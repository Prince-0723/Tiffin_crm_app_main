import Joi from "joi";
import mongoose from "mongoose";
import Payment, { PAYMENT_METHODS } from "../models/Payment.model.js";
import Customer from "../models/Customer.model.js";
import Invoice from "../models/Invoice.model.js";
import Subscription from "../models/Subscription.model.js";
import { createRazorpayOrder } from "../services/payment.service.js";
import { asyncHandler } from "../utils/asyncHandler.js";
import { ApiResponse } from "../class/apiResponseClass.js";
import { ApiError } from "../class/apiErrorClass.js";
import config from "../config/index.js";
import { sendNotification } from "../services/inAppNotification.service.js";

const MAX_LIMIT = 100;
const DEFAULT_LIMIT = 20;
const DEFAULT_PAGE = 1;

const createPaymentSchema = Joi.object({
  customerId: Joi.string().hex().length(24).required(),
  invoiceId: Joi.string().hex().length(24).optional(),
  subscriptionId: Joi.string().hex().length(24).optional(),
  amount: Joi.number().precision(2).min(0).required(),
  paymentMethod: Joi.string()
    .valid(...PAYMENT_METHODS)
    .required(),
  paymentDate: Joi.date().iso().optional(),
  transactionRef: Joi.string().allow("", null),
});

const createOrderSchema = Joi.object({
  amount: Joi.number().min(1).required(),
  receipt: Joi.string().required(),
  customerId: Joi.string().hex().length(24).optional(),
  invoiceId: Joi.string().hex().length(24).optional(),
});

const listQuerySchema = Joi.object({
  page: Joi.number().integer().min(1).optional(),
  limit: Joi.number().integer().min(1).max(MAX_LIMIT).optional(),
  customerId: Joi.string().hex().length(24).optional(),
  fromDate: Joi.date().iso().optional(),
  toDate: Joi.date().iso().optional(),
});

/**
 * GET /api/v1/payments
 * Query: page, limit, customerId, fromDate, toDate
 */
export const listPayments = asyncHandler(async (req, res) => {
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
  if (value.customerId) filter.customerId = value.customerId;
  if (value.fromDate || value.toDate) {
    filter.createdAt = {};
    if (value.fromDate) filter.createdAt.$gte = new Date(value.fromDate);
    if (value.toDate) filter.createdAt.$lte = new Date(value.toDate);
  }

  const [data, total] = await Promise.all([
    Payment.find(filter)
      .populate("customerId", "name phone address")
      .populate("invoiceId", "invoiceNumber netAmount")
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit)
      .lean(),
    Payment.countDocuments(filter),
  ]);

  const totalPages = Math.ceil(total / limit);

  const response = new ApiResponse(200, "Payments fetched", {
    data,
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
 * POST /api/v1/payments
 * Manual payment: amount, method, customerId, subscriptionId?
 */
export const createPayment = asyncHandler(async (req, res) => {
  const { error, value } = createPaymentSchema.validate(req.body, {
    stripUnknown: true,
    abortEarly: false,
  });
  if (error) {
    throw new ApiError(400, error.details.map((d) => d.message).join("; "));
  }

  const ownerId = req.user.userId;
  const customerId = new mongoose.Types.ObjectId(value.customerId);
  const invoiceId = value.invoiceId
    ? new mongoose.Types.ObjectId(value.invoiceId)
    : null;
  const subscriptionId = value.subscriptionId
    ? new mongoose.Types.ObjectId(value.subscriptionId)
    : null;

  const [customer, invoice, subscription] = await Promise.all([
    Customer.findOne({
      _id: customerId,
      ownerId,
      isDeleted: { $ne: true },
    }),
    invoiceId
      ? Invoice.findOne({ _id: invoiceId, ownerId })
      : Promise.resolve(null),
    subscriptionId
      ? Subscription.findOne({
          _id: subscriptionId,
          ownerId,
          customerId,
          status: { $in: ["active", "paused"] },
        })
      : Promise.resolve(null),
  ]);

  if (!customer) throw new ApiError(404, "Customer not found");
  if (invoiceId) {
    if (!invoice) throw new ApiError(404, "Invoice not found");
    if (invoice.isVoid) throw new ApiError(400, "INVOICE_VOIDED");

    if (value.amount > invoice.balanceDue) {
      throw new ApiError(400, "PAYMENT_EXCEEDS_DUE");
    }
  }
  if (subscriptionId && !subscription) {
    throw new ApiError(404, "Subscription not found");
  }

  const session = await mongoose.startSession();
  session.startTransaction();

  const isWalletTopUp = !invoiceId && !subscriptionId;

  try {
    const payment = await Payment.create(
      [
        {
          ownerId,
          customerId,
          ...(invoiceId && { invoiceId }),
          ...(subscriptionId && { subscriptionId }),
          amount: value.amount,
          paymentMethod: value.paymentMethod,
          paymentDate: value.paymentDate || new Date(),
          transactionRef: value.transactionRef,
          status: "captured",
          type: isWalletTopUp ? "wallet_credit" : "payment",
        },
      ],
      { session }
    );

    if (invoiceId) {
      invoice.paidAmount += value.amount;
      invoice.balanceDue = Math.max(invoice.netAmount - invoice.paidAmount, 0);
      invoice.paymentStatus =
        invoice.balanceDue === 0
          ? "paid"
          : invoice.paidAmount > 0
            ? "partial"
            : "unpaid";
      await invoice.save({ session });
    }

    if (isWalletTopUp) {
      await Customer.findByIdAndUpdate(
        customerId,
        { $inc: { balance: value.amount, walletBalance: value.amount } },
        { session }
      );
    }
    if (subscriptionId) {
      const subDoc = await Subscription.findOne({
        _id: subscriptionId,
        ownerId,
        customerId,
      }).session(session);

      if (!subDoc) {
        throw new ApiError(404, "Subscription not found");
      }

      const payAmt = Number(value.amount);
      if (subDoc.payLater === true) {
        const total = Number(subDoc.totalAmount ?? 0);
        const paid = Number(subDoc.paidAmount ?? 0);
        const room = Math.max(0, total - paid);
        const towardSub = Math.min(payAmt, room);
        if (towardSub > 0) {
          await Subscription.findByIdAndUpdate(
            subscriptionId,
            { $inc: { paidAmount: towardSub } },
            { session }
          );
        }
        const excess = payAmt - towardSub;
        if (excess > 0) {
          await Customer.findByIdAndUpdate(
            customerId,
            { $inc: { balance: excess, walletBalance: excess } },
            { session }
          );
        }
      } else {
        await Subscription.findByIdAndUpdate(
          subscriptionId,
          { $inc: { paidAmount: payAmt, remainingBalance: payAmt } },
          { session }
        );
      }
    }

    await session.commitTransaction();
    session.endSession();

    const paymentDoc = payment[0]; // Payment.create([...], session) returns an array

    const created = await Payment.findById(paymentDoc._id)
      .populate("customerId", "name phone address")
      .populate("invoiceId", "invoiceNumber netAmount balanceDue paymentStatus")
      .lean();

    const walletMsg =
      paymentDoc.type === "wallet_credit"
        ? `₹${paymentDoc.amount} added to wallet`
        : `Payment of ₹${paymentDoc.amount} received`;

    await sendNotification({
      customerId: paymentDoc.customerId,
      ownerId: ownerId,
      title: "Payment Received 💰",
      message: walletMsg,
      data: { paymentId: paymentDoc._id.toString() },
    }).catch(() => {}); // non-critical; never block payment response

    const response = new ApiResponse(201, "Payment recorded", created);
    res.status(response.statusCode).json({
      success: response.success,
      message: response.message,
      data: response.data,
    });
  } catch (err) {
    await session.abortTransaction();
    session.endSession();
    throw err;
  }
});

/**
 * POST /api/v1/payments/create-order
 * Create Razorpay order; return order_id and key_id for Flutter.
 */
export const createOrder = asyncHandler(async (req, res) => {
  const { error, value } = createOrderSchema.validate(req.body, {
    stripUnknown: true,
    abortEarly: false,
  });
  if (error) {
    throw new ApiError(400, error.details.map((d) => d.message).join("; "));
  }

  if (!config.RAZORPAY_KEY_ID || !config.RAZORPAY_KEY_SECRET) {
    throw new ApiError(503, "Razorpay is not configured");
  }

  let paymentId = value.receipt;
  if (value.customerId && value.invoiceId) {
    const ownerId = req.user.userId;
    const customer = await Customer.findOne({
      _id: value.customerId,
      ownerId,
      isDeleted: { $ne: true },
    });
    if (!customer) throw new ApiError(404, "Customer not found");

    const invoice = await Invoice.findOne({
      _id: value.invoiceId,
      ownerId,
    });
    if (!invoice) throw new ApiError(404, "Invoice not found");

    const payment = await Payment.create({
      ownerId,
      customerId: value.customerId,
      invoiceId: value.invoiceId,
      amount: value.amount,
      paymentMethod: "razorpay",
    });
    paymentId = payment._id.toString();
  }

  const { orderId, keyId } = await createRazorpayOrder(value.amount, paymentId);

  if (value.customerId && value.invoiceId) {
    await Payment.findOneAndUpdate(
      { _id: paymentId },
      { $set: { razorpayOrderId: orderId } }
    );
  }

  const response = new ApiResponse(200, "Order created", {
    orderId,
    keyId,
    amount: value.amount,
    receipt: paymentId,
    ...(value.customerId && { paymentId }),
  });

  res.status(response.statusCode).json({
    success: response.success,
    message: response.message,
    data: response.data,
  });
});

/**
 * GET /api/v1/payments/:id/invoice
 * Backwards compatibility: return basic payment info.
 */
export const getInvoice = asyncHandler(async (req, res) => {
  const ownerId = req.user.userId;
  const { id } = req.params;

  const payment = await Payment.findOne({ _id: id, ownerId }).lean();
  if (!payment) {
    throw new ApiError(404, "Payment not found");
  }

  const response = new ApiResponse(200, "Payment fetched", payment);
  res.status(response.statusCode).json(response);
});
