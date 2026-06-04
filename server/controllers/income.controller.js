import Joi from "joi";
import mongoose from "mongoose";
import Income, { INCOME_PAYMENT_METHODS } from "../models/Income.model.js";
import { asyncHandler } from "../utils/asyncHandler.js";
import { ApiResponse } from "../class/apiResponseClass.js";
import { ApiError } from "../class/apiErrorClass.js";
import { utcDayRangeFilter } from "../utils/utcDateRangeFilter.js";

const MAX_LIMIT = 200;
const DEFAULT_LIMIT = 20;
const DEFAULT_PAGE = 1;

const createSchema = Joi.object({
  source: Joi.string().trim().required(),
  amount: Joi.number().min(0).required(),
  date: Joi.date().iso().required(),
  notes: Joi.string().trim().allow("", null),
  paymentMethod: Joi.string().valid(...INCOME_PAYMENT_METHODS).optional(),
  referenceId: Joi.string().trim().allow("", null),
});

const listQuerySchema = Joi.object({
  page: Joi.number().integer().min(1).optional(),
  limit: Joi.number().integer().min(1).max(MAX_LIMIT).optional(),
  source: Joi.string().trim().allow("").optional(),
  dateFrom: Joi.date().iso().optional(),
  dateTo: Joi.date().iso().optional(),
});

function mapIncomeDoc(doc) {
  const o = doc.toObject ? doc.toObject() : doc;
  return {
    ...o,
    vendorId: o.ownerId,
  };
}

/**
 * POST /api/v1/incomes
 */
export const createIncome = asyncHandler(async (req, res) => {
  const { error, value } = createSchema.validate(req.body, {
    stripUnknown: true,
    abortEarly: false,
  });
  if (error) {
    throw new ApiError(400, error.details.map((d) => d.message).join("; "));
  }

  const ownerId = req.user.userId;
  const income = await Income.create({
    ownerId,
    source: value.source,
    amount: value.amount,
    date: new Date(value.date),
    notes: value.notes || undefined,
    paymentMethod: value.paymentMethod,
    referenceId: value.referenceId || undefined,
  });

  const response = new ApiResponse(201, "Income created", mapIncomeDoc(income));
  res.status(response.statusCode).json({
    success: response.success,
    message: response.message,
    data: response.data,
  });
});

/**
 * GET /api/v1/incomes
 */
export const listIncomes = asyncHandler(async (req, res) => {
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
  const dateBounds = utcDayRangeFilter(value.dateFrom, value.dateTo);
  if (dateBounds) filter.date = dateBounds;
  if (value.source && value.source.trim()) {
    filter.source = { $regex: value.source.trim(), $options: "i" };
  }

  const [rows, total] = await Promise.all([
    Income.find(filter)
      .sort({ date: -1 })
      .skip(skip)
      .limit(limit)
      .lean(),
    Income.countDocuments(filter),
  ]);

  const data = rows.map((r) => ({ ...r, vendorId: r.ownerId }));

  const response = new ApiResponse(200, "Incomes fetched", {
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
 * DELETE /api/v1/incomes/:id
 */
export const deleteIncome = asyncHandler(async (req, res) => {
  const ownerId = req.user.userId;
  const { id } = req.params;

  if (!mongoose.Types.ObjectId.isValid(id)) {
    throw new ApiError(400, "Invalid income id");
  }

  const existing = await Income.findById(id).lean();
  if (!existing) {
    throw new ApiError(404, "Income not found");
  }
  if (existing.ownerId.toString() !== ownerId.toString()) {
    throw new ApiError(403, "Forbidden");
  }

  await Income.deleteOne({ _id: id, ownerId });

  const response = new ApiResponse(200, "Income deleted successfully", null);
  res.status(response.statusCode).json({
    success: response.success,
    message: response.message,
    data: response.data,
  });
});
