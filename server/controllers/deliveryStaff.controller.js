import Joi from "joi";
import DeliveryStaff from "../models/DeliveryStaff.model.js";
import DailyOrder from "../models/DailyOrder.model.js";
import { asyncHandler } from "../utils/asyncHandler.js";
import { ApiResponse } from "../class/apiResponseClass.js";
import { ApiError } from "../class/apiErrorClass.js";

const MAX_LIMIT = 100;
const DEFAULT_LIMIT = 20;
const DEFAULT_PAGE = 1;

const phoneSchema = Joi.string()
  .pattern(/^[6-9]\d{9}$/)
  .required()
  .messages({ "string.pattern.base": "Phone must be a valid 10-digit Indian mobile number" });

const createStaffSchema = Joi.object({
  name: Joi.string().trim().required().messages({ "string.empty": "Name is required" }),
  phone: phoneSchema,
  areas: Joi.array().items(Joi.string().trim()).optional(),
  joiningDate: Joi.date().iso().optional(),
  isActive: Joi.boolean().optional(),
});

const updateStaffSchema = Joi.object({
  name: Joi.string().trim().optional(),
  phone: Joi.string().pattern(/^[6-9]\d{9}$/).optional(),
  areas: Joi.array().items(Joi.string().trim()).optional(),
  joiningDate: Joi.date().iso().optional(),
  isActive: Joi.boolean().optional(),
  fcmToken: Joi.string().allow("", null).optional(),
}).min(1);

const listQuerySchema = Joi.object({
  page: Joi.number().integer().min(1).optional(),
  limit: Joi.number().integer().min(1).max(MAX_LIMIT).optional(),
  isActive: Joi.boolean().optional(),
});

/**
 * GET /api/v1/delivery-staff
 */
export const listStaff = asyncHandler(async (req, res) => {
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

  const [data, total] = await Promise.all([
    DeliveryStaff.find(filter)
      .sort({ name: 1 })
      .skip(skip)
      .limit(limit)
      .lean(),
    DeliveryStaff.countDocuments(filter),
  ]);

  res.status(200).json(
    new ApiResponse(200, "Delivery staff fetched", {
      data,
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
    })
  );
});

/**
 * GET /api/v1/delivery-staff/:id
 */
export const getStaffById = asyncHandler(async (req, res) => {
  const ownerId = req.user.userId;
  const { id } = req.params;

  const staff = await DeliveryStaff.findOne({ _id: id, ownerId }).lean();
  if (!staff) throw new ApiError(404, "Delivery staff not found");

  res.status(200).json(new ApiResponse(200, "Staff fetched", staff));
});

/**
 * POST /api/v1/delivery-staff
 */
export const createStaff = asyncHandler(async (req, res) => {
  const { error, value } = createStaffSchema.validate(req.body, {
    stripUnknown: true,
    abortEarly: false,
  });
  if (error) {
    throw new ApiError(400, error.details.map((d) => d.message).join("; "));
  }

  const ownerId = req.user.userId;
  const phone = String(value.phone).trim().replace(/^\+?91/, "");

  const existing = await DeliveryStaff.findOne({ ownerId, phone }).lean();
  if (existing) {
    throw new ApiError(409, "Delivery staff with this phone already exists");
  }

  const staff = await DeliveryStaff.create({
    ownerId,
    name: value.name.trim(),
    phone,
    areas: value.areas || [],
    joiningDate: value.joiningDate || new Date(),
    isActive: value.isActive !== undefined ? value.isActive : true,
  });

  res.status(201).json(new ApiResponse(201, "Delivery staff created", staff.toObject()));
});

/**
 * PUT /api/v1/delivery-staff/:id
 */
export const updateStaff = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { error, value } = updateStaffSchema.validate(req.body, {
    stripUnknown: true,
    abortEarly: false,
  });
  if (error) {
    throw new ApiError(400, error.details.map((d) => d.message).join("; "));
  }

  const ownerId = req.user.userId;

  if (value.phone) {
    const phone = String(value.phone).trim().replace(/^\+?91/, "");
    const duplicate = await DeliveryStaff.findOne({
      ownerId,
      phone,
      _id: { $ne: id },
    }).lean();
    if (duplicate) throw new ApiError(409, "Another staff with this phone exists");
    value.phone = phone;
  }

  const staff = await DeliveryStaff.findOneAndUpdate(
    { _id: id, ownerId },
    { $set: value },
    { new: true, runValidators: true }
  ).lean();

  if (!staff) throw new ApiError(404, "Delivery staff not found");

  res.status(200).json(new ApiResponse(200, "Staff updated", staff));
});

/**
 * DELETE /api/v1/delivery-staff/:id
 * Soft-delete: sets isActive: false. Blocks if staff has pending orders today.
 */
export const deleteStaff = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const ownerId = req.user.userId;

  const staff = await DeliveryStaff.findOne({ _id: id, ownerId });
  if (!staff) throw new ApiError(404, "Delivery staff not found");

  const today = new Date();
  today.setUTCHours(0, 0, 0, 0);

  const pendingOrders = await DailyOrder.countDocuments({
    deliveryStaffId: id,
    orderDate: today,
    status: { $in: ["pending", "processing", "out_for_delivery"] },
  });

  if (pendingOrders > 0) {
    throw new ApiError(
      400,
      `Cannot deactivate staff. They have ${pendingOrders} pending order(s) today.`
    );
  }

  await DeliveryStaff.findByIdAndUpdate(id, { $set: { isActive: false } });

  res.status(200).json(new ApiResponse(200, "Delivery staff deactivated"));
});

// ─── self-service (delivery staff role only) ─────────────────────────────────

const selfUpdateSchema = Joi.object({
  fcmToken: Joi.string().optional(),
  location: Joi.object({
    type: Joi.string().valid("Point").optional(),
    coordinates: Joi.array().items(Joi.number()).length(2).optional(),
  }).optional(),
}).min(1);

/**
 * GET /api/v1/delivery-staff/me
 * Delivery staff fetches their own profile using staffId from JWT.
 */
export const getMyStaffProfile = asyncHandler(async (req, res) => {
  const { staffId } = req.user;
  if (!staffId) throw new ApiError(403, "Staff ID not found in token");

  const staff = await DeliveryStaff.findById(staffId).lean();
  if (!staff) throw new ApiError(404, "Staff profile not found");

  res.status(200).json(new ApiResponse(200, "Profile fetched", staff));
});

/**
 * PATCH /api/v1/delivery-staff/me
 * Delivery staff updates their own fcmToken and/or current location.
 * Called on app open so push notifications are always routed to the current device.
 */
export const updateMyStaffProfile = asyncHandler(async (req, res) => {
  const { staffId } = req.user;
  if (!staffId) throw new ApiError(403, "Staff ID not found in token");

  const { error, value } = selfUpdateSchema.validate(req.body, {
    stripUnknown: true,
    abortEarly: false,
  });
  if (error) throw new ApiError(400, error.details.map((d) => d.message).join("; "));

  const updatePayload = {};
  if (value.fcmToken) updatePayload.fcmToken = value.fcmToken;
  if (value.location?.coordinates?.length === 2) {
    updatePayload.location = { type: "Point", coordinates: value.location.coordinates };
  }

  const updated = await DeliveryStaff.findByIdAndUpdate(
    staffId,
    { $set: updatePayload },
    { new: true }
  ).lean();

  if (!updated) throw new ApiError(404, "Staff profile not found");

  res.status(200).json(new ApiResponse(200, "Profile updated", updated));
});
