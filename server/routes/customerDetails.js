import { Router } from "express";
import crypto from "crypto";
import mongoose from "mongoose";
import Joi from "joi";
import Customer from "../models/Customer.model.js";
import Subscription from "../models/Subscription.model.js";
import Payment from "../models/Payment.model.js";
import Transaction from "../models/Transaction.model.js";
import DeliverySchedule from "../models/DeliverySchedule.model.js";
import DailyOrder from "../models/DailyOrder.model.js";
import User from "../models/User.model.js";
import Zone from "../models/Zone.model.js";
import { authMiddleware } from "../middleware/auth.middleware.js";
import { requireRole } from "../middleware/rbac.middleware.js";
import { asyncHandler } from "../utils/asyncHandler.js";
import { ApiResponse } from "../class/apiResponseClass.js";
import { ApiError } from "../class/apiErrorClass.js";
import { effectiveRemaining } from "../utils/subscriptionBalance.js";
import {
  displayWalletBalance,
  effectiveWallet,
} from "../utils/customerWallet.js";
import { notifyIfWalletJustHitZero } from "../utils/walletZeroNotification.js";
import { sendNotification } from "../services/inAppNotification.service.js";
import { NOTIFICATION_TYPES } from "../utils/notificationTypes.js";
import {
  istTodayYmd,
  remainingDaysInclusiveIST,
  totalDaysInclusiveIST,
  ymdIST,
} from "../utils/subscriptionCalendarDays.js";
import {
  payLaterConsumptionExposure,
  payLaterEffectiveCreditCap,
  settlePayLaterSubscriptions,
  subscriptionCashOwed,
} from "../utils/subscriptionPayLater.js";

/**
 * Shown amount for subscription history. Many legacy rows have paidAmount 0 while
 * totalAmount holds the priced period (wallet prepay); mirror subscription list normalization.
 */
function historySubscriptionAmount(sub) {
  const paid = Number(sub.paidAmount) || 0;
  const total = Number(sub.totalAmount) || 0;
  if (paid > 0) return paid;
  if (total > 0) return total;
  const plan = sub.planId;
  const price = plan && Number(plan.price);
  if (!price || !sub.startDate || !sub.endDate) return 0;
  const start = new Date(sub.startDate);
  const end = new Date(sub.endDate);
  if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime())) return 0;
  const totalDays = totalDaysInclusiveIST(start, end);
  return price * totalDays;
}

const router = Router();

/**
 * Public token verification for customer portal magic-link login.
 * GET /api/v1/customer-details/verify-token?token=...&id=...
 */
router.get(
  "/verify-token",
  asyncHandler(async (req, res) => {
    try {
      const token = String(req.query.token || "").trim();
      const id = String(req.query.id || "").trim();
      if (!token || !id || !mongoose.Types.ObjectId.isValid(id)) {
        return res
          .status(401)
          .json({ success: false, message: "Invalid or expired link" });
      }

      const customer = await Customer.findOne({
        _id: id,
        loginToken: token,
        loginTokenExpiry: { $gt: new Date() },
        isDeleted: { $ne: true },
      });

      if (!customer) {
        return res
          .status(401)
          .json({ success: false, message: "Invalid or expired link" });
      }

      const activeSub = await Subscription.findOne({
        customerId: customer._id,
        status: "active",
        endDate: { $gte: new Date() },
      })
        .sort({ endDate: -1 })
        .populate("planId", "planName")
        .lean();

      const planName = activeSub?.planId?.planName || "";

      customer.loginToken = null;
      customer.loginTokenExpiry = null;
      await customer.save();

      return res.status(200).json({
        success: true,
        customer: {
          id: String(customer._id),
          name: customer.name || "",
          phone: customer.phone || "",
          planName,
        },
      });
    } catch (_) {
      return res
        .status(500)
        .json({ success: false, message: "Failed to verify login link" });
    }
  })
);

router.use(authMiddleware);
router.use(requireRole(["vendor", "admin"]));

/** Resolve vendor owner id for scoped queries. */
function resolveOwnerId(req) {
  return req.user.ownerId || req.user.userId;
}

/** Validates Mongo ObjectId string. */
function assertObjectId(id, label = "id") {
  if (!mongoose.Types.ObjectId.isValid(id)) {
    throw new ApiError(400, `Invalid ${label}`);
  }
}

/**
 * Loads the customer for this vendor or throws 404.
 */
async function assertCustomer(ownerId, customerId) {
  assertObjectId(customerId, "customerId");
  const customer = await Customer.findOne({
    _id: customerId,
    ownerId,
    isDeleted: { $ne: true },
  }).lean();
  if (!customer) throw new ApiError(404, "Customer not found");
  return customer;
}

/** Sums meal item quantities across all slots (items per day). */
function countItemsPerDay(plan) {
  if (!plan?.mealSlots?.length) return 0;
  let n = 0;
  for (const slot of plan.mealSlots) {
    for (const it of slot.items || []) {
      n += Number(it.quantity) > 0 ? Number(it.quantity) : 1;
    }
  }
  return n;
}

/** Formats resolved daily order lines into a short label. */
function formatOrderItems(resolvedItems) {
  if (!resolvedItems?.length) return "";
  return resolvedItems
    .map((r) => {
      const name = r.itemName || "Item";
      const q = r.quantity || 1;
      return `${name} x${q}`;
    })
    .join(", ");
}

/** Short label when there are no daily orders yet (plan summary). */
function defaultItemsFromPlan(plan) {
  if (!plan) return "—";
  if (plan.planName) return String(plan.planName);
  return "—";
}

async function buildCustomerInfoPayload(ownerId, customer) {
  const sub = await Subscription.findOne({
    ownerId,
    customerId: customer._id,
    status: { $in: ["active", "paused"] },
    endDate: { $gte: new Date() },
  })
    .sort({ endDate: -1 })
    .populate("planId")
    .lean();

  let planName = "";
  let startDate = null;
  if (sub?.planId) {
    const p = sub.planId;
    planName = p.planName || "";
    startDate = sub.startDate || null;
  }

  let location = null;
  const coords = customer.location?.coordinates;
  if (Array.isArray(coords) && coords.length >= 2) {
    const lng = Number(coords[0]);
    const lat = Number(coords[1]);
    if (
      Number.isFinite(lat) &&
      Number.isFinite(lng) &&
      (lat !== 0 || lng !== 0)
    ) {
      location = { type: "Point", coordinates: [lng, lat] };
    }
  }

  let zoneName = "";
  if (customer.zoneId) {
    const zone = await Zone.findById(customer.zoneId).select("name").lean();
    zoneName = zone?.name ? String(zone.name) : "";
  }

  const subHasCreditLimit =
    sub?.creditLimit != null && Number.isFinite(Number(sub.creditLimit));
  const customerCreditLimit = Number(customer.creditLimit);
  const customerHasCreditLimit =
    Number.isFinite(customerCreditLimit) && customerCreditLimit > 0;
  const cap = sub?.payLater ? payLaterEffectiveCreditCap(sub) : null;
  const exposure = sub?.payLater ? payLaterConsumptionExposure(sub) : null;
  const creditLimit = sub?.payLater
    ? subHasCreditLimit
      ? Number(sub.creditLimit)
      : Number.isFinite(cap)
        ? cap
        : null
    : customerHasCreditLimit
      ? customerCreditLimit
      : null;
  const creditHeadroom =
    sub?.payLater && Number.isFinite(cap)
      ? Math.max(0, cap - Number(exposure || 0))
      : null;

  return {
    name: customer.name || "",
    phone: customer.phone || "",
    email: customer.email || "",
    address: customer.address || "",
    planName,
    startDate: startDate ? startDate.toISOString() : "",
    status: customer.status || "active",
    location,
    zoneName,
    zone: customer.zone ? String(customer.zone) : "",
    activeSubscriptionId: sub?._id ? sub._id.toString() : "",
    payLater: sub?.payLater === true,
    creditLimit,
    consumptionExposure: sub?.payLater ? Number(exposure || 0) : null,
    creditHeadroom,
    amountDueOnPlan: sub?.payLater ? subscriptionCashOwed(sub) : null,
    subscriptionBalance: sub ? effectiveRemaining(sub) : null,
    totalAmount: sub ? Number(sub.totalAmount ?? 0) : null,
    paidAmount: sub ? Number(sub.paidAmount ?? 0) : null,
  };
}

/**
 * GET /api/v1/customer-details/:customerId/info
 * Returns core profile + active plan summary for the Info tab.
 */
router.get(
  "/:customerId/info",
  asyncHandler(async (req, res) => {
    const ownerId = resolveOwnerId(req);
    const { customerId } = req.params;
    const customer = await assertCustomer(ownerId, customerId);

    const payload = await buildCustomerInfoPayload(ownerId, customer);

    const response = new ApiResponse(200, "Customer info", payload);
    return res.status(response.statusCode).json({
      success: response.success,
      message: response.message,
      data: response.data,
    });
  })
);

const creditLimitSchema = Joi.object({
  creditLimit: Joi.number().min(0).allow(null).required(),
});

/**
 * PUT /api/v1/customer-details/:customerId/credit-limit
 * Updates the stored customer credit limit and active pay-later plan cap.
 */
router.put(
  "/:customerId/credit-limit",
  asyncHandler(async (req, res) => {
    const ownerId = resolveOwnerId(req);
    const { customerId } = req.params;
    const { error, value } = creditLimitSchema.validate(req.body, {
      stripUnknown: true,
      abortEarly: false,
    });
    if (error) {
      throw new ApiError(400, error.details.map((d) => d.message).join("; "));
    }

    await assertCustomer(ownerId, customerId);

    const nextLimit =
      value.creditLimit != null && Number.isFinite(Number(value.creditLimit))
        ? Number(value.creditLimit)
        : null;

    const session = await mongoose.startSession();
    session.startTransaction();
    try {
      await Customer.findOneAndUpdate(
        { _id: customerId, ownerId },
        { $set: { creditLimit: nextLimit ?? 0 } },
        { new: true, runValidators: true, session }
      );

      const activeSub = await Subscription.findOne({
        ownerId,
        customerId,
        payLater: true,
        status: { $in: ["active", "paused"] },
        endDate: { $gte: new Date() },
      })
        .sort({ endDate: -1 })
        .session(session);

      if (activeSub) {
        activeSub.creditLimit = nextLimit;
        await activeSub.save({ session });
      }

      await session.commitTransaction();
      session.endSession();
    } catch (e) {
      await session.abortTransaction();
      session.endSession();
      throw e;
    }

    const updated = await assertCustomer(ownerId, customerId);
    const payload = await buildCustomerInfoPayload(ownerId, updated);
    const response = new ApiResponse(200, "Credit limit updated", payload);
    return res.status(response.statusCode).json({
      success: response.success,
      message: response.message,
      data: response.data,
    });
  })
);

/**
 * GET /api/v1/customer-details/:customerId/subscriptions
 * Active plan card + subscription history list.
 */
router.get(
  "/:customerId/subscriptions",
  asyncHandler(async (req, res) => {
    const ownerId = resolveOwnerId(req);
    const { customerId } = req.params;
    await assertCustomer(ownerId, customerId);

    const now = new Date();
    const activeSub = await Subscription.findOne({
      ownerId,
      customerId,
      status: "active",
      endDate: { $gte: now },
    })
      .sort({ endDate: -1 })
      .populate("planId")
      .lean();

    let activePlan = null;
    if (activeSub?.planId) {
      const plan = activeSub.planId;
      const pricePerMonth = Number(plan.price) || 0;
      const itemsPerDay = countItemsPerDay(plan);
      const end = activeSub.endDate ? new Date(activeSub.endDate) : null;
      const start = activeSub.startDate ? new Date(activeSub.startDate) : null;
      const remainingDays = remainingDaysInclusiveIST(
        activeSub.startDate,
        activeSub.endDate
      );
      const amountDue = subscriptionCashOwed(activeSub);
      const exposure = payLaterConsumptionExposure(activeSub);
      const cap = payLaterEffectiveCreditCap(activeSub);
      const headroom = Number.isFinite(cap) ? Math.max(0, cap - exposure) : null;
      activePlan = {
        id: activeSub._id.toString(),
        planName: plan.planName || "",
        itemsPerDay,
        pricePerMonth,
        startDate: start ? start.toISOString() : "",
        endDate: end ? end.toISOString() : "",
        remainingDays,
        payLater: !!activeSub.payLater,
        creditLimit:
          activeSub.creditLimit != null
            ? Number(activeSub.creditLimit)
            : null,
        paymentDueDate: activeSub.paymentDueDate
          ? new Date(activeSub.paymentDueDate).toISOString()
          : "",
        amountDueOnPlan: amountDue,
        totalAmount: Number(activeSub.totalAmount ?? 0),
        paidAmount: Number(activeSub.paidAmount ?? 0),
        consumptionExposure: activeSub.payLater ? exposure : null,
        creditHeadroom: activeSub.payLater ? headroom : null,
      };
    }

    const historyDocs = await Subscription.find({
      ownerId,
      customerId,
      $or: [{ status: { $ne: "active" } }, { endDate: { $lt: now } }],
    })
      .sort({ endDate: -1 })
      .populate("planId")
      .lean();

    const history = historyDocs.map((h) => {
      const plan = h.planId;
      const planName = plan?.planName || "Plan";
      const end = h.endDate ? new Date(h.endDate) : null;
      const completed = !!end && end.getTime() < now.getTime();
      return {
        planName,
        startDate: h.startDate ? new Date(h.startDate).toISOString() : "",
        endDate: h.endDate ? new Date(h.endDate).toISOString() : "",
        amountPaid: historySubscriptionAmount(h),
        completed,
      };
    });

    const response = new ApiResponse(200, "Subscriptions", {
      activePlan,
      history,
    });
    return res.status(response.statusCode).json({
      success: response.success,
      message: response.message,
      data: response.data,
    });
  })
);

/**
 * GET /api/v1/customer-details/:customerId/transactions/:transactionId/receipt
 * Full receipt payload for bottom sheet / share.
 */
router.get(
  "/:customerId/transactions/:transactionId/receipt",
  asyncHandler(async (req, res) => {
    const ownerId = resolveOwnerId(req);
    const { customerId, transactionId } = req.params;
    await assertCustomer(ownerId, customerId);

    const vendor = await User.findById(ownerId)
      .select("businessName ownerName")
      .lean();
    const businessName =
      vendor?.businessName || vendor?.ownerName || "Business";

    if (transactionId.startsWith("pay_")) {
      const pid = transactionId.slice(4);
      assertObjectId(pid, "transactionId");
      const p = await Payment.findOne({
        _id: pid,
        customerId,
        ownerId,
      }).lean();
      if (!p) throw new ApiError(404, "Receipt not found");

      const items = [];
      const total = Number(p.amount) || 0;
      const payload = {
        businessName,
        date: p.paymentDate ? new Date(p.paymentDate).toISOString() : "",
        description:
          p.notes || (p.type === "wallet_credit" ? "Wallet credit" : "Payment"),
        items,
        total,
        paymentMode: p.paymentMethod || "cash",
        type: p.type === "wallet_credit" ? "credit" : "debit",
      };
      const response = new ApiResponse(200, "Receipt", payload);
      return res.status(response.statusCode).json({
        success: response.success,
        message: response.message,
        data: response.data,
      });
    }

    assertObjectId(transactionId, "transactionId");
    const t = await Transaction.findOne({
      _id: transactionId,
      customerId,
      ownerId,
    }).lean();
    if (!t) throw new ApiError(404, "Receipt not found");

    const items = (t.items || []).map((it) => ({
      name: it.name,
      quantity: it.quantity,
      unitPrice: it.unitPrice,
    }));
    const total = Number(t.amount) || 0;
    const payload = {
      businessName,
      date: t.date ? new Date(t.date).toISOString() : "",
      description: t.description || "",
      items,
      total,
      paymentMode: t.paymentMode || "cash",
      type: t.type,
    };

    const response = new ApiResponse(200, "Receipt", payload);
    return res.status(response.statusCode).json({
      success: response.success,
      message: response.message,
      data: response.data,
    });
  })
);

/**
 * GET /api/v1/customer-details/:customerId/transactions
 * Optional query: startDate, endDate (ISO strings).
 */
router.get(
  "/:customerId/transactions",
  asyncHandler(async (req, res) => {
    const ownerId = resolveOwnerId(req);
    const { customerId } = req.params;
    await assertCustomer(ownerId, customerId);

    const startRaw = req.query.startDate;
    const endRaw = req.query.endDate;
    const start = startRaw ? new Date(String(startRaw)) : new Date(0);
    const end = endRaw ? new Date(String(endRaw)) : new Date(8640000000000000);
    if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime())) {
      throw new ApiError(400, "Invalid date range");
    }

    const [txns, payments] = await Promise.all([
      Transaction.find({
        ownerId,
        customerId,
        date: { $gte: start, $lte: end },
      })
        .sort({ date: -1 })
        .lean(),
      Payment.find({
        ownerId,
        customerId,
        paymentDate: { $gte: start, $lte: end },
        status: "captured",
      })
        .sort({ paymentDate: -1 })
        .lean(),
    ]);

    const mappedTx = txns.map((t) => ({
      id: t._id.toString(),
      date: t.date ? new Date(t.date).toISOString() : "",
      description: t.description || "",
      amount: Number(t.amount) || 0,
      type: t.type,
      paymentMode: t.paymentMode || "cash",
      source: t.source || "manual",
      items: (t.items || []).map((it) => ({
        name: it.name,
        quantity: it.quantity,
        unitPrice: it.unitPrice,
      })),
    }));

    const mappedPay = payments.map((p) => ({
      id: `pay_${p._id.toString()}`,
      date: p.paymentDate ? new Date(p.paymentDate).toISOString() : "",
      description:
        p.notes || (p.type === "wallet_credit" ? "Wallet credit" : "Payment"),
      amount: Number(p.amount) || 0,
      type: p.type === "wallet_credit" ? "credit" : "debit",
      paymentMode: p.paymentMethod || "cash",
      items: [],
    }));

    const merged = [...mappedTx, ...mappedPay].sort(
      (a, b) => new Date(b.date).getTime() - new Date(a.date).getTime()
    );

    const response = new ApiResponse(200, "Transactions", merged);
    return res.status(response.statusCode).json({
      success: response.success,
      message: response.message,
      data: response.data,
    });
  })
);

/**
 * GET /api/v1/customer-details/:customerId/balance
 */
router.get(
  "/:customerId/balance",
  asyncHandler(async (req, res) => {
    const ownerId = resolveOwnerId(req);
    const { customerId } = req.params;
    const customer = await assertCustomer(ownerId, customerId);

    const sub = await Subscription.findOne({
      ownerId,
      customerId,
      status: { $in: ["active", "paused"] },
      endDate: { $gte: new Date() },
    })
      .sort({ endDate: -1 })
      .lean();

    const subBal = effectiveRemaining(sub);

    const payload = {
      walletBalance: displayWalletBalance(customer),
      subscriptionBalance: subBal,
    };

    const response = new ApiResponse(200, "Balance", payload);
    return res.status(response.statusCode).json({
      success: response.success,
      message: response.message,
      data: response.data,
    });
  })
);

const addBalanceSchema = Joi.object({
  amount: Joi.number().positive().required(),
  paymentMode: Joi.string().valid("cash", "upi", "online").required(),
  note: Joi.string().allow("").optional(),
});

const deductBalanceSchema = Joi.object({
  amount: Joi.number().positive().required(),
  note: Joi.string().allow("").optional(),
});

/**
 * POST /api/v1/customer-details/:customerId/add-balance
 * Increments wallet balance and records a credit transaction.
 */
router.post(
  "/:customerId/add-balance",
  asyncHandler(async (req, res) => {
    const ownerId = resolveOwnerId(req);
    const { customerId } = req.params;
    const { error, value } = addBalanceSchema.validate(req.body, {
      stripUnknown: true,
    });
    if (error) {
      throw new ApiError(400, error.details.map((d) => d.message).join("; "));
    }
    await assertCustomer(ownerId, customerId);

    const modeMap = { cash: "cash", upi: "upi", online: "razorpay" };
    const storedMode = modeMap[value.paymentMode] || "cash";

    const session = await mongoose.startSession();
    session.startTransaction();
    let appliedToSubscription = 0;
    let remainder = 0;
    try {
      const inc = Number(value.amount);
      const cid = new mongoose.Types.ObjectId(customerId);
      const oid = mongoose.Types.ObjectId.isValid(ownerId)
        ? new mongoose.Types.ObjectId(ownerId)
        : ownerId;

      const settled = await settlePayLaterSubscriptions({
        session,
        ownerId: oid,
        customerId: cid,
        amount: inc,
      });
      remainder = settled.remainder;
      appliedToSubscription = settled.appliedToSubscription;

      const updated = await Customer.findByIdAndUpdate(
        customerId,
        {
          $inc: { walletBalance: remainder, balance: remainder },
        },
        { new: true, session }
      ).lean();

      const ledgerRows = [];
      if (appliedToSubscription > 0) {
        ledgerRows.push({
          ownerId: oid,
          customerId: cid,
          date: new Date(),
          description:
            value.note?.trim()?.length && appliedToSubscription < inc
              ? `${value.note} — ₹${appliedToSubscription.toFixed(0)} plan dues`
              : `Plan dues settlement (₹${appliedToSubscription.toFixed(0)})`,
          amount: appliedToSubscription,
          type: "credit",
          paymentMode: storedMode,
          source: "subscription_dues_payment",
          items: [],
        });
      }
      if (remainder > 0) {
        ledgerRows.push({
          ownerId: oid,
          customerId: cid,
          date: new Date(),
          description:
            appliedToSubscription > 0 && value.note?.trim()?.length
              ? `${value.note} — ₹${remainder.toFixed(0)} wallet`
              : value.note || "Wallet top-up",
          amount: remainder,
          type: "credit",
          paymentMode: storedMode,
          source: "wallet_topup",
          items: [],
        });
      }
      await Transaction.create(ledgerRows, { session, ordered: true });

      await session.commitTransaction();
      session.endSession();

      const subAfter = await Subscription.findOne({
        ownerId,
        customerId,
        status: "active",
        endDate: { $gte: new Date() },
      })
        .sort({ endDate: -1 })
        .lean();

      const response = new ApiResponse(200, "Balance added", {
        success: true,
        updatedWalletBalance: displayWalletBalance(updated),
        updatedSubscriptionBalance: effectiveRemaining(subAfter),
        appliedToSubscriptionDues: appliedToSubscription,
        addedToWallet: remainder,
      });
      return res.status(response.statusCode).json({
        success: response.success,
        message: response.message,
        data: response.data,
      });
    } catch (e) {
      await session.abortTransaction();
      session.endSession();
      throw e;
    }
  })
);

/**
 * POST /api/v1/customer-details/:customerId/deduct-balance
 * Decrements wallet balance and records a debit transaction.
 */
router.post(
  "/:customerId/deduct-balance",
  asyncHandler(async (req, res) => {
    const ownerId = resolveOwnerId(req);
    const { customerId } = req.params;
    const { error, value } = deductBalanceSchema.validate(req.body, {
      stripUnknown: true,
    });
    if (error) {
      throw new ApiError(400, error.details.map((d) => d.message).join("; "));
    }
    const customerBefore = await assertCustomer(ownerId, customerId);
    const amount = Number(value.amount);
    if (effectiveWallet(customerBefore) < amount) {
      throw new ApiError(400, "Insufficient wallet balance");
    }

    const session = await mongoose.startSession();
    session.startTransaction();
    try {
      const updated = await Customer.findByIdAndUpdate(
        customerId,
        {
          $inc: { walletBalance: -amount, balance: -amount },
        },
        { new: true, session }
      ).lean();

      await Transaction.create(
        [
          {
            ownerId,
            customerId,
            date: new Date(),
            description: value.note || "Wallet deduction",
            amount,
            type: "debit",
            paymentMode: "cash",
            source: "wallet_deduction",
            items: [],
          },
        ],
        { session }
      );

      await session.commitTransaction();
      session.endSession();

      await notifyIfWalletJustHitZero({
        ownerId,
        customerId,
        customerBefore: customerBefore,
        customerAfter: updated,
      });

      const subAfter = await Subscription.findOne({
        ownerId,
        customerId,
        status: "active",
        endDate: { $gte: new Date() },
      })
        .sort({ endDate: -1 })
        .lean();

      const response = new ApiResponse(200, "Balance deducted", {
        success: true,
        updatedWalletBalance: displayWalletBalance(updated),
        updatedSubscriptionBalance: effectiveRemaining(subAfter),
      });
      return res.status(response.statusCode).json({
        success: response.success,
        message: response.message,
        data: response.data,
      });
    } catch (e) {
      await session.abortTransaction();
      session.endSession();
      throw e;
    }
  })
);

const extraChargeSchema = Joi.object({
  amount: Joi.number().positive().required(),
  note: Joi.string().trim().required(),
  /** separate = pending due; wallet | subscription = deduct from customer wallet */
  chargeType: Joi.string()
    .valid("separate", "subscription", "wallet")
    .required(),
});

/**
 * POST /api/v1/customer-details/:customerId/send-login-link
 * Generates one-time login token (24h) and returns WhatsApp-ready message.
 */
router.post(
  "/:customerId/send-login-link",
  asyncHandler(async (req, res) => {
    try {
      const ownerId = resolveOwnerId(req);
      const { customerId } = req.params;
      const customer = await Customer.findOne({
        _id: customerId,
        ownerId,
        isDeleted: { $ne: true },
      });
      if (!customer) {
        return res
          .status(404)
          .json({ success: false, message: "Customer not found" });
      }

      const token = crypto.randomBytes(32).toString("hex");
      const expiry = new Date(Date.now() + 24 * 60 * 60 * 1000);
      customer.loginToken = token;
      customer.loginTokenExpiry = expiry;
      await customer.save();

      const basePortal = process.env.CUSTOMER_PORTAL_URL || "";
      const loginUrl = `${basePortal}/login?token=${token}&id=${customer._id}`;

      const message =
        `Hello ${customer.name}!\n\n` +
        "Here is your login link for the customer portal:\n\n" +
        `${loginUrl}\n\n` +
        "This link is valid for 24 hours.\n\n" +
        "Thank you!";

      return res.status(200).json({
        success: true,
        loginUrl,
        phone: customer.phone || "",
        message,
      });
    } catch (_) {
      return res
        .status(500)
        .json({ success: false, message: "Could not create login link" });
    }
  })
);

/**
 * POST /api/v1/customer-details/:customerId/extra-charge
 */
router.post(
  "/:customerId/extra-charge",
  asyncHandler(async (req, res) => {
    const ownerId = resolveOwnerId(req);
    const { customerId } = req.params;
    const { error, value } = extraChargeSchema.validate(req.body, {
      stripUnknown: true,
    });
    if (error) {
      throw new ApiError(400, error.details.map((d) => d.message).join("; "));
    }
    await assertCustomer(ownerId, customerId);

    const amt = Number(value.amount);
    let walletChargeBefore = null;

    const session = await mongoose.startSession();
    session.startTransaction();
    try {
      if (value.chargeType === "separate") {
        await Customer.findByIdAndUpdate(
          customerId,
          { $inc: { pendingDue: amt } },
          { session }
        );
        await Transaction.create(
          [
            {
              ownerId,
              customerId,
              date: new Date(),
              description: value.note,
              amount: amt,
              type: "debit",
              paymentMode: "cash",
              source: "extra_charge_separate",
              items: [
                {
                  name: value.note,
                  quantity: 1,
                  unitPrice: amt,
                },
              ],
            },
          ],
          { session }
        );
      } else {
        // Manual charges always hit wallet (not subscription prepaid balance).
        const cust = await Customer.findById(customerId)
          .session(session)
          .lean();
        if (!cust) throw new ApiError(404, "Customer not found");
        walletChargeBefore = cust;
        const wallet = effectiveWallet(cust);
        if (wallet < amt) {
          throw new ApiError(400, "Insufficient wallet balance");
        }
        await Customer.findByIdAndUpdate(
          customerId,
          { $inc: { walletBalance: -amt, balance: -amt } },
          { session }
        );
        await Transaction.create(
          [
            {
              ownerId,
              customerId,
              date: new Date(),
              description: value.note,
              amount: amt,
              type: "debit",
              paymentMode: "cash",
              source:
                value.chargeType === "wallet"
                  ? "extra_charge_wallet"
                  : "extra_charge_subscription",
              items: [
                {
                  name: value.note,
                  quantity: 1,
                  unitPrice: amt,
                },
              ],
            },
          ],
          { session }
        );
      }

      const customer = await Customer.findById(customerId)
        .session(session)
        .lean();
      const subAfter = await Subscription.findOne({
        ownerId,
        customerId,
        status: "active",
        endDate: { $gte: new Date() },
      })
        .sort({ endDate: -1 })
        .session(session)
        .lean();

      await session.commitTransaction();
      session.endSession();

      if (walletChargeBefore && customer) {
        await notifyIfWalletJustHitZero({
          ownerId,
          customerId,
          customerBefore: walletChargeBefore,
          customerAfter: customer,
        });
      }

      const response = new ApiResponse(200, "Charge recorded", {
        success: true,
        updatedWalletBalance: displayWalletBalance(customer),
        updatedSubscriptionBalance: effectiveRemaining(subAfter),
      });
      return res.status(response.statusCode).json({
        success: response.success,
        message: response.message,
        data: response.data,
      });
    } catch (e) {
      await session.abortTransaction();
      session.endSession();
      throw e;
    }
  })
);

/**
 * POST /api/v1/customer-details/:customerId/notify-wallet-reminder
 * Push + in-app reminder; returns WhatsApp text for optional follow-up.
 */
router.post(
  "/:customerId/notify-wallet-reminder",
  asyncHandler(async (req, res) => {
    const ownerId = resolveOwnerId(req);
    const { customerId } = req.params;
    const customer = await assertCustomer(ownerId, customerId);
    const w = displayWalletBalance(customer);
    const name = (customer.name || "").trim();
    const whatsappMessage = !name
      ? `Hi, your Tiffin wallet balance is ₹${w.toFixed(0)}. Please top up when you can. 🙏`
      : `Hi ${name}, your Tiffin wallet balance is ₹${w.toFixed(0)}. Please top up when you can. 🙏`;

    const pushMessage = name
      ? `${name}, your wallet balance is ₹${w.toFixed(0)}. Please top up when you can.`
      : `Your wallet balance is ₹${w.toFixed(0)}. Please top up when you can.`;

    try {
      await sendNotification({
        customerId,
        ownerId,
        type: NOTIFICATION_TYPES.LOW_BALANCE,
        title: "Wallet reminder",
        message: pushMessage,
        data: {
          walletBalance: w,
          screen: "wallet",
          reason: "vendor_reminder",
        },
      });
    } catch (err) {
      console.error("[notify-wallet-reminder]", err?.message || err);
    }

    const response = new ApiResponse(200, "Reminder sent", {
      walletBalance: w,
      whatsappMessage,
    });
    return res.status(response.statusCode).json({
      success: response.success,
      message: response.message,
      data: response.data,
    });
  })
);

/**
 * GET /api/v1/customer-details/:customerId/deliveries
 * Full subscription window: one row per calendar day from startDate → endDate (IST).
 */
router.get(
  "/:customerId/deliveries",
  asyncHandler(async (req, res) => {
    const ownerId = resolveOwnerId(req);
    const { customerId } = req.params;
    await assertCustomer(ownerId, customerId);

    const subscription = await Subscription.findOne({
      ownerId,
      customerId,
      status: "active",
      endDate: { $gte: new Date() },
    })
      .sort({ endDate: -1 })
      .populate("planId")
      .lean();

    if (!subscription) {
      const empty = new ApiResponse(200, "Deliveries", {
        subscription: null,
        deliveries: [],
      });
      return res.status(empty.statusCode).json({
        success: empty.success,
        message: empty.message,
        data: empty.data,
      });
    }

    const plan = subscription.planId;
    const planName = plan?.planName ? String(plan.planName) : "";

    const startYmd = ymdIST(subscription.startDate);
    const endYmd = ymdIST(subscription.endDate);
    const startMs = new Date(`${startYmd}T00:00:00+05:30`).getTime();
    const endMs = new Date(`${endYmd}T00:00:00+05:30`).getTime();
    const dayMs = 86400000;
    const totalDays = totalDaysInclusiveIST(
      subscription.startDate,
      subscription.endDate
    );
    const remainingDays = remainingDaysInclusiveIST(
      subscription.startDate,
      subscription.endDate
    );

    const rangeStart = new Date(`${startYmd}T00:00:00+05:30`);
    const rangeEnd = new Date(`${endYmd}T23:59:59.999+05:30`);

    const [scheduleDocs, orderDocs] = await Promise.all([
      DeliverySchedule.find({
        ownerId,
        customerId,
        date: { $gte: rangeStart, $lte: rangeEnd },
      }).lean(),
      DailyOrder.find({
        ownerId,
        customerId,
        orderDate: { $gte: rangeStart, $lte: rangeEnd },
      }).lean(),
    ]);

    const scheduleByYmd = new Map();
    for (const s of scheduleDocs) {
      scheduleByYmd.set(ymdIST(s.date), s);
    }

    const ordersByYmd = new Map();
    for (const o of orderDocs) {
      const k = ymdIST(o.orderDate);
      if (!ordersByYmd.has(k)) ordersByYmd.set(k, []);
      ordersByYmd.get(k).push(o);
    }

    const startDateObj = subscription.startDate
      ? new Date(subscription.startDate)
      : null;
    const endDateObj = subscription.endDate
      ? new Date(subscription.endDate)
      : null;

    const rows = [];
    for (let t = startMs; t <= endMs; t += dayMs) {
      const ymd = new Date(t).toLocaleDateString("en-CA", {
        timeZone: "Asia/Kolkata",
      });

      const schedule = scheduleByYmd.get(ymd);
      const orders = ordersByYmd.get(ymd) || [];

      let items = "";
      let status = "pending";

      if (schedule?.status === "cancelled") {
        items =
          schedule.items ||
          formatOrderItems(orders.flatMap((o) => o.resolvedItems || []));
        status = "cancelled";
      } else if (orders.length) {
        items = formatOrderItems(orders.flatMap((o) => o.resolvedItems || []));
        const hasDelivered = orders.some((o) => o.status === "delivered");
        const hasCancelled = orders.some((o) => o.status === "cancelled");
        if (hasCancelled && !hasDelivered) status = "cancelled";
        else if (hasDelivered) status = "delivered";
        else status = "pending";
      } else {
        items = defaultItemsFromPlan(plan);
        status = "pending";
      }

      /** Sum of DailyOrder.amount for that day — meal plan price slots, not item catalog. */
      let dayAmount = 0;
      if (schedule?.status === "cancelled") {
        dayAmount = 0;
      } else if (orders.length) {
        dayAmount = orders.reduce(
          (sum, o) => sum + (Number(o.amount) || 0),
          0
        );
      } else if (plan && Number(plan.price) > 0) {
        dayAmount = Number(plan.price) || 0;
      }

      rows.push({
        date: ymd,
        items: items || "—",
        status,
        amount: dayAmount,
      });
    }

    const subPayload = {
      planName,
      startDate: startDateObj ? startDateObj.toISOString() : "",
      endDate: endDateObj ? endDateObj.toISOString() : "",
      totalDays,
      remainingDays,
    };

    const response = new ApiResponse(200, "Deliveries", {
      subscription: subPayload,
      deliveries: rows,
    });
    return res.status(response.statusCode).json({
      success: response.success,
      message: response.message,
      data: response.data,
    });
  })
);

/**
 * PATCH /api/v1/customer-details/:customerId/deliveries/:date/cancel
 * date = YYYY-MM-DD
 */
router.patch(
  "/:customerId/deliveries/:date/cancel",
  asyncHandler(async (req, res) => {
    const ownerId = resolveOwnerId(req);
    const { customerId, date } = req.params;
    await assertCustomer(ownerId, customerId);

    const ymd = String(date);
    if (!/^\d{4}-\d{2}-\d{2}$/.test(ymd)) {
      throw new ApiError(400, "Invalid date");
    }

    const today = istTodayYmd();
    if (ymd < today) {
      throw new ApiError(400, "Cannot cancel past deliveries");
    }

    const start = new Date(`${ymd}T00:00:00+05:30`);
    const end = new Date(`${ymd}T23:59:59.999+05:30`);

    const orders = await DailyOrder.find({
      ownerId,
      customerId,
      orderDate: { $gte: start, $lte: end },
    }).lean();

    const itemsText = formatOrderItems(
      orders.flatMap((o) => o.resolvedItems || [])
    );

    await DeliverySchedule.findOneAndUpdate(
      { customerId, date: { $gte: start, $lte: end } },
      {
        $set: {
          ownerId,
          customerId,
          date: start,
          items: itemsText,
          status: "cancelled",
          cancelledAt: new Date(),
        },
      },
      { upsert: true, new: true }
    );

    await DailyOrder.updateMany(
      {
        ownerId,
        customerId,
        orderDate: { $gte: start, $lte: end },
        status: { $nin: ["delivered", "cancelled"] },
      },
      {
        $set: {
          status: "cancelled",
          cancelledAt: new Date(),
          cancelledBy: "customer",
        },
      }
    );

    const io = req.app.get("io");
    if (io) {
      const vendorRoomId = resolveOwnerId(req);
      io.of("/delivery")
        .to(`admin:${vendorRoomId}`)
        .emit("daily_orders_changed", {
          date: ymd,
          customerId: String(customerId),
        });
    }

    const response = new ApiResponse(200, "Delivery cancelled", {
      success: true,
      date: ymd,
      status: "cancelled",
    });
    return res.status(response.statusCode).json({
      success: response.success,
      message: response.message,
      data: response.data,
    });
  })
);

/**
 * PATCH /api/v1/customer-details/:customerId/deliveries/:date/undo-cancel
 * Reverts a vendor-side cancel for a calendar day (same window as cancel).
 * Restores DeliverySchedule + DailyOrder rows that were cancelled via customer-details cancel.
 */
router.patch(
  "/:customerId/deliveries/:date/undo-cancel",
  asyncHandler(async (req, res) => {
    const ownerId = resolveOwnerId(req);
    const { customerId, date } = req.params;
    await assertCustomer(ownerId, customerId);

    const ymd = String(date);
    if (!/^\d{4}-\d{2}-\d{2}$/.test(ymd)) {
      throw new ApiError(400, "Invalid date");
    }

    const today = istTodayYmd();
    if (ymd < today) {
      throw new ApiError(400, "Cannot undo cancellations for past dates");
    }

    const start = new Date(`${ymd}T00:00:00+05:30`);
    const end = new Date(`${ymd}T23:59:59.999+05:30`);

    const orders = await DailyOrder.find({
      ownerId,
      customerId,
      orderDate: { $gte: start, $lte: end },
    }).lean();

    if (orders.some((o) => o.status === "delivered")) {
      throw new ApiError(
        400,
        "Cannot undo: at least one delivery is already marked delivered"
      );
    }

    const schedule = await DeliverySchedule.findOne({
      customerId,
      date: { $gte: start, $lte: end },
    }).lean();

    const hasCancelledSchedule = schedule?.status === "cancelled";
    const hasCustomerCancelledOrders = orders.some(
      (o) => o.status === "cancelled" && o.cancelledBy === "customer"
    );

    if (!hasCancelledSchedule && !hasCustomerCancelledOrders) {
      throw new ApiError(400, "Nothing to undo for this date");
    }

    if (hasCancelledSchedule) {
      await DeliverySchedule.findOneAndUpdate(
        { customerId, date: { $gte: start, $lte: end } },
        {
          $set: {
            status: "pending",
            cancelledAt: null,
          },
        },
        { new: true }
      );
    }

    await DailyOrder.updateMany(
      {
        ownerId,
        customerId,
        orderDate: { $gte: start, $lte: end },
        status: "cancelled",
        cancelledBy: "customer",
      },
      {
        $set: {
          status: "pending",
          cancelledAt: null,
          cancelledBy: null,
          cancellationReason: null,
        },
      }
    );

    const io = req.app.get("io");
    if (io) {
      const vendorRoomId = resolveOwnerId(req);
      io.of("/delivery")
        .to(`admin:${vendorRoomId}`)
        .emit("daily_orders_changed", {
          date: ymd,
          customerId: String(customerId),
        });
    }

    const response = new ApiResponse(200, "Delivery restored", {
      success: true,
      date: ymd,
      status: "pending",
    });
    return res.status(response.statusCode).json({
      success: response.success,
      message: response.message,
      data: response.data,
    });
  })
);

export default router;
