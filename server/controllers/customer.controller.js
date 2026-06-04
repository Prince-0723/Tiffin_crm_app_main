import Joi from "joi";
import mongoose from "mongoose";
import Customer, { CUSTOMER_STATUSES } from "../models/Customer.model.js";
import Payment, { PAYMENT_METHODS } from "../models/Payment.model.js";
import User from "../models/User.model.js";
import Subscription from "../models/Subscription.model.js";
import DailyOrder from "../models/DailyOrder.model.js";
import { settlePayLaterSubscriptions } from "../utils/subscriptionPayLater.js";
import Zone from "../models/Zone.model.js";
import { parseCustomerCsv } from "../utils/parseCustomerCsv.js";
import {
  normalizeCustomerPhone,
  isValidIndianMobile,
} from "../utils/normalizeCustomerPhone.js";
import { asyncHandler } from "../utils/asyncHandler.js";
import {
  displayWalletBalance,
  effectiveWallet,
} from "../utils/customerWallet.js";
import { notifyIfWalletJustHitZero } from "../utils/walletZeroNotification.js";
import { ApiResponse } from "../class/apiResponseClass.js";
import { ApiError } from "../class/apiErrorClass.js";

const MAX_LIMIT = 100;
const DEFAULT_LIMIT = 20;
const DEFAULT_PAGE = 1;

const phoneSchema = Joi.string().trim().required().messages({
  "string.empty": "Phone is required",
});

const createCustomerSchema = Joi.object({
  name: Joi.string()
    .trim()
    .required()
    .messages({ "string.empty": "Name is required" }),
  phone: phoneSchema,
  address: Joi.string()
    .trim()
    .required()
    .messages({ "string.empty": "Address is required" }),
  area: Joi.string().trim().allow("").optional(),
  zoneId: Joi.string().hex().length(24).allow(null, "").optional(),
  landmark: Joi.string().trim().allow("").optional(),
  whatsapp: Joi.string().trim().allow("").optional(),
  notes: Joi.string().trim().allow("").optional(),
  tags: Joi.array().items(Joi.string().trim()).optional(),
  creditLimit: Joi.number().min(0).optional(),
  status: Joi.string()
    .valid(...CUSTOMER_STATUSES)
    .optional(),
  location: Joi.object({
    type: Joi.string().valid("Point").optional(),
    coordinates: Joi.array().items(Joi.number()).length(2).optional(), // [lng, lat]
  }).optional(),
});

const updateCustomerSchema = Joi.object({
  name: Joi.string().trim().optional(),
  phone: Joi.string().trim().optional(),
  address: Joi.string().trim().allow("").optional(),
  area: Joi.string().trim().allow("").optional(),
  zoneId: Joi.string().hex().length(24).allow(null, "").optional(),
  landmark: Joi.string().trim().allow("").optional(),
  whatsapp: Joi.string().trim().allow("").optional(),
  notes: Joi.string().trim().allow("").optional(),
  tags: Joi.array().items(Joi.string().trim()).optional(),
  creditLimit: Joi.number().min(0).optional(),
  status: Joi.string()
    .valid(...CUSTOMER_STATUSES)
    .optional(),
  isDeleted: Joi.boolean().optional(),
  location: Joi.object({
    type: Joi.string().valid("Point").optional(),
    coordinates: Joi.array().items(Joi.number()).length(2).optional(),
  }).optional(),
}).min(1);

const listQuerySchema = Joi.object({
  page: Joi.number().integer().min(1).optional(),
  limit: Joi.number().integer().min(1).max(MAX_LIMIT).optional(),
  status: Joi.string()
    .valid(...CUSTOMER_STATUSES)
    .optional(),
  lowBalance: Joi.boolean().truthy("true").falsy("false").optional(),
});

const bulkPhoneSchema = Joi.string()
  .trim()
  .required()
  .custom((value, helpers) => {
    const n = normalizeCustomerPhone(value);
    if (!isValidIndianMobile(n)) {
      return helpers.error("any.invalid");
    }
    return n;
  })
  .messages({
    "any.invalid": "Phone must be a valid 10-digit Indian mobile number",
  });

const bulkCustomerItemSchema = Joi.object({
  name: Joi.string()
    .trim()
    .required()
    .messages({ "string.empty": "Name is required" }),
  phone: bulkPhoneSchema,
  address: Joi.string().trim().allow("").optional(),
  zone: Joi.string().trim().allow("").optional(),
  status: Joi.string()
    .valid(...CUSTOMER_STATUSES)
    .optional(),
  whatsapp: Joi.string().trim().allow("").optional(),
});

const bulkCreateSchema = Joi.object({
  customers: Joi.array()
    .items(bulkCustomerItemSchema)
    .min(1)
    .max(100)
    .required(),
});

const bulkCsvSchema = Joi.object({
  csv: Joi.string().trim().min(1).max(200_000).required(),
});

const bulkBodySchema = Joi.alternatives()
  .try(bulkCreateSchema, bulkCsvSchema)
  .required()
  .messages({
    "alternatives.match": "Provide either customers (array) or csv (string)",
  });

/**
 * GET /api/v1/customers
 * Query: page, limit, status, customerType
 */
export const listCustomers = asyncHandler(async (req, res) => {
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
  const filter = { ownerId, isDeleted: { $ne: true } };
  if (value.status) filter.status = value.status;

  if (value.lowBalance) {
    const vendor = await User.findById(ownerId).select("settings").lean();
    const threshold = vendor?.settings?.lowBalanceThreshold ?? 100;
    filter.$or = [{ walletBalance: { $lt: threshold } }, { balance: { $lt: threshold } }];
  }

  const [data, total] = await Promise.all([
    Customer.find(filter)
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit)
      .lean(),
    Customer.countDocuments(filter),
  ]);

  const totalPages = Math.ceil(total / limit);

  // Prefer the dedicated whatsapp number if set; fall back to the registered phone.
  const enriched = data.map((c) => {
    const w = displayWalletBalance(c);
    return {
      ...c,
      balance: w,
      walletBalance: w,
      whatsappUrl: `https://wa.me/91${c.whatsapp || c.phone}`,
    };
  });

  const response = new ApiResponse(200, "Customers fetched", {
    data: enriched,
    total,
    page,
    limit,
    totalPages,
  });

  res.status(response.statusCode).json({
    success: response.success,
    message: response.message,
    data: response.data,
  });
});

/**
 * GET /api/v1/customers/:id
 */
export const getCustomerById = asyncHandler(async (req, res) => {
  const ownerId = req.user.userId;
  const { id } = req.params;
  const customer = await Customer.findOne({
    _id: id,
    ownerId,
    isDeleted: { $ne: true },
  }).lean();

  if (!customer) {
    throw new ApiError(404, "Customer not found");
  }

  const w = displayWalletBalance(customer);
  let zoneName = "";
  if (customer.zoneId) {
    const zone = await Zone.findById(customer.zoneId).select("name").lean();
    zoneName = zone?.name ? String(zone.name) : "";
  }
  const data = {
    ...customer,
    balance: w,
    walletBalance: w,
    whatsappUrl: `https://wa.me/91${customer.whatsapp || customer.phone}`,
    zoneName,
  };

  const response = new ApiResponse(200, "Customer fetched", data);
  res.status(response.statusCode).json({
    success: response.success,
    message: response.message,
    data: response.data,
  });
});

/**
 * POST /api/v1/customers
 */
export const createCustomer = asyncHandler(async (req, res) => {
  const { error, value } = createCustomerSchema.validate(req.body, {
    stripUnknown: true,
    abortEarly: false,
  });
  if (error) {
    throw new ApiError(400, error.details.map((d) => d.message).join("; "));
  }

  const ownerId = req.user.userId;

  const phone = String(value.phone)
    .trim()
    .replace(/^(\+91|0091)/, "");

  const existing = await Customer.findOne({
    phone,
    ownerId,
    isDeleted: { $ne: true },
  });
  if (existing) {
    throw new ApiError(409, "Customer with this phone already exists");
  }

  const payload = {
    ownerId,
    name: value.name.trim(),
    phone,
    address: value.address || "",
    area: value.area || "",
    landmark: value.landmark || "",
    status: value.status || "active",
    whatsapp: value.whatsapp || null,
    notes: value.notes || "",
    tags: value.tags || [],
    creditLimit: Number(value.creditLimit || 0),
    zoneId: value.zoneId ? value.zoneId : null,
  };

  if (value.location?.coordinates?.length === 2) {
    payload.location = {
      type: "Point",
      coordinates: value.location.coordinates,
    };
  }

  const customer = await Customer.create(payload);
  const created = customer.toObject();

  const response = new ApiResponse(201, "Customer created", created);
  res.status(response.statusCode).json({
    success: response.success,
    message: response.message,
    data: response.data,
  });
});

/**
 * PUT /api/v1/customers/:id
 */
export const updateCustomer = asyncHandler(async (req, res) => {
  const ownerId = req.user.userId;
  const { id } = req.params;

  const { error, value } = updateCustomerSchema.validate(req.body, {
    stripUnknown: true,
    abortEarly: false,
  });
  if (error) {
    throw new ApiError(400, error.details.map((d) => d.message).join("; "));
  }

  const customer = await Customer.findOne({
    _id: id,
    ownerId,
    isDeleted: { $ne: true },
  });
  if (!customer) {
    throw new ApiError(404, "Customer not found");
  }

  if (value.phone) {
    const phone = String(value.phone)
      .trim()
      .replace(/^(\+91|0091)/, "");

    const existing = await Customer.findOne({
      phone,
      _id: { $ne: id },
      isDeleted: { $ne: true },
    });
    if (existing) {
      throw new ApiError(
        409,
        "Another customer with this phone already exists"
      );
    }
    value.phone = phone;
  }

  const updatePayload = { ...value };
  if (Object.prototype.hasOwnProperty.call(updatePayload, "zoneId")) {
    // Normalize empty string → null
    if (!updatePayload.zoneId) updatePayload.zoneId = null;
  }
  if (value.location?.coordinates?.length === 2) {
    updatePayload.location = {
      type: "Point",
      coordinates: value.location.coordinates,
    };
  }

  const updated = await Customer.findByIdAndUpdate(
    id,
    { $set: updatePayload },
    { new: true }
  ).lean();

  const wUp = displayWalletBalance(updated);
  let zoneNameUp = "";
  if (updated.zoneId) {
    const zone = await Zone.findById(updated.zoneId).select("name").lean();
    zoneNameUp = zone?.name ? String(zone.name) : "";
  }
  const payload = {
    ...updated,
    balance: wUp,
    walletBalance: wUp,
    whatsappUrl: `https://wa.me/91${updated.whatsapp || updated.phone}`,
    zoneName: zoneNameUp,
  };

  const response = new ApiResponse(200, "Customer updated", payload);
  res.status(response.statusCode).json({
    success: response.success,
    message: response.message,
    data: response.data,
  });
});

/**
 * POST /api/v1/customers/bulk
 * Body: { customers: [{ name, phone, address?, zone? }] } or { csv: "name,phone,address,zone\\n..." }
 * Rate limited: 5 req/15 min
 */
export const bulkCreateCustomers = asyncHandler(async (req, res) => {
  const ownerId = req.user.userId;
  const { error, value } = bulkBodySchema.validate(req.body, {
    stripUnknown: true,
    abortEarly: false,
  });
  if (error) {
    throw new ApiError(400, error.details.map((d) => d.message).join("; "));
  }

  let sourceRows;
  let totalRows;

  if (value.csv) {
    const parsed = parseCustomerCsv(value.csv);
    if (parsed.errors.length) {
      throw new ApiError(400, parsed.errors.join("; "));
    }
    if (parsed.rows.length > 100) {
      throw new ApiError(400, "CSV cannot contain more than 100 data rows");
    }
    totalRows = parsed.rows.length;
    sourceRows = parsed.rows.map((r) => ({
      lineNumber: r.lineNumber,
      name: r.name,
      phone: normalizeCustomerPhone(r.phone),
      address: r.address,
      zoneName: (r.zone || "").trim(),
    }));
  } else {
    totalRows = value.customers.length;
    sourceRows = value.customers.map((c, idx) => ({
      lineNumber: idx + 1,
      name: c.name,
      phone: c.phone,
      address: c.address || "",
      zoneName: (c.zone || "").trim(),
    }));
  }

  const zones = await Zone.find({ ownerId }).select("name").lean();
  const zoneByName = new Map();
  for (const z of zones) {
    zoneByName.set(String(z.name).trim().toLowerCase(), z._id);
  }

  const rowErrors = [];
  const validated = [];
  for (const r of sourceRows) {
    if (!r.name?.trim()) {
      rowErrors.push({ line: r.lineNumber, message: "Name is required" });
      continue;
    }
    if (!isValidIndianMobile(r.phone)) {
      rowErrors.push({ line: r.lineNumber, message: "Invalid phone number" });
      continue;
    }
    if (value.csv && !String(r.address || "").trim()) {
      rowErrors.push({ line: r.lineNumber, message: "Address is required" });
      continue;
    }
    let zoneId = null;
    let zoneWarning = null;
    if (r.zoneName) {
      const id = zoneByName.get(r.zoneName.toLowerCase());
      if (id) zoneId = id;
      else zoneWarning = `Unknown zone "${r.zoneName}"`;
    }
    validated.push({
      lineNumber: r.lineNumber,
      name: r.name.trim(),
      phone: r.phone,
      address: String(r.address).trim(),
      zoneId,
      zoneWarning,
    });
  }

  const phones = validated.map((c) => c.phone);
  const existingCustomers = await Customer.find({
    ownerId,
    phone: { $in: phones },
    isDeleted: { $ne: true },
  })
    .select("phone")
    .lean();

  const existingPhones = new Set(existingCustomers.map((c) => c.phone));

  const duplicateErrors = [];
  const pendingDocs = [];
  for (const c of validated) {
    if (existingPhones.has(c.phone)) {
      duplicateErrors.push({
        line: c.lineNumber,
        message: "Phone already registered",
      });
      continue;
    }
    existingPhones.add(c.phone);
    pendingDocs.push({
      lineNumber: c.lineNumber,
      zoneWarning: c.zoneWarning,
      doc: {
        ownerId,
        name: c.name,
        phone: c.phone,
        address: c.address,
        area: "",
        landmark: "",
        status: "active",
        whatsapp: null,
        notes: "",
        tags: [],
        zoneId: c.zoneId,
      },
    });
  }

  if (pendingDocs.length === 0) {
    const detail = [...rowErrors, ...duplicateErrors]
      .map((e) => `Line ${e.line}: ${e.message}`)
      .join("; ");
    throw new ApiError(
      400,
      detail || "All phones already exist or no valid rows to import"
    );
  }

  const inserted = await Customer.insertMany(pendingDocs.map((p) => p.doc));
  const created = inserted.length;
  const skipped = totalRows - created;
  const warnings = pendingDocs
    .filter((p) => p.zoneWarning)
    .map((p) => ({ line: p.lineNumber, message: p.zoneWarning }));

  const response = new ApiResponse(201, "Bulk import completed", {
    created,
    imported: created,
    skipped,
    errors: [...rowErrors, ...duplicateErrors],
    warnings,
    data: inserted.map((c) => c.toObject()),
  });

  res.status(response.statusCode).json({
    success: response.success,
    message: response.message,
    data: response.data,
  });
});

const walletCreditSchema = Joi.object({
  amount: Joi.number().precision(2).min(0.01).required().messages({
    "number.base": "Amount is required",
    "number.min": "Amount must be greater than 0",
  }),
  paymentMethod: Joi.string()
    .valid(...PAYMENT_METHODS)
    .optional(),
  notes: Joi.string().trim().allow("").optional(),
});

const walletDebitSchema = Joi.object({
  amount: Joi.number().precision(2).min(0.01).required().messages({
    "number.base": "Amount is required",
    "number.min": "Amount must be greater than 0",
  }),
  notes: Joi.string().trim().allow("").optional(),
});

/**
 * POST /api/v1/customers/:id/wallet/credit
 * Vendor adds cash/offline balance to customer wallet.
 * Increments customer wallet and creates a Payment record.
 */
export const walletCredit = asyncHandler(async (req, res) => {
  const { error, value } = walletCreditSchema.validate(req.body, {
    stripUnknown: true,
    abortEarly: false,
  });
  if (error) {
    throw new ApiError(400, error.details.map((d) => d.message).join("; "));
  }

  const ownerId = req.user.userId;
  const { id } = req.params;

  const customer = await Customer.findOne({
    _id: id,
    ownerId,
    isDeleted: { $ne: true },
  });
  if (!customer) throw new ApiError(404, "Customer not found");

  const session = await mongoose.startSession();
  session.startTransaction();

  try {
    const amt = Number(value.amount);
    const cid = new mongoose.Types.ObjectId(id);
    const oid = new mongoose.Types.ObjectId(ownerId);

    const { remainder, appliedToSubscription } =
      await settlePayLaterSubscriptions({
        session,
        ownerId: oid,
        customerId: cid,
        amount: amt,
      });

    const updatedCustomer = await Customer.findByIdAndUpdate(
      id,
      { $inc: { balance: remainder, walletBalance: remainder } },
      { new: true, session }
    ).lean();

    const noteParts = [value.notes?.trim() || ""];
    if (appliedToSubscription > 0) {
      noteParts.push(
        `₹${appliedToSubscription.toFixed(0)} toward plan dues`
      );
    }
    const [payment] = await Payment.create(
      [
        {
          ownerId,
          customerId: id,
          amount: amt,
          paymentMethod: value.paymentMethod || "cash",
          notes: noteParts.filter(Boolean).join(" · "),
          status: "captured",
          type: "wallet_credit",
        },
      ],
      { session }
    );

    await session.commitTransaction();
    session.endSession();

    res.status(201).json(
      new ApiResponse(201, "Balance added successfully", {
        newBalance: displayWalletBalance(updatedCustomer),
        amountAdded: value.amount,
        paymentId: payment._id,
      })
    );
  } catch (err) {
    await session.abortTransaction();
    session.endSession();
    throw err;
  }
});

/**
 * POST /api/v1/customers/:id/wallet/debit
 * Vendor manually deducts from customer wallet.
 * Decrements both balance fields to keep them consistent.
 */
export const walletDebit = asyncHandler(async (req, res) => {
  const { error, value } = walletDebitSchema.validate(req.body, {
    stripUnknown: true,
    abortEarly: false,
  });
  if (error) {
    throw new ApiError(400, error.details.map((d) => d.message).join("; "));
  }

  const ownerId = req.user.userId;
  const { id } = req.params;
  const amount = Number(value.amount);

  const customer = await Customer.findOne({
    _id: id,
    ownerId,
    isDeleted: { $ne: true },
  })
    .select("balance walletBalance")
    .lean();
  if (!customer) throw new ApiError(404, "Customer not found");

  const currentWallet = effectiveWallet(customer);
  if (currentWallet < amount) {
    throw new ApiError(400, "Insufficient wallet balance");
  }

  const session = await mongoose.startSession();
  session.startTransaction();
  try {
    const updatedCustomer = await Customer.findByIdAndUpdate(
      id,
      { $inc: { balance: -amount, walletBalance: -amount } },
      { new: true, session }
    ).lean();

    const [payment] = await Payment.create(
      [
        {
          ownerId,
          customerId: id,
          amount,
          paymentMethod: "cash",
          notes: value.notes || "Manual wallet deduction",
          status: "captured",
          type: "order_deduction",
        },
      ],
      { session }
    );

    await session.commitTransaction();
    session.endSession();

    await notifyIfWalletJustHitZero({
      ownerId,
      customerId: id,
      customerBefore: customer,
      customerAfter: updatedCustomer,
    });

    res.status(201).json(
      new ApiResponse(201, "Wallet amount deducted successfully", {
        newBalance: displayWalletBalance(updatedCustomer),
        amountDeducted: amount,
        paymentId: payment._id,
      })
    );
  } catch (err) {
    await session.abortTransaction();
    session.endSession();
    throw err;
  }
});

/**
 * DELETE /api/v1/customers/:id
 * Soft delete: sets isDeleted: true
 */
export const deleteCustomer = asyncHandler(async (req, res) => {
  const ownerId = req.user.userId;
  const { id } = req.params;

  const customer = await Customer.findOne({
    _id: id,
    ownerId,
    isDeleted: { $ne: true },
  });
  if (!customer) {
    throw new ApiError(404, "Customer not found");
  }

  const updated = await Customer.findByIdAndUpdate(
    id,
    { $set: { isDeleted: true } },
    { new: true }
  ).lean();

  // Cancel customer's active/paused subscriptions
  await Subscription.updateMany(
    { customerId: id, status: { $in: ["active", "paused"] } },
    { $set: { status: "cancelled" } }
  );

  // Remove customer's pending daily orders
  await DailyOrder.deleteMany({
    customerId: id,
    status: { $in: ["pending", "processing", "out_for_delivery"] },
  });

  // Emit daily_orders_changed on /delivery socket channel
  const io = req.app.get("io");
  if (io) {
    io.of("/delivery")
      .to(`admin:${ownerId}`)
      .emit("daily_orders_changed", { reason: "customer_deleted" });
  }

  const response = new ApiResponse(200, "Customer deleted (soft)", updated);
  res.status(response.statusCode).json({
    success: response.success,
    message: response.message,
    data: response.data,
  });
});
