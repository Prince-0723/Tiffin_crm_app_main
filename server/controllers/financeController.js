import Joi from "joi";
import mongoose from "mongoose";
import Transaction from "../models/Transaction.model.js";
import Customer from "../models/Customer.model.js";
import { asyncHandler } from "../utils/asyncHandler.js";
import { ApiError } from "../class/apiErrorClass.js";
import { parseUTC } from "../services/dailyOrder.service.js";
import { getFinanceSummary, getDailyBreakdown } from "../utils/financeCalc.js";

const FINANCE_TYPES = ["processed", "income", "deposit", "expense", "refund", "manual"];
const STATUSES = ["completed", "voided"];

const ymdSchema = Joi.string()
  .pattern(/^\d{4}-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])$/)
  .required()
  .messages({
    "string.pattern.base": "date must be YYYY-MM-DD (e.g. 2026-04-20)",
  });

const monthSchema = Joi.string()
  .pattern(/^\d{4}-(0[1-9]|1[0-2])$/)
  .required()
  .messages({
    "string.pattern.base": "month must be YYYY-MM (e.g. 2026-04)",
  });

function monthRangeUtc(monthStr) {
  const [yStr, mStr] = monthStr.split("-");
  const year = parseInt(yStr, 10);
  const month1to12 = parseInt(mStr, 10);
  const start = parseUTC(`${monthStr}-01`);
  let nextY = year;
  let nextM = month1to12 + 1;
  if (nextM > 12) {
    nextM = 1;
    nextY += 1;
  }
  const endExclusive = parseUTC(`${nextY}-${String(nextM).padStart(2, "0")}-01`);
  return { start, endExclusive, year, month1to12 };
}

function daysInCalendarMonth(year, month1to12) {
  return new Date(year, month1to12, 0).getDate();
}

function* iterateMonthDates(year, month1to12) {
  const dim = daysInCalendarMonth(year, month1to12);
  const ym = `${year}-${String(month1to12).padStart(2, "0")}`;
  for (let d = 1; d <= dim; d += 1) {
    yield `${ym}-${String(d).padStart(2, "0")}`;
  }
}

function oid(id, label) {
  if (!mongoose.Types.ObjectId.isValid(id)) {
    throw new ApiError(400, `Invalid ${label}`);
  }
  return new mongoose.Types.ObjectId(id);
}

function success(res, data, statusCode = 200) {
  res.status(statusCode).json({ success: true, data });
}

/**
 * POST /api/v1/finance/processed
 */
export const createProcessed = asyncHandler(async (req, res) => {
  const schema = Joi.object({
    customerId: Joi.string().required(),
    orderId: Joi.string().required(),
    date: Joi.date().iso().required(),
    amount: Joi.number().greater(0).required(),
    items: Joi.array()
      .items(
        Joi.object({
          name: Joi.string().trim().required(),
          quantity: Joi.number().min(0).optional(),
          unitPrice: Joi.number().min(0).optional(),
        })
      )
      .optional(),
    note: Joi.string().trim().allow("", null).optional(),
  });

  const { error, value } = schema.validate(req.body, {
    stripUnknown: true,
    abortEarly: false,
  });
  if (error) throw new ApiError(400, error.details.map((d) => d.message).join("; "));

  const ownerId = req.user.userId;
  const txn = await Transaction.create({
    ownerId,
    customerId: oid(value.customerId, "customerId"),
    orderId: oid(value.orderId, "orderId"),
    date: new Date(value.date),
    description: value.note || "",
    amount: value.amount,
    type: "credit",
    financeType: "processed",
    status: "completed",
    source: "processed",
    items: value.items || [],
  });

  success(res, txn, 201);
});

/**
 * POST /api/v1/finance/income
 */
export const createIncomeTxn = asyncHandler(async (req, res) => {
  const schema = Joi.object({
    customerId: Joi.string().required(),
    date: Joi.date().iso().required(),
    amount: Joi.number().greater(0).required(),
    source: Joi.string().trim().required(),
    note: Joi.string().trim().allow("", null).optional(),
  });

  const { error, value } = schema.validate(req.body, {
    stripUnknown: true,
    abortEarly: false,
  });
  if (error) throw new ApiError(400, error.details.map((d) => d.message).join("; "));

  const ownerId = req.user.userId;
  const txn = await Transaction.create({
    ownerId,
    customerId: oid(value.customerId, "customerId"),
    date: new Date(value.date),
    description: value.note || "",
    amount: value.amount,
    type: "credit",
    financeType: "income",
    status: "completed",
    source: value.source,
  });

  success(res, txn, 201);
});

/**
 * POST /api/v1/finance/deposit
 */
export const createDeposit = asyncHandler(async (req, res) => {
  const schema = Joi.object({
    customerId: Joi.string().required(),
    date: Joi.date().iso().required(),
    amount: Joi.number().greater(0).required(),
    paymentMode: Joi.string().trim().required(),
    note: Joi.string().trim().allow("", null).optional(),
  });

  const { error, value } = schema.validate(req.body, {
    stripUnknown: true,
    abortEarly: false,
  });
  if (error) throw new ApiError(400, error.details.map((d) => d.message).join("; "));

  const ownerId = req.user.userId;
  const txn = await Transaction.create({
    ownerId,
    customerId: oid(value.customerId, "customerId"),
    date: new Date(value.date),
    description: value.note || "",
    amount: value.amount,
    type: "credit",
    financeType: "deposit",
    status: "completed",
    source: "deposit",
    paymentMode: value.paymentMode,
  });

  success(res, txn, 201);
});

/**
 * POST /api/v1/finance/expense
 *
 * Note: existing Transaction schema requires customerId. For expenses we store
 * a vendor-scoped placeholder customerId (ownerId) and rely on financeType filters
 * for finance reporting.
 */
export const createExpenseTxn = asyncHandler(async (req, res) => {
  const schema = Joi.object({
    date: Joi.date().iso().required(),
    amount: Joi.number().greater(0).required(),
    category: Joi.string().trim().allow("", null).default(null),
    note: Joi.string().trim().allow("", null).optional(),
  });

  const { error, value } = schema.validate(req.body, {
    stripUnknown: true,
    abortEarly: false,
  });
  if (error) throw new ApiError(400, error.details.map((d) => d.message).join("; "));

  const ownerId = req.user.userId;
  const txn = await Transaction.create({
    ownerId,
    customerId: oid(ownerId, "ownerId"),
    date: new Date(value.date),
    description: value.note || "",
    amount: value.amount,
    type: "debit",
    financeType: "expense",
    status: "completed",
    source: "expense",
    category: value.category || null,
  });

  success(res, txn, 201);
});

/**
 * POST /api/v1/finance/refund
 */
export const createRefund = asyncHandler(async (req, res) => {
  const schema = Joi.object({
    originalTransactionId: Joi.string().required(),
    date: Joi.date().iso().required(),
    amount: Joi.number().greater(0).required(),
    note: Joi.string().trim().allow("", null).optional(),
  });

  const { error, value } = schema.validate(req.body, {
    stripUnknown: true,
    abortEarly: false,
  });
  if (error) throw new ApiError(400, error.details.map((d) => d.message).join("; "));

  const ownerId = req.user.userId;
  const originalId = oid(value.originalTransactionId, "originalTransactionId");

  const session = await mongoose.startSession();
  let refundTxn;
  await session.withTransaction(async () => {
    const original = await Transaction.findOne({ _id: originalId, ownerId }).session(session);
    if (!original) throw new ApiError(404, "Original transaction not found");
    if (original.status === "voided") throw new ApiError(400, "Original transaction already voided");

    original.status = "voided";
    await original.save({ session });

    refundTxn = await Transaction.create(
      [
        {
          ownerId,
          customerId: original.customerId,
          orderId: original.orderId || null,
          date: new Date(value.date),
          description: value.note || "",
          amount: value.amount,
          type: "debit",
          financeType: "refund",
          status: "completed",
          source: "refund",
        },
      ],
      { session }
    );
  });
  await session.endSession();

  success(res, refundTxn?.[0] || null, 201);
});

/**
 * GET /api/v1/finance/daily?date=YYYY-MM-DD
 */
export const getDailyFinance = asyncHandler(async (req, res) => {
  const schema = Joi.object({ date: ymdSchema });
  const { error, value } = schema.validate(req.query, { stripUnknown: true, abortEarly: false });
  if (error) throw new ApiError(400, error.details.map((d) => d.message).join("; "));

  const ownerId = req.user.userId;
  const start = parseUTC(value.date);
  const endExclusive = new Date(start);
  endExclusive.setUTCDate(endExclusive.getUTCDate() + 1);

  // Backward compatibility: this endpoint isn't used by the new Finance screen.
  success(res, {
    revenue: 0,
    incomes: 0,
    deposits: 0,
    expenses: 0,
    refunds: 0,
    gross_income: 0,
    net_profit: 0,
    pending_cash: 0,
  });
});

/**
 * GET /api/v1/finance/calendar?month=YYYY-MM
 * -> array of { date, revenue, expenses, net_profit } including zero days.
 */
export const getFinanceCalendar = asyncHandler(async (req, res) => {
  const schema = Joi.object({ month: monthSchema });
  const { error, value } = schema.validate(req.query, { stripUnknown: true, abortEarly: false });
  if (error) throw new ApiError(400, error.details.map((d) => d.message).join("; "));

  const ownerId = req.user.userId;
  const ownerOid = oid(ownerId, "ownerId");
  const { start, endExclusive, year, month1to12 } = monthRangeUtc(value.month);

  const rows = await Transaction.aggregate([
    {
      $match: {
        ownerId: ownerOid,
        status: "completed",
        date: { $gte: start, $lt: endExclusive },
      },
    },
    {
      $group: {
        _id: {
          $dateToString: { format: "%Y-%m-%d", date: "$date", timezone: "UTC" },
        },
        revenue: {
          $sum: {
            $cond: [
              {
                $and: [
                  { $eq: ["$financeType", "processed"] },
                  { $eq: ["$type", "credit"] },
                ],
              },
              { $ifNull: ["$amount", 0] },
              0,
            ],
          },
        },
        incomes: {
          $sum: {
            $cond: [
              { $and: [{ $eq: ["$financeType", "income"] }, { $eq: ["$type", "credit"] }] },
              { $ifNull: ["$amount", 0] },
              0,
            ],
          },
        },
        refunds: {
          $sum: {
            $cond: [
              { $and: [{ $eq: ["$financeType", "refund"] }, { $eq: ["$type", "debit"] }] },
              { $ifNull: ["$amount", 0] },
              0,
            ],
          },
        },
        expenses: {
          $sum: {
            $cond: [
              { $and: [{ $eq: ["$financeType", "expense"] }, { $eq: ["$type", "debit"] }] },
              { $ifNull: ["$amount", 0] },
              0,
            ],
          },
        },
      },
    },
    {
      $project: {
        _id: 0,
        date: "$_id",
        revenue: 1,
        expenses: 1,
        net_profit: {
          $subtract: [
            { $subtract: [{ $add: ["$revenue", "$incomes"] }, "$refunds"] },
            "$expenses",
          ],
        },
      },
    },
  ]);

  const map = new Map(rows.map((r) => [r.date, r]));
  const out = [];
  for (const d of iterateMonthDates(year, month1to12)) {
    const r = map.get(d);
    out.push({
      date: d,
      revenue: r?.revenue ?? 0,
      expenses: r?.expenses ?? 0,
      net_profit: r?.net_profit ?? 0,
    });
  }

  success(res, out);
});

/**
 * GET /api/v1/finance/summary?month=YYYY-MM
 * -> { ...totals, expenses_by_category[], income_by_source[] }
 */
export const getMonthlySummary = asyncHandler(async (req, res) => {
  // Unified endpoint:
  // - supports month=YYYY-MM (legacy)
  // - supports month=4&year=2026 (new)
  const schema = Joi.object({
    month: Joi.alternatives().try(monthSchema, Joi.number().integer().min(1).max(12)),
    year: Joi.number().integer().min(2000).max(2100).optional(),
  });
  const { error, value } = schema.validate(req.query, {
    stripUnknown: true,
    abortEarly: false,
  });
  if (error) throw new ApiError(400, error.details.map((d) => d.message).join("; "));

  const ownerId = req.user.userId;

  let startDate;
  let endDate;
  let month;
  let year;

  if (typeof value.month === "string") {
    const r = monthRangeUtc(value.month);
    startDate = r.start;
    endDate = new Date(r.endExclusive);
    endDate.setUTCMilliseconds(endDate.getUTCMilliseconds() - 1);
    month = r.month1to12;
    year = r.year;
  } else {
    month = value.month || new Date().getMonth() + 1;
    year = value.year || new Date().getFullYear();
    startDate = new Date(Date.UTC(year, month - 1, 1, 0, 0, 0, 0));
    endDate = new Date(Date.UTC(year, month, 0, 23, 59, 59, 999));
  }

  const [summary, daily] = await Promise.all([
    getFinanceSummary(ownerId, startDate, endDate),
    getDailyBreakdown(ownerId, startDate, endDate),
  ]);

  success(res, {
    summary,
    daily,
    period: {
      month,
      year,
      startDate,
      endDate,
    },
  });
});

/**
 * GET /api/v1/finance/pending?month=YYYY-MM
 * -> per customer: { customerId, name, gross_income, deposited, pending }
 */
export const getPendingByCustomer = asyncHandler(async (req, res) => {
  const schema = Joi.object({ month: monthSchema });
  const { error, value } = schema.validate(req.query, { stripUnknown: true, abortEarly: false });
  if (error) throw new ApiError(400, error.details.map((d) => d.message).join("; "));

  const ownerId = req.user.userId;
  const ownerOid = oid(ownerId, "ownerId");
  const { start, endExclusive } = monthRangeUtc(value.month);

  const rows = await Transaction.aggregate([
    {
      $match: {
        ownerId: ownerOid,
        status: "completed",
        date: { $gte: start, $lt: endExclusive },
        customerId: { $ne: null },
      },
    },
    {
      $group: {
        _id: "$customerId",
        revenue: {
          $sum: {
            $cond: [
              { $and: [{ $eq: ["$financeType", "processed"] }, { $eq: ["$type", "credit"] }] },
              { $ifNull: ["$amount", 0] },
              0,
            ],
          },
        },
        incomes: {
          $sum: {
            $cond: [
              { $and: [{ $eq: ["$financeType", "income"] }, { $eq: ["$type", "credit"] }] },
              { $ifNull: ["$amount", 0] },
              0,
            ],
          },
        },
        deposited: {
          $sum: {
            $cond: [
              { $and: [{ $eq: ["$financeType", "deposit"] }, { $eq: ["$type", "credit"] }] },
              { $ifNull: ["$amount", 0] },
              0,
            ],
          },
        },
      },
    },
    {
      $addFields: {
        gross_income: { $add: ["$revenue", "$incomes"] },
      },
    },
    {
      $addFields: {
        pending: { $subtract: ["$gross_income", "$deposited"] },
      },
    },
    { $match: { pending: { $gt: 0 } } },
    {
      $lookup: {
        from: Customer.collection.name,
        localField: "_id",
        foreignField: "_id",
        as: "customer",
      },
    },
    { $unwind: { path: "$customer", preserveNullAndEmptyArrays: true } },
    {
      $project: {
        _id: 0,
        customerId: "$_id",
        name: { $ifNull: ["$customer.name", null] },
        gross_income: 1,
        deposited: 1,
        pending: 1,
      },
    },
    { $sort: { pending: -1 } },
  ]);

  success(res, rows);
});

export const __financeEnums = {
  FINANCE_TYPES,
  STATUSES,
};

