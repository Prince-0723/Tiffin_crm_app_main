import Joi from "joi";
import mongoose from "mongoose";
import Zone from "../models/Zone.model.js";
import { asyncHandler } from "../utils/asyncHandler.js";
import { ApiResponse } from "../class/apiResponseClass.js";
import { ApiError } from "../class/apiErrorClass.js";

const MAX_LIMIT = 100;
const DEFAULT_LIMIT = 50;
const DEFAULT_PAGE = 1;

const createZoneSchema = Joi.object({
  name: Joi.string().trim().min(1).max(80).required(),
  description: Joi.string().trim().allow("").max(500).optional(),
  color: Joi.string().trim().allow("").max(30).optional(),
  isActive: Joi.boolean().optional(),
});

const updateZoneSchema = Joi.object({
  name: Joi.string().trim().min(1).max(80).optional(),
  description: Joi.string().trim().allow("").max(500).optional(),
  color: Joi.string().trim().allow("").max(30).optional(),
  isActive: Joi.boolean().optional(),
}).min(1);

const listQuerySchema = Joi.object({
  page: Joi.number().integer().min(1).optional(),
  limit: Joi.number().integer().min(1).max(MAX_LIMIT).optional(),
  isActive: Joi.boolean().truthy("true").falsy("false").optional(),
});

/**
 * GET /api/v1/zones
 */
export const listZones = asyncHandler(async (req, res) => {
  const { error, value } = listQuerySchema.validate(req.query, {
    stripUnknown: true,
    abortEarly: false,
  });
  if (error) throw new ApiError(400, error.details.map((d) => d.message).join("; "));

  const page = value.page || DEFAULT_PAGE;
  const limit = Math.min(value.limit || DEFAULT_LIMIT, MAX_LIMIT);
  const skip = (page - 1) * limit;

  const ownerId = req.user.ownerId || req.user.userId;
  const filter = { ownerId };
  if (typeof value.isActive === "boolean") filter.isActive = value.isActive;

  const [data, total] = await Promise.all([
    Zone.find(filter).sort({ name: 1 }).skip(skip).limit(limit).lean(),
    Zone.countDocuments(filter),
  ]);

  res.status(200).json(
    new ApiResponse(200, "Zones fetched", {
      data,
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
    })
  );
});

/**
 * GET /api/v1/zones/:id
 */
export const getZoneById = asyncHandler(async (req, res) => {
  const ownerId = req.user.ownerId || req.user.userId;
  const { id } = req.params;
  if (!mongoose.Types.ObjectId.isValid(id)) throw new ApiError(400, "Invalid zone id");

  const zone = await Zone.findOne({ _id: id, ownerId }).lean();
  if (!zone) throw new ApiError(404, "Zone not found");

  res.status(200).json(new ApiResponse(200, "Zone fetched", zone));
});

/**
 * POST /api/v1/zones
 */
export const createZone = asyncHandler(async (req, res) => {
  const { error, value } = createZoneSchema.validate(req.body || {}, {
    stripUnknown: true,
    abortEarly: false,
  });
  if (error) throw new ApiError(400, error.details.map((d) => d.message).join("; "));

  const ownerId = req.user.ownerId || req.user.userId;

  const existing = await Zone.findOne({
    ownerId,
    name: value.name.trim(),
  }).lean();
  if (existing) throw new ApiError(409, "Zone with this name already exists");

  const zone = await Zone.create({
    ownerId,
    name: value.name.trim(),
    description: value.description || "",
    color: value.color || "",
    isActive: value.isActive !== undefined ? value.isActive : true,
  });

  res.status(201).json(new ApiResponse(201, "Zone created", zone.toObject()));
});

/**
 * PUT /api/v1/zones/:id
 */
export const updateZone = asyncHandler(async (req, res) => {
  const { id } = req.params;
  if (!mongoose.Types.ObjectId.isValid(id)) throw new ApiError(400, "Invalid zone id");

  const { error, value } = updateZoneSchema.validate(req.body || {}, {
    stripUnknown: true,
    abortEarly: false,
  });
  if (error) throw new ApiError(400, error.details.map((d) => d.message).join("; "));

  const ownerId = req.user.ownerId || req.user.userId;

  if (value.name) {
    const duplicate = await Zone.findOne({
      ownerId,
      name: value.name.trim(),
      _id: { $ne: id },
    }).lean();
    if (duplicate) throw new ApiError(409, "Another zone with this name exists");
    value.name = value.name.trim();
  }

  const updated = await Zone.findOneAndUpdate(
    { _id: id, ownerId },
    { $set: value },
    { new: true, runValidators: true }
  ).lean();

  if (!updated) throw new ApiError(404, "Zone not found");

  res.status(200).json(new ApiResponse(200, "Zone updated", updated));
});

/**
 * DELETE /api/v1/zones/:id
 * Soft delete: isActive=false
 */
export const deactivateZone = asyncHandler(async (req, res) => {
  const ownerId = req.user.ownerId || req.user.userId;
  const { id } = req.params;
  if (!mongoose.Types.ObjectId.isValid(id)) throw new ApiError(400, "Invalid zone id");

  const zone = await Zone.findOne({ _id: id, ownerId }).lean();
  if (!zone) throw new ApiError(404, "Zone not found");

  await Zone.updateOne({ _id: id, ownerId }, { $set: { isActive: false } });

  res.status(200).json(new ApiResponse(200, "Zone deactivated", { id }));
});

