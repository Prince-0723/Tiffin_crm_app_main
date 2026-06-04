import Joi from "joi";
import Customer from "../models/Customer.model.js";
import User from "../models/User.model.js";
import Subscription from "../models/Subscription.model.js";
import DailyOrder from "../models/DailyOrder.model.js";
import Notification from "../models/Notification.model.js";
import { asyncHandler } from "../utils/asyncHandler.js";
import { ApiResponse } from "../class/apiResponseClass.js";
import { ApiError } from "../class/apiErrorClass.js";
import { effectiveRemaining } from "../utils/subscriptionBalance.js";
import { displayWalletBalance } from "../utils/customerWallet.js";

const ORDER_STATUSES = [
  "pending",
  "processing",
  "out_for_delivery",
  "delivered",
  "cancelled",
  "failed",
  "skipped",
];

// Allow portal users to update contact + profile fields (phone is the login identity for many flows).
const PHONE_PATTERN = /^\d{10,15}$/;

const updateProfileSchema = Joi.object({
  name: Joi.string().trim().min(1).optional(),
  phone: Joi.string().trim().pattern(PHONE_PATTERN).optional(),
  whatsapp: Joi.string().trim().allow(null, "").optional(),
  address: Joi.string().trim().allow("").optional(),
  fcmToken: Joi.string().optional(),
  location: Joi.object({
    type: Joi.string().valid("Point").optional(),
    coordinates: Joi.array().items(Joi.number()).length(2).optional(),
  }).optional(),
}).min(1);

const ordersQuerySchema = Joi.object({
  page: Joi.number().integer().min(1).optional(),
  limit: Joi.number().integer().min(1).max(50).optional(),
  status: Joi.string()
    .valid(...ORDER_STATUSES)
    .optional(),
});

const vendorPublicForCustomer = async (ownerId) => {
  if (!ownerId) return null;
  const v = await User.findById(ownerId)
    .select(
      "businessName ownerName phone upiId settings.portalAnnouncementText settings.portalAnnouncementUpdatedAt"
    )
    .lean();
  if (!v) return null;
  return {
    businessName: (v.businessName || "").trim(),
    ownerName: (v.ownerName || "").trim(),
    phone: (v.phone || "").trim(),
    upiId: (v.upiId || "").trim(),
    announcement: {
      text: (v.settings?.portalAnnouncementText ?? "").trim(),
      updatedAt: v.settings?.portalAnnouncementUpdatedAt ?? null,
    },
  };
};

/**
 * GET /api/v1/customer/me
 */
export const getMyProfile = asyncHandler(async (req, res) => {
  const { customerId } = req.user;
  if (!customerId) throw new ApiError(403, "Customer ID not found in token");

  const customer = await Customer.findOne({
    _id: customerId,
    isDeleted: { $ne: true },
  }).lean();

  if (!customer) throw new ApiError(404, "Customer profile not found");

  const vendor = await vendorPublicForCustomer(customer.ownerId);

  res
    .status(200)
    .json(new ApiResponse(200, "Profile fetched", { ...customer, vendor }));
});

/**
 * GET /api/v1/customer/me/balance
 * Returns wallet + active subscription remaining balance.
 */
export const getMyBalance = asyncHandler(async (req, res) => {
  const { customerId } = req.user;
  if (!customerId) throw new ApiError(403, "Customer ID not found in token");

  const [customer, subscription] = await Promise.all([
    Customer.findOne({ _id: customerId, isDeleted: { $ne: true } })
      .select("balance walletBalance")
      .lean(),
    Subscription.findOne({
      customerId,
      status: { $in: ["active", "paused"] },
      endDate: { $gte: new Date() },
    })
      .sort({ endDate: -1 })
      .select("remainingBalance totalAmount paidAmount")
      .lean(),
  ]);

  if (!customer) throw new ApiError(404, "Customer profile not found");

  return res.status(200).json(
    new ApiResponse(200, "Balance fetched", {
      walletBalance: displayWalletBalance(customer),
      subscriptionBalance: effectiveRemaining(subscription),
    })
  );
});

/**
 * PUT /api/v1/customer/me
 * Allows updating name, phone, whatsapp, address, location, fcmToken.
 */
export const updateMyProfile = asyncHandler(async (req, res) => {
  const { customerId, ownerId: ownerIdFromToken } = req.user;
  if (!customerId) throw new ApiError(403, "Customer ID not found in token");

  const { error, value } = updateProfileSchema.validate(req.body, {
    stripUnknown: true,
    abortEarly: false,
  });
  if (error) {
    throw new ApiError(400, error.details.map((d) => d.message).join("; "));
  }

  const updatePayload = { ...value };
  if (value.location?.coordinates?.length === 2) {
    updatePayload.location = {
      type: "Point",
      coordinates: value.location.coordinates,
    };
  }

  // If only phone changes, keep WhatsApp in sync when it matched the old number (typical case).
  if (value.phone !== undefined) {
    const existing = await Customer.findOne({
      _id: customerId,
      isDeleted: { $ne: true },
    })
      .select("phone whatsapp ownerId")
      .lean();

    if (!existing) throw new ApiError(404, "Customer profile not found");

    const ownerId = ownerIdFromToken || existing.ownerId?.toString?.() || null;
    if (!ownerId) {
      throw new ApiError(403, "Owner context not found for this customer");
    }

    const dup = await Customer.findOne({
      ownerId,
      phone: value.phone,
      _id: { $ne: customerId },
      isDeleted: { $ne: true },
    })
      .select("_id")
      .lean();
    if (dup) {
      throw new ApiError(
        409,
        "This phone number is already used for another customer under this business"
      );
    }

    if (value.whatsapp === undefined) {
      const wa = existing.whatsapp;
      const prevPhone = existing.phone;
      if (!wa || wa === prevPhone) {
        updatePayload.whatsapp = value.phone;
      }
    }
  }

  const updated = await Customer.findOneAndUpdate(
    { _id: customerId, isDeleted: { $ne: true } },
    { $set: updatePayload },
    { new: true }
  ).lean();

  if (!updated) throw new ApiError(404, "Customer profile not found");

  const vendor = await vendorPublicForCustomer(updated.ownerId);

  res
    .status(200)
    .json(new ApiResponse(200, "Profile updated", { ...updated, vendor }));
});

/**
 * GET /api/v1/customer/me/plan
 * Returns the customer's active or paused subscription with plan details.
 */
export const getMyActivePlan = asyncHandler(async (req, res) => {
  const { customerId } = req.user;
  if (!customerId) throw new ApiError(403, "Customer ID not found in token");

  const subscription = await Subscription.findOne({
    customerId,
    status: { $in: ["active", "paused"] },
  })
    .populate({
      path: "planId",
      select:
        "planName price planType mealSlots includesBreakfast includesLunch includesDinner",
      populate: {
        path: "mealSlots.items.itemId",
        select: "name unitPrice unit dietType",
      },
    })
    .populate("ownerId", "businessName ownerName phone upiId")
    .lean();

  if (!subscription) {
    return res
      .status(200)
      .json(new ApiResponse(200, "No active subscription", null));
  }

  res
    .status(200)
    .json(new ApiResponse(200, "Active subscription fetched", subscription));
});

/**
 * GET /api/v1/customer/me/orders
 * Query: page, limit, status
 */
export const getMyOrders = asyncHandler(async (req, res) => {
  const { customerId } = req.user;
  if (!customerId) throw new ApiError(403, "Customer ID not found in token");

  const { error, value } = ordersQuerySchema.validate(req.query, {
    stripUnknown: true,
    abortEarly: false,
  });
  if (error) {
    throw new ApiError(400, error.details.map((d) => d.message).join("; "));
  }

  const page = value.page || 1;
  const limit = value.limit || 20;
  const skip = (page - 1) * limit;

  const filter = { customerId };
  if (value.status) filter.status = value.status;

  const [data, total] = await Promise.all([
    DailyOrder.find(filter)
      .populate("planId", "planName price")
      // Expose name + phone only — enough for the customer to contact/identify the rider.
      .populate("deliveryStaffId", "name phone")
      .populate("resolvedItems.itemId", "name unitPrice unit dietType")
      .sort({ orderDate: -1 })
      .skip(skip)
      .limit(limit)
      .lean(),
    DailyOrder.countDocuments(filter),
  ]);

  res.status(200).json(
    new ApiResponse(200, "Orders fetched", {
      data,
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
    })
  );
});

const notificationsQuerySchema = Joi.object({
  page: Joi.number().integer().min(1).optional(),
  limit: Joi.number().integer().min(1).max(50).optional(),
  isRead: Joi.boolean().truthy("true").falsy("false").optional(),
});

/**
 * GET /api/v1/customer/me/notifications
 * List in-app notifications for the logged-in customer.
 * Query: page, limit, isRead (optional)
 */
export const getMyNotifications = asyncHandler(async (req, res) => {
  const { customerId } = req.user;
  if (!customerId) throw new ApiError(403, "Customer ID not found in token");

  const { error, value } = notificationsQuerySchema.validate(req.query, {
    stripUnknown: true,
    abortEarly: false,
  });
  if (error) {
    throw new ApiError(400, error.details.map((d) => d.message).join("; "));
  }

  const page = value.page || 1;
  const limit = value.limit || 20;
  const skip = (page - 1) * limit;

  const filter = { customerId };
  if (typeof value.isRead === "boolean") filter.isRead = value.isRead;

  const [data, total] = await Promise.all([
    Notification.find(filter)
      .select("type title message data isRead sentAt createdAt")
      .sort({ sentAt: -1 })
      .skip(skip)
      .limit(limit)
      .lean(),
    Notification.countDocuments(filter),
  ]);

  res.status(200).json(
    new ApiResponse(200, "Notifications fetched", {
      data,
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
    })
  );
});

/**
 * PATCH /api/v1/customer/me/notifications/:id/read
 * Mark a notification as read. Notification must belong to this customer.
 */
export const markNotificationRead = asyncHandler(async (req, res) => {
  const { customerId } = req.user;
  if (!customerId) throw new ApiError(403, "Customer ID not found in token");

  const { id } = req.params;
  const updated = await Notification.findOneAndUpdate(
    { _id: id, customerId },
    { $set: { isRead: true } },
    { new: true }
  )
    .select("_id type title message isRead sentAt")
    .lean();

  if (!updated) throw new ApiError(404, "Notification not found");

  res.status(200).json(new ApiResponse(200, "Marked as read", updated));
});

/**
 * DELETE /api/v1/customer/me/notifications/:id
 * Delete a single notification belonging to this customer.
 */
export const deleteNotification = asyncHandler(async (req, res) => {
  const { customerId } = req.user;
  if (!customerId) throw new ApiError(403, "Customer ID not found in token");

  const { id } = req.params;
  const deleted = await Notification.findOneAndDelete({
    _id: id,
    customerId,
  }).lean();

  if (!deleted) throw new ApiError(404, "Notification not found");

  res
    .status(200)
    .json(new ApiResponse(200, "Notification deleted", { id: deleted._id }));
});

/**
 * DELETE /api/v1/customer/me/notifications/clear-read
 * Delete all read notifications for this customer.
 */
export const clearReadNotifications = asyncHandler(async (req, res) => {
  const { customerId } = req.user;
  if (!customerId) throw new ApiError(403, "Customer ID not found in token");

  const result = await Notification.deleteMany({
    customerId,
    isRead: true,
  });

  res.status(200).json(
    new ApiResponse(200, "Read notifications cleared", {
      deletedCount: result.deletedCount,
    })
  );
});

/**
 * PATCH /api/v1/customer/me/notifications/read-all
 * Mark all notifications as read for this customer.
 */
export const markAllNotificationsRead = asyncHandler(async (req, res) => {
  const { customerId } = req.user;
  if (!customerId) throw new ApiError(403, "Customer ID not found in token");

  await Notification.updateMany({ customerId }, { $set: { isRead: true } });

  res
    .status(200)
    .json(new ApiResponse(200, "All notifications marked as read", null));
});
