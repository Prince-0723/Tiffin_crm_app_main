import Joi from "joi";
import mongoose from "mongoose";
import User from "../models/User.model.js";
import Customer from "../models/Customer.model.js";
import DeliveryStaff from "../models/DeliveryStaff.model.js";
import MealPlan from "../models/Plan.model.js";
import Item from "../models/Item.model.js";
import DailyOrder from "../models/DailyOrder.model.js";
import Subscription from "../models/Subscription.model.js";
import Payment from "../models/Payment.model.js";
import Invoice from "../models/Invoice.model.js";
import Notification from "../models/Notification.model.js";
import { asyncHandler } from "../utils/asyncHandler.js";
import { ApiResponse } from "../class/apiResponseClass.js";
import { ApiError } from "../class/apiErrorClass.js";

// ─── shared helpers ──────────────────────────────────────────────────────────

const paginationSchema = Joi.object({
  page: Joi.number().integer().min(1).optional(),
  limit: Joi.number().integer().min(1).max(200).optional(),
  vendorId: Joi.string().hex().length(24).optional(),
});

const paginate = (query, page = 1, limit = 20) => ({
  skip: (page - 1) * limit,
  limit: Math.min(limit, 200),
});

// ─── vendors ─────────────────────────────────────────────────────────────────

/**
 * GET /api/v1/admin/vendors
 * All users with role: vendor.
 * Query: page, limit, isActive
 */
export const listVendors = asyncHandler(async (req, res) => {
  const schema = paginationSchema.keys({
    isActive: Joi.boolean().truthy("true").falsy("false").optional(),
  });

  const { error, value } = schema.validate(req.query, {
    stripUnknown: true,
    abortEarly: false,
  });
  if (error) throw new ApiError(400, error.details.map((d) => d.message).join("; "));

  const page = value.page || 1;
  const limit = value.limit || 20;
  const { skip } = paginate(null, page, limit);

  const filter = { role: "vendor" };
  if (typeof value.isActive === "boolean") filter.isActive = value.isActive;

  const [data, total] = await Promise.all([
    User.find(filter)
      .select("businessName ownerName phone email city isActive invoiceCounter createdAt lastLoginAt settings.lowBalanceThreshold")
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit)
      .lean(),
    User.countDocuments(filter),
  ]);

  res.status(200).json(
    new ApiResponse(200, "Vendors fetched", {
      data,
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
    })
  );
});

// ─── customers ───────────────────────────────────────────────────────────────

/**
 * GET /api/v1/admin/customers
 * All customers across all vendors.
 * Query: page, limit, vendorId, status
 */
export const listAllCustomers = asyncHandler(async (req, res) => {
  const schema = paginationSchema.keys({
    status: Joi.string().valid("active", "inactive", "blocked").optional(),
  });

  const { error, value } = schema.validate(req.query, {
    stripUnknown: true,
    abortEarly: false,
  });
  if (error) throw new ApiError(400, error.details.map((d) => d.message).join("; "));

  const page = value.page || 1;
  const limit = value.limit || 20;
  const { skip } = paginate(null, page, limit);

  const filter = { isDeleted: { $ne: true } };
  if (value.vendorId) filter.ownerId = value.vendorId;
  if (value.status) filter.status = value.status;

  const [data, total] = await Promise.all([
    Customer.find(filter)
      .populate("ownerId", "businessName ownerName phone")
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit)
      .lean(),
    Customer.countDocuments(filter),
  ]);

  res.status(200).json(
    new ApiResponse(200, "Customers fetched", {
      data,
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
    })
  );
});

// ─── delivery staff ───────────────────────────────────────────────────────────

/**
 * GET /api/v1/admin/delivery-staff
 * All delivery staff across all vendors.
 * Query: page, limit, vendorId, isActive
 */
export const listAllDeliveryStaff = asyncHandler(async (req, res) => {
  const schema = paginationSchema.keys({
    isActive: Joi.boolean().truthy("true").falsy("false").optional(),
  });

  const { error, value } = schema.validate(req.query, {
    stripUnknown: true,
    abortEarly: false,
  });
  if (error) throw new ApiError(400, error.details.map((d) => d.message).join("; "));

  const page = value.page || 1;
  const limit = value.limit || 20;
  const { skip } = paginate(null, page, limit);

  const filter = {};
  if (value.vendorId) filter.ownerId = value.vendorId;
  if (typeof value.isActive === "boolean") filter.isActive = value.isActive;

  const [data, total] = await Promise.all([
    DeliveryStaff.find(filter)
      .populate("ownerId", "businessName ownerName phone")
      .sort({ createdAt: -1 })
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

// ─── meal plans ───────────────────────────────────────────────────────────────

/**
 * GET /api/v1/admin/plans
 * All meal plans across all vendors.
 * Query: page, limit, vendorId, isActive
 */
export const listAllPlans = asyncHandler(async (req, res) => {
  const schema = paginationSchema.keys({
    isActive: Joi.boolean().truthy("true").falsy("false").optional(),
  });

  const { error, value } = schema.validate(req.query, {
    stripUnknown: true,
    abortEarly: false,
  });
  if (error) throw new ApiError(400, error.details.map((d) => d.message).join("; "));

  const page = value.page || 1;
  const limit = value.limit || 20;
  const { skip } = paginate(null, page, limit);

  const filter = {};
  if (value.vendorId) filter.ownerId = value.vendorId;
  if (typeof value.isActive === "boolean") filter.isActive = value.isActive;

  const [data, total] = await Promise.all([
    MealPlan.find(filter)
      .populate("ownerId", "businessName ownerName phone")
      .populate("customerId", "name phone")
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit)
      .lean(),
    MealPlan.countDocuments(filter),
  ]);

  res.status(200).json(
    new ApiResponse(200, "Meal plans fetched", {
      data,
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
    })
  );
});

// ─── items ────────────────────────────────────────────────────────────────────

/**
 * GET /api/v1/admin/items
 * All food items across all vendors.
 * Query: page, limit, vendorId, isActive
 */
export const listAllItems = asyncHandler(async (req, res) => {
  const schema = paginationSchema.keys({
    isActive: Joi.boolean().truthy("true").falsy("false").optional(),
  });

  const { error, value } = schema.validate(req.query, {
    stripUnknown: true,
    abortEarly: false,
  });
  if (error) throw new ApiError(400, error.details.map((d) => d.message).join("; "));

  const page = value.page || 1;
  const limit = value.limit || 20;
  const { skip } = paginate(null, page, limit);

  const filter = {};
  if (value.vendorId) filter.ownerId = value.vendorId;
  if (typeof value.isActive === "boolean") filter.isActive = value.isActive;

  const [data, total] = await Promise.all([
    Item.find(filter)
      .populate("ownerId", "businessName ownerName phone")
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit)
      .lean(),
    Item.countDocuments(filter),
  ]);

  res.status(200).json(
    new ApiResponse(200, "Items fetched", {
      data,
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
    })
  );
});

// ─── subscriptions ────────────────────────────────────────────────────────────

/**
 * GET /api/v1/admin/subscriptions
 * All subscriptions across all vendors.
 * Query: page, limit, vendorId, status
 */
export const listAllSubscriptions = asyncHandler(async (req, res) => {
  const schema = paginationSchema.keys({
    status: Joi.string()
      .valid("active", "paused", "expired", "cancelled")
      .optional(),
  });

  const { error, value } = schema.validate(req.query, {
    stripUnknown: true,
    abortEarly: false,
  });
  if (error) throw new ApiError(400, error.details.map((d) => d.message).join("; "));

  const page = value.page || 1;
  const limit = value.limit || 20;
  const { skip } = paginate(null, page, limit);

  const filter = {};
  if (value.vendorId) filter.ownerId = value.vendorId;
  if (value.status) filter.status = value.status;

  const [data, total] = await Promise.all([
    Subscription.find(filter)
      .populate("ownerId", "businessName ownerName phone")
      .populate("customerId", "name phone address balance")
      .populate("planId", "planName price planType")
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit)
      .lean(),
    Subscription.countDocuments(filter),
  ]);

  res.status(200).json(
    new ApiResponse(200, "Subscriptions fetched", {
      data,
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
    })
  );
});

// ─── daily orders ─────────────────────────────────────────────────────────────

/**
 * GET /api/v1/admin/orders
 * All daily orders across all vendors.
 * Query: page, limit, vendorId, status, date (YYYY-MM-DD)
 */
export const listAllOrders = asyncHandler(async (req, res) => {
  const schema = paginationSchema.keys({
    status: Joi.string()
      .valid("pending", "processing", "out_for_delivery", "delivered", "cancelled", "failed", "skipped")
      .optional(),
    date: Joi.string()
      .pattern(/^\d{4}-\d{2}-\d{2}$/)
      .optional()
      .messages({ "string.pattern.base": "date must be YYYY-MM-DD" }),
  });

  const { error, value } = schema.validate(req.query, {
    stripUnknown: true,
    abortEarly: false,
  });
  if (error) throw new ApiError(400, error.details.map((d) => d.message).join("; "));

  const page = value.page || 1;
  const limit = value.limit || 20;
  const { skip } = paginate(null, page, limit);

  const filter = {};
  if (value.vendorId) filter.ownerId = value.vendorId;
  if (value.status) filter.status = value.status;
  if (value.date) {
    const [y, m, d] = value.date.split("-").map(Number);
    filter.orderDate = new Date(Date.UTC(y, m - 1, d));
  }

  const [data, total] = await Promise.all([
    DailyOrder.find(filter)
      .populate("ownerId", "businessName ownerName phone")
      .populate("customerId", "name phone address")
      .populate("deliveryStaffId", "name phone")
      .sort({ orderDate: -1, createdAt: -1 })
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

// ─── payments ─────────────────────────────────────────────────────────────────

/**
 * GET /api/v1/admin/payments
 * All payment transactions across all vendors.
 * Query: page, limit, vendorId, status, type
 */
export const listAllPayments = asyncHandler(async (req, res) => {
  const schema = paginationSchema.keys({
    status: Joi.string().valid("pending", "captured", "failed", "refunded").optional(),
    type: Joi.string().valid("payment", "wallet_credit", "order_deduction").optional(),
  });

  const { error, value } = schema.validate(req.query, {
    stripUnknown: true,
    abortEarly: false,
  });
  if (error) throw new ApiError(400, error.details.map((d) => d.message).join("; "));

  const page = value.page || 1;
  const limit = value.limit || 20;
  const { skip } = paginate(null, page, limit);

  const filter = {};
  if (value.vendorId) filter.ownerId = value.vendorId;
  if (value.status) filter.status = value.status;
  if (value.type) filter.type = value.type;

  const [data, total] = await Promise.all([
    Payment.find(filter)
      .populate("ownerId", "businessName ownerName phone")
      .populate("customerId", "name phone")
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit)
      .lean(),
    Payment.countDocuments(filter),
  ]);

  res.status(200).json(
    new ApiResponse(200, "Payments fetched", {
      data,
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
    })
  );
});

// ─── invoices ─────────────────────────────────────────────────────────────────

/**
 * GET /api/v1/admin/invoices
 * All invoices across all vendors.
 * Query: page, limit, vendorId, paymentStatus
 */
export const listAllInvoices = asyncHandler(async (req, res) => {
  const schema = paginationSchema.keys({
    paymentStatus: Joi.string().valid("unpaid", "partial", "paid").optional(),
  });

  const { error, value } = schema.validate(req.query, {
    stripUnknown: true,
    abortEarly: false,
  });
  if (error) throw new ApiError(400, error.details.map((d) => d.message).join("; "));

  const page = value.page || 1;
  const limit = value.limit || 20;
  const { skip } = paginate(null, page, limit);

  const filter = {};
  if (value.vendorId) filter.ownerId = value.vendorId;
  if (value.paymentStatus) filter.paymentStatus = value.paymentStatus;

  const [data, total] = await Promise.all([
    Invoice.find(filter)
      .populate("ownerId", "businessName ownerName phone")
      .populate("customerId", "name phone")
      .populate("subscriptionId", "startDate endDate status")
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit)
      .lean(),
    Invoice.countDocuments(filter),
  ]);

  res.status(200).json(
    new ApiResponse(200, "Invoices fetched", {
      data,
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
    })
  );
});

// ─── notifications ────────────────────────────────────────────────────────────

/**
 * GET /api/v1/admin/notifications
 * All in-app notifications across all vendors.
 * Query: page, limit, vendorId, type, isRead
 */
export const listAllNotifications = asyncHandler(async (req, res) => {
  const schema = paginationSchema.keys({
    type: Joi.string().optional(),
    isRead: Joi.boolean().truthy("true").falsy("false").optional(),
  });

  const { error, value } = schema.validate(req.query, {
    stripUnknown: true,
    abortEarly: false,
  });
  if (error) throw new ApiError(400, error.details.map((d) => d.message).join("; "));

  const page = value.page || 1;
  const limit = value.limit || 20;
  const { skip } = paginate(null, page, limit);

  const filter = {};
  if (value.vendorId) filter.ownerId = value.vendorId;
  if (value.type) filter.type = value.type;
  if (typeof value.isRead === "boolean") filter.isRead = value.isRead;

  const [data, total] = await Promise.all([
    Notification.find(filter)
      .populate("ownerId", "businessName ownerName phone")
      .populate("customerId", "name phone")
      .sort({ createdAt: -1 })
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

// ─── system stats ─────────────────────────────────────────────────────────────

/**
 * GET /api/v1/admin/stats
 * System-wide aggregate statistics.
 */
export const getSystemStats = asyncHandler(async (req, res) => {
  const today = new Date();
  today.setUTCHours(0, 0, 0, 0);
  const tomorrow = new Date(today);
  tomorrow.setUTCDate(tomorrow.getUTCDate() + 1);
  const monthAgo = new Date();
  monthAgo.setMonth(monthAgo.getMonth() - 1);

  const [
    totalVendors,
    activeVendors,
    totalCustomers,
    totalDeliveryStaff,
    totalPlans,
    activeSubscriptions,
    todayOrders,
    todayDelivered,
    monthlyRevenue,
    totalOrdersAllTime,
    todayRevenueAgg,
  ] = await Promise.all([
    User.countDocuments({ role: "vendor" }),
    User.countDocuments({ role: "vendor", isActive: true }),
    Customer.countDocuments({ isDeleted: { $ne: true } }),
    DeliveryStaff.countDocuments({ isActive: true }),
    MealPlan.countDocuments({ isActive: true }),
    Subscription.countDocuments({ status: "active" }),
    DailyOrder.countDocuments({ orderDate: today }),
    DailyOrder.countDocuments({ orderDate: today, status: "delivered" }),
    Payment.aggregate([
      {
        $match: {
          status: "captured",
          createdAt: { $gte: monthAgo },
        },
      },
      { $group: { _id: null, total: { $sum: "$amount" } } },
    ]),
    DailyOrder.countDocuments({}),
    Payment.aggregate([
      {
        $match: {
          status: "captured",
          createdAt: { $gte: today, $lt: tomorrow },
        },
      },
      { $group: { _id: null, total: { $sum: "$amount" } } },
    ]),
  ]);

  res.status(200).json(
    new ApiResponse(200, "System stats fetched", {
      vendors: { total: totalVendors, active: activeVendors },
      customers: { total: totalCustomers },
      deliveryStaff: { total: totalDeliveryStaff },
      plans: { active: totalPlans },
      subscriptions: { active: activeSubscriptions },
      totalOrders: totalOrdersAllTime,
      todayOrders: {
        total: todayOrders,
        delivered: todayDelivered,
        pending: todayOrders - todayDelivered,
      },
      revenue: {
        last30Days: monthlyRevenue[0]?.total || 0,
        today: todayRevenueAgg[0]?.total || 0,
      },
    })
  );
});

// ─── vendor stats (per-vendor customer / subscription counts) ─────────────────

/**
 * GET /api/v1/admin/vendors/stats
 * Per-vendor customer totals and subscription-status breakdown (distinct customers).
 */
export const getVendorStats = asyncHandler(async (req, res) => {
  const [vendors, customerTotals, subCounts] = await Promise.all([
    User.find({ role: "vendor" })
      .select("_id businessName ownerName")
      .lean(),
    Customer.aggregate([
      { $match: { isDeleted: { $ne: true } } },
      { $group: { _id: "$ownerId", totalCustomers: { $sum: 1 } } },
    ]),
    Subscription.aggregate([
      {
        $group: {
          _id: {
            ownerId: "$ownerId",
            customerId: "$customerId",
            status: "$status",
          },
        },
      },
      {
        $group: {
          _id: {
            ownerId: "$_id.ownerId",
            status: "$_id.status",
          },
          count: { $sum: 1 },
        },
      },
    ]),
  ]);

  const customerMap = Object.fromEntries(
    customerTotals.map((r) => [r._id.toString(), r.totalCustomers])
  );

  const subByVendor = {};
  for (const row of subCounts) {
    const vid = row._id.ownerId.toString();
    if (!subByVendor[vid]) {
      subByVendor[vid] = { active: 0, paused: 0, expired: 0 };
    }
    const st = row._id.status;
    const c = row.count;
    if (st === "active") subByVendor[vid].active = c;
    else if (st === "paused") subByVendor[vid].paused = c;
    else if (st === "expired" || st === "cancelled") {
      subByVendor[vid].expired += c;
    }
  }

  const rows = vendors
    .map((v) => {
      const id = v._id.toString();
      const sub = subByVendor[id] || { active: 0, paused: 0, expired: 0 };
      return {
        vendorId: id,
        vendorName: v.businessName || v.ownerName || "—",
        totalCustomers: customerMap[id] || 0,
        activeCustomers: sub.active,
        pausedCustomers: sub.paused,
        expiredCustomers: sub.expired,
      };
    })
    .sort((a, b) => b.totalCustomers - a.totalCustomers);

  res.status(200).json(new ApiResponse(200, "Vendor stats fetched", rows));
});
