import Joi from "joi";
import Item from "../models/Item.model.js";
import MealPlan from "../models/Plan.model.js";
import { asyncHandler } from "../utils/asyncHandler.js";
import { ApiResponse } from "../class/apiResponseClass.js";
import { ApiError } from "../class/apiErrorClass.js";

const MAX_LIMIT = 100;
const DEFAULT_LIMIT = 20;
const DEFAULT_PAGE = 1;

const createItemSchema = Joi.object({
  name: Joi.string()
    .trim()
    .required()
    .messages({ "string.empty": "Item name is required" }),
  unitPrice: Joi.number().min(0).optional().allow(null).messages({
    "number.base": "Unit price must be a number",
    "number.min": "Unit price must be 0 or greater",
  }),
  unit: Joi.string()
    .valid("piece", "bowl", "plate", "glass", "other")
    .optional(),
  category: Joi.string().trim().allow("").optional(),
  dietType: Joi.string().valid("veg", "non_veg").optional(),
  isActive: Joi.boolean().optional(),
});

const updateItemSchema = Joi.object({
  name: Joi.string().trim().optional(),
  unitPrice: Joi.number().min(0).optional().allow(null),
  unit: Joi.string()
    .valid("piece", "bowl", "plate", "glass", "other")
    .optional(),
  category: Joi.string().trim().allow("").optional(),
  dietType: Joi.string().valid("veg", "non_veg").optional(),
  isActive: Joi.boolean().optional(),
}).min(1);

const listQuerySchema = Joi.object({
  page: Joi.number().integer().min(1).optional(),
  limit: Joi.number().integer().min(1).max(MAX_LIMIT).optional(),
  isActive: Joi.boolean().optional(),
  category: Joi.string().trim().optional(),
  dietType: Joi.string().valid("veg", "non_veg").optional(),
});

/**
 * GET /api/v1/items
 */
export const listItems = asyncHandler(async (req, res) => {
  const { error, value } = listQuerySchema.validate(req.query, {
    stripUnknown: true,
    abortEarly: false,
  });
  if (error) {
    throw new ApiError(400, error.details.map((d) => d.message).join("; "));
  }

  const page = value.page || DEFAULT_PAGE;
  const limit = Math.min(value.limit || DEFAULT_LIMIT, MAX_LIMIT);
  const skip = (page - 1) * limit;

  const ownerId = req.user.userId;
  const filter = { ownerId };
  if (value.isActive !== undefined) filter.isActive = value.isActive;
  if (value.category) filter.category = value.category;
  if (value.dietType) filter.dietType = value.dietType;

  const [data, total] = await Promise.all([
    Item.find(filter).sort({ name: 1 }).skip(skip).limit(limit).lean(),
    Item.countDocuments(filter),
  ]);

  const totalPages = Math.ceil(total / limit);

  res.status(200).json(
    new ApiResponse(200, "Items fetched", {
      data,
      total,
      page,
      limit,
      totalPages,
    })
  );
});

/**
 * GET /api/v1/items/:id
 */
export const getItemById = asyncHandler(async (req, res) => {
  const ownerId = req.user.userId;
  const { id } = req.params;

  const item = await Item.findOne({ _id: id, ownerId }).lean();
  if (!item) throw new ApiError(404, "Item not found");

  res.status(200).json(new ApiResponse(200, "Item fetched", item));
});

/**
 * POST /api/v1/items
 */
export const createItem = asyncHandler(async (req, res) => {
  const { error, value } = createItemSchema.validate(req.body, {
    stripUnknown: true,
    abortEarly: false,
  });
  if (error) {
    throw new ApiError(400, error.details.map((d) => d.message).join("; "));
  }

  const ownerId = req.user.userId;

  const existing = await Item.findOne({
    ownerId,
    name: { $regex: new RegExp(`^${value.name.trim()}$`, "i") },
  }).lean();
  if (existing) {
    throw new ApiError(409, `Item "${value.name}" already exists`);
  }

  const item = await Item.create({ ownerId, ...value });

  res.status(201).json(new ApiResponse(201, "Item created", item.toObject()));
});

/**
 * PUT /api/v1/items/:id
 */
export const updateItem = asyncHandler(async (req, res) => {
  const { id } = req.params;

  const { error, value } = updateItemSchema.validate(req.body, {
    stripUnknown: true,
    abortEarly: false,
  });
  if (error) {
    throw new ApiError(400, error.details.map((d) => d.message).join("; "));
  }

  const ownerId = req.user.userId;

  if (value.name) {
    const duplicate = await Item.findOne({
      ownerId,
      name: { $regex: new RegExp(`^${value.name.trim()}$`, "i") },
      _id: { $ne: id },
    }).lean();
    if (duplicate) {
      throw new ApiError(409, `Another item named "${value.name}" already exists`);
    }
  }

  const item = await Item.findOneAndUpdate(
    { _id: id, ownerId },
    { $set: value },
    { new: true, runValidators: true }
  ).lean();

  if (!item) throw new ApiError(404, "Item not found");

  res.status(200).json(new ApiResponse(200, "Item updated", item));
});

/**
 * DELETE /api/v1/items/:id
 * Blocked if item is referenced in any active MealPlan's mealSlots.
 */
export const deleteItem = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const ownerId = req.user.userId;

  const item = await Item.findOne({ _id: id, ownerId });
  if (!item) throw new ApiError(404, "Item not found");

  const usedInPlan = await MealPlan.findOne({
    ownerId,
    isActive: true,
    "mealSlots.items.itemId": id,
  }).lean();

  if (usedInPlan) {
    throw new ApiError(
      400,
      `Cannot delete item "${item.name}". It is used in active plan "${usedInPlan.planName}". Deactivate the plan first or remove the item from it.`
    );
  }

  await Item.deleteOne({ _id: id });

  res.status(200).json(new ApiResponse(200, "Item deleted successfully"));
});
