import Joi from "joi";
import mongoose from "mongoose";
import Plan from "../models/Plan.model.js";
import Item from "../models/Item.model.js";
import Customer from "../models/Customer.model.js";
import Subscription from "../models/Subscription.model.js";
import DailyOrder from "../models/DailyOrder.model.js";
import { asyncHandler } from "../utils/asyncHandler.js";
import { ApiResponse } from "../class/apiResponseClass.js";
import { ApiError } from "../class/apiErrorClass.js";

const MAX_LIMIT = 100;
const DEFAULT_LIMIT = 20;
const DEFAULT_PAGE = 1;

const SLOT_VALUES = ["breakfast", "lunch", "dinner", "snack", "early_morning"];

const mealSlotItemSchema = Joi.object({
  itemId: Joi.string().hex().length(24).required().messages({
    "string.empty": "Item ID is required",
    "string.length": "Invalid item ID format",
  }),
  quantity: Joi.number().integer().min(1).required().messages({
    "number.min": "Quantity must be at least 1",
  }),
});

const mealSlotSchema = Joi.object({
  slot: Joi.string()
    .valid(...SLOT_VALUES)
    .required()
    .messages({ "any.only": `Slot must be one of: ${SLOT_VALUES.join(", ")}` }),
  items: Joi.array().items(mealSlotItemSchema).min(1).required().messages({
    "array.min": "Each meal slot must have at least one item",
  }),
});

const createPlanSchema = Joi.object({
  planName: Joi.string()
    .trim()
    .required()
    .messages({ "string.empty": "Plan name is required" }),
  planType: Joi.string()
    .valid("daily", "weekly", "monthly", "custom")
    .optional(),
  price: Joi.number().min(0).required().messages({
    "number.min": "Price must be 0 or greater",
  }),
  mealSlots: Joi.array().items(mealSlotSchema).min(1).required().messages({
    "array.min": "At least one meal slot is required",
    "any.required": "mealSlots is required",
  }),
  // Optional: when provided the plan is a custom plan for this one customer only.
  customerId: Joi.string().hex().length(24).optional().messages({
    "string.length": "Invalid customerId format",
  }),
  isActive: Joi.boolean().optional(),
  color: Joi.string().trim().allow("").optional(),
});

const updatePlanSchema = Joi.object({
  planName: Joi.string().trim().optional(),
  planType: Joi.string()
    .valid("daily", "weekly", "monthly", "custom")
    .optional(),
  price: Joi.number().min(0).optional(),
  mealSlots: Joi.array().items(mealSlotSchema).min(1).optional(),
  isActive: Joi.boolean().optional(),
  color: Joi.string().trim().allow("").optional(),
}).min(1);

const listQuerySchema = Joi.object({
  page: Joi.number().integer().min(1).optional(),
  limit: Joi.number().integer().min(1).max(MAX_LIMIT).optional(),
  isActive: Joi.boolean().optional(),
  planType: Joi.string()
    .valid("daily", "weekly", "monthly", "custom")
    .optional(),
  // When customerId is supplied, returns generic plans + that customer's custom plans.
  // Use "generic" to list only plans with no customerId attached.
  customerId: Joi.string().hex().length(24).optional().messages({
    "string.length": "Invalid customerId format",
  }),
  generic: Joi.boolean().truthy("true").falsy("false").optional(),
});

/**
 * Validate that all itemIds in mealSlots belong to the given ownerId.
 * Returns the item map: { itemId => { name, unitPrice } }
 */
const validateMealSlotItems = async (mealSlots, ownerId) => {
  const allItemIds = [
    ...new Set(mealSlots.flatMap((slot) => slot.items.map((i) => i.itemId))),
  ];

  const items = await Item.find({
    _id: { $in: allItemIds },
    ownerId,
    isActive: true,
  })
    .select("name unitPrice")
    .lean();

  if (items.length !== allItemIds.length) {
    const foundIds = new Set(items.map((i) => i._id.toString()));
    const missing = allItemIds.filter((id) => !foundIds.has(id));
    throw new ApiError(
      400,
      `Item(s) not found or inactive: ${missing.join(", ")}`
    );
  }

  const itemMap = {};
  for (const item of items) {
    itemMap[item._id.toString()] = item;
  }
  return itemMap;
};

/**
 * GET /api/v1/plans
 */
export const listPlans = asyncHandler(async (req, res) => {
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
  const baseFilter = { ownerId };
  if (value.isActive !== undefined) baseFilter.isActive = value.isActive;
  if (value.planType) baseFilter.planType = value.planType;

  let filter;
  if (value.customerId) {
    // Return generic plans (no customerId) + plans for this specific customer
    filter = {
      ...baseFilter,
      $or: [{ customerId: null }, { customerId: value.customerId }],
    };
  } else if (value.generic) {
    // Only generic / reusable plans
    filter = { ...baseFilter, customerId: null };
  } else {
    // Default: all plans belonging to this vendor
    filter = baseFilter;
  }

  const [data, total] = await Promise.all([
    Plan.find(filter)
      .populate("mealSlots.items.itemId", "name unitPrice unit")
      .populate("customerId", "name phone")
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit)
      .lean(),
    Plan.countDocuments(filter),
  ]);

  const totalPages = Math.ceil(total / limit);

  res.status(200).json(
    new ApiResponse(200, "Plans fetched", {
      data,
      total,
      page,
      limit,
      totalPages,
    })
  );
});

/**
 * GET /api/v1/plans/:id
 */
export const getPlanById = asyncHandler(async (req, res) => {
  const ownerId = req.user.userId;
  const { id } = req.params;

  const plan = await Plan.findOne({ _id: id, ownerId })
    .populate("mealSlots.items.itemId", "name unitPrice unit")
    .lean();

  if (!plan) throw new ApiError(404, "Plan not found");

  res.status(200).json(new ApiResponse(200, "Plan fetched", plan));
});

/**
 * POST /api/v1/plans
 * Also used internally by createCustomPlanForCustomer.
 * When `customerId` is supplied in the body, the plan is created as a
 * customer-specific plan and only that customer can be subscribed to it.
 */
export const createPlan = asyncHandler(async (req, res) => {
  const { error, value } = createPlanSchema.validate(req.body, {
    stripUnknown: true,
    abortEarly: false,
  });
  if (error) {
    throw new ApiError(400, error.details.map((d) => d.message).join("; "));
  }

  const ownerId = req.user.userId;

  // If creating a customer-specific plan, verify the customer belongs to this vendor.
  if (value.customerId) {
    const customer = await Customer.findOne({
      _id: value.customerId,
      ownerId,
      isDeleted: { $ne: true },
    }).lean();
    if (!customer) throw new ApiError(404, "Customer not found");
  }

  // Validate all item refs belong to this vendor
  await validateMealSlotItems(value.mealSlots, ownerId);

  // Prevent duplicate slot types in the same plan
  const slotTypes = value.mealSlots.map((s) => s.slot);
  const uniqueSlots = new Set(slotTypes);
  if (uniqueSlots.size !== slotTypes.length) {
    throw new ApiError(400, "Duplicate meal slots are not allowed in a plan");
  }

  const plan = await Plan.create({
    ownerId,
    customerId: value.customerId || null,
    planName: value.planName.trim(),
    planType: value.planType || "monthly",
    price: value.price,
    mealSlots: value.mealSlots,
    isActive: value.isActive !== undefined ? value.isActive : true,
    color: value.color || "",
  });

  const created = await Plan.findById(plan._id)
    .populate("mealSlots.items.itemId", "name unitPrice unit")
    .populate("customerId", "name phone")
    .lean();

  res.status(201).json(new ApiResponse(201, "Plan created", created));
});

/**
 * PUT /api/v1/plans/:id
 */
export const updatePlan = asyncHandler(async (req, res) => {
  const { id } = req.params;

  const { error, value } = updatePlanSchema.validate(req.body, {
    stripUnknown: true,
    abortEarly: false,
  });
  if (error) {
    throw new ApiError(400, error.details.map((d) => d.message).join("; "));
  }

  const ownerId = req.user.userId;

  if (value.mealSlots) {
    await validateMealSlotItems(value.mealSlots, ownerId);

    const slotTypes = value.mealSlots.map((s) => s.slot);
    const uniqueSlots = new Set(slotTypes);
    if (uniqueSlots.size !== slotTypes.length) {
      throw new ApiError(400, "Duplicate meal slots are not allowed in a plan");
    }

    // Recompute convenience flags — findOneAndUpdate skips pre("save") hooks.
    const slots = value.mealSlots.map((s) => s.slot);
    value.includesBreakfast = slots.includes("breakfast") || slots.includes("early_morning");
    value.includesLunch = slots.includes("lunch");
    value.includesDinner = slots.includes("dinner");
  }

  const plan = await Plan.findOneAndUpdate(
    { _id: id, ownerId },
    { $set: value },
    { new: true }
  )
    .populate("mealSlots.items.itemId", "name unitPrice unit")
    .populate("customerId", "name phone")
    .lean();

  if (!plan) throw new ApiError(404, "Plan not found");

  res.status(200).json(new ApiResponse(200, "Plan updated", plan));
});

/**
 * POST /api/v1/customers/:customerId/plans
 * Convenience endpoint: vendor creates a custom meal plan directly for a
 * specific customer. Equivalent to POST /plans with customerId in the body
 * but takes customerId from the URL for ergonomics.
 */
export const createCustomerPlan = asyncHandler(async (req, res) => {
  const ownerId = req.user.userId;
  const { customerId } = req.params;

  if (!mongoose.Types.ObjectId.isValid(customerId)) {
    throw new ApiError(400, "Invalid customerId");
  }

  // Verify the customer belongs to this vendor
  const customer = await Customer.findOne({
    _id: customerId,
    ownerId,
    isDeleted: { $ne: true },
  }).lean();
  if (!customer) throw new ApiError(404, "Customer not found");

  const { error, value } = createPlanSchema.validate(
    { ...req.body, customerId },
    { stripUnknown: true, abortEarly: false }
  );
  if (error) throw new ApiError(400, error.details.map((d) => d.message).join("; "));

  await validateMealSlotItems(value.mealSlots, ownerId);

  const slotTypes = value.mealSlots.map((s) => s.slot);
  if (new Set(slotTypes).size !== slotTypes.length) {
    throw new ApiError(400, "Duplicate meal slots are not allowed in a plan");
  }

  const plan = await Plan.create({
    ownerId,
    customerId,
    planName: value.planName.trim(),
    planType: value.planType || "custom",
    price: value.price,
    mealSlots: value.mealSlots,
    isActive: value.isActive !== undefined ? value.isActive : true,
    color: value.color || "",
  });

  const created = await Plan.findById(plan._id)
    .populate("mealSlots.items.itemId", "name unitPrice unit")
    .populate("customerId", "name phone")
    .lean();

  res.status(201).json(
    new ApiResponse(201, `Custom plan created for customer ${customer.name}`, created)
  );
});

/**
 * DELETE /api/v1/plans/:id
 */
export const deletePlan = asyncHandler(async (req, res) => {
  const ownerId = req.user.userId;
  const { id } = req.params;

  const plan = await Plan.findOne({ _id: id, ownerId });
  if (!plan) throw new ApiError(404, "Meal plan not found");

  const activeSubscriptions = await Subscription.countDocuments({
    planId: id,
    status: "active",
  });
  if (activeSubscriptions > 0) {
    throw new ApiError(400, "Cannot delete plan. Active subscriptions exist.");
  }

  const futureOrders = await DailyOrder.countDocuments({
    planId: id,
    orderDate: { $gte: new Date() },
  });
  if (futureOrders > 0) {
    throw new ApiError(400, "Cannot delete plan. Future orders already generated.");
  }

  await Plan.deleteOne({ _id: id });

  res.status(200).json(new ApiResponse(200, "Meal plan deleted successfully"));
});
