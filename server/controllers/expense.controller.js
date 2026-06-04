import Joi from "joi";
import mongoose from "mongoose";
import Expense, {
  EXPENSE_CATEGORIES,
  EXPENSE_PAYMENT_METHODS,
} from "../models/Expense.model.js";
import Income from "../models/Income.model.js";
import { asyncHandler } from "../utils/asyncHandler.js";
import { ApiResponse } from "../class/apiResponseClass.js";
import { ApiError } from "../class/apiErrorClass.js";
import { utcDayRangeFilter } from "../utils/utcDateRangeFilter.js";

const MAX_LIMIT = 200;
const DEFAULT_LIMIT = 20;
const DEFAULT_PAGE = 1;

const createSchema = Joi.object({
  title: Joi.string().trim().required(),
  amount: Joi.number().min(0).required(),
  category: Joi.string()
    .valid(...EXPENSE_CATEGORIES)
    .required(),
  date: Joi.date().iso().required(),
  notes: Joi.string().trim().allow("", null),
  paymentMethod: Joi.string().valid(...EXPENSE_PAYMENT_METHODS).optional(),
  tags: Joi.array().items(Joi.string().trim()).optional(),
  attachmentUrl: Joi.string().trim().allow("", null).optional(),
});

const listQuerySchema = Joi.object({
  page: Joi.number().integer().min(1).optional(),
  limit: Joi.number().integer().min(1).max(MAX_LIMIT).optional(),
  category: Joi.string()
    .valid(...EXPENSE_CATEGORIES)
    .optional(),
  dateFrom: Joi.date().iso().optional(),
  dateTo: Joi.date().iso().optional(),
  search: Joi.string().trim().allow("").optional(),
});

function monthRangeUtc() {
  const now = new Date();
  const start = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1));
  const end = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() + 1, 1));
  return { start, end };
}

function mapExpenseDoc(doc) {
  const o = doc.toObject ? doc.toObject() : doc;
  return {
    ...o,
    vendorId: o.ownerId,
  };
}

/**
 * POST /api/v1/expenses
 */
export const createExpense = asyncHandler(async (req, res) => {
  const { error, value } = createSchema.validate(req.body, {
    stripUnknown: true,
    abortEarly: false,
  });
  if (error) {
    throw new ApiError(400, error.details.map((d) => d.message).join("; "));
  }

  const ownerId = req.user.userId;
  const expense = await Expense.create({
    ownerId,
    title: value.title,
    amount: value.amount,
    category: value.category,
    date: new Date(value.date),
    notes: value.notes || undefined,
    paymentMethod: value.paymentMethod,
    tags: value.tags || [],
    attachmentUrl: value.attachmentUrl || undefined,
  });

  const response = new ApiResponse(201, "Expense created", mapExpenseDoc(expense));
  res.status(response.statusCode).json({
    success: response.success,
    message: response.message,
    data: response.data,
  });
});

/**
 * GET /api/v1/expenses
 */
export const listExpenses = asyncHandler(async (req, res) => {
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
  if (value.category) filter.category = value.category;
  const dateBounds = utcDayRangeFilter(value.dateFrom, value.dateTo);
  if (dateBounds) filter.date = dateBounds;
  if (value.search && value.search.trim()) {
    filter.title = { $regex: value.search.trim(), $options: "i" };
  }

  const [rows, total] = await Promise.all([
    Expense.find(filter)
      .sort({ date: -1 })
      .skip(skip)
      .limit(limit)
      .lean(),
    Expense.countDocuments(filter),
  ]);

  const data = rows.map((r) => ({ ...r, vendorId: r.ownerId }));

  const response = new ApiResponse(200, "Expenses fetched", {
    data,
    total,
    page,
    limit,
    totalPages: Math.ceil(total / limit),
  });
  res.status(response.statusCode).json({
    success: response.success,
    message: response.message,
    data: response.data,
  });
});

/**
 * DELETE /api/v1/expenses/:id
 */
export const deleteExpense = asyncHandler(async (req, res) => {
  const ownerId = req.user.userId;
  const { id } = req.params;

  if (!mongoose.Types.ObjectId.isValid(id)) {
    throw new ApiError(400, "Invalid expense id");
  }

  const existing = await Expense.findById(id).lean();
  if (!existing) {
    throw new ApiError(404, "Expense not found");
  }
  if (existing.ownerId.toString() !== ownerId.toString()) {
    throw new ApiError(403, "Forbidden");
  }

  await Expense.deleteOne({ _id: id, ownerId });

  const response = new ApiResponse(200, "Expense deleted successfully", null);
  res.status(response.statusCode).json({
    success: response.success,
    message: response.message,
    data: response.data,
  });
});

/**
 * GET /api/v1/expenses/summary
 */
export const getExpenseSummary = asyncHandler(async (req, res) => {
  const ownerId = req.user.userId;
  const { start, end } = monthRangeUtc();

  const [expenseAgg, incomeAgg, byCategory] = await Promise.all([
    Expense.aggregate([
      {
        $match: {
          ownerId: new mongoose.Types.ObjectId(ownerId),
          date: { $gte: start, $lt: end },
        },
      },
      { $group: { _id: null, total: { $sum: "$amount" } } },
    ]),
    Income.aggregate([
      {
        $match: {
          ownerId: new mongoose.Types.ObjectId(ownerId),
          date: { $gte: start, $lt: end },
        },
      },
      { $group: { _id: null, total: { $sum: "$amount" } } },
    ]),
    Expense.aggregate([
      {
        $match: {
          ownerId: new mongoose.Types.ObjectId(ownerId),
          date: { $gte: start, $lt: end },
        },
      },
      {
        $group: {
          _id: "$category",
          total: { $sum: "$amount" },
        },
      },
      { $sort: { total: -1 } },
    ]),
  ]);

  const totalExpenseThisMonth = expenseAgg[0]?.total ?? 0;
  const totalIncomeThisMonth = incomeAgg[0]?.total ?? 0;
  const netBalance = totalIncomeThisMonth - totalExpenseThisMonth;

  const categoryBreakdown = byCategory.map((row) => {
    const catTotal = row.total ?? 0;
    const pct =
      totalExpenseThisMonth > 0
        ? Math.round((catTotal / totalExpenseThisMonth) * 10000) / 100
        : 0;
    return {
      category: row._id,
      total: catTotal,
      percentage: pct,
    };
  });

  const payload = {
    totalExpenseThisMonth,
    totalIncomeThisMonth,
    netBalance,
    categoryBreakdown,
  };

  const response = new ApiResponse(200, "Expense summary fetched", payload);
  res.status(response.statusCode).json({
    success: response.success,
    message: response.message,
    data: response.data,
  });
});
