import {
  getSummaryReport,
  getTodayDeliveriesReport,
  getExpiringSubscriptionsReport,
  getPendingPaymentsReport,
  getDeliveredOrderAmountReport,
} from "../services/report.service.js";
import { asyncHandler } from "../utils/asyncHandler.js";
import { ApiResponse } from "../class/apiResponseClass.js";
import { ApiError } from "../class/apiErrorClass.js";

/**
 * GET /api/v1/reports/summary?period=monthly|weekly|daily
 */
export const getSummary = asyncHandler(async (req, res) => {
  const { period = "monthly" } = req.query;
  const allowed = ["daily", "weekly", "monthly"];

  if (!allowed.includes(period)) {
    throw new ApiError(400, "Invalid period. Use daily, weekly, monthly.");
  }

  // Vendor: scoped to their ownerId. Admin: system-wide (no owner filter).
  const ownerId = req.user.role === "admin" ? null : req.user.userId;
  const data = await getSummaryReport(ownerId, period);

  const response = new ApiResponse(200, "Summary report fetched", data);
  res.status(response.statusCode).json(response);
});

/**
 * GET /api/v1/reports/today-deliveries
 */
export const getTodayDeliveries = asyncHandler(async (req, res) => {
  const ownerId = req.user.role === "admin" ? null : req.user.userId;
  const data = await getTodayDeliveriesReport(ownerId);

  const response = new ApiResponse(200, "Today's deliveries fetched", data);
  res.status(response.statusCode).json(response);
});

/**
 * GET /api/v1/reports/delivered-amount?date=YYYY-MM-DD
 * Sum of DailyOrder.amount where status is delivered for that UTC orderDate day.
 * Omit date for today (UTC). Vendor: own orders. Admin: all vendors.
 */
export const getDeliveredOrderAmount = asyncHandler(async (req, res) => {
  const { date } = req.query;
  const ownerId = req.user.role === "admin" ? null : req.user.userId;
  const data = await getDeliveredOrderAmountReport(ownerId, date);

  const response = new ApiResponse(
    200,
    "Delivered order amount fetched",
    data
  );
  res.status(response.statusCode).json(response);
});

/**
 * GET /api/v1/reports/expiring-subscriptions?days=7
 */
export const getExpiringSubscriptions = asyncHandler(async (req, res) => {
  const ownerId = req.user.role === "admin" ? null : req.user.userId;
  const days = parseInt(req.query.days ?? "7", 10);

  if (isNaN(days) || days < 1 || days > 90) {
    throw new ApiError(400, "days must be a number between 1 and 90");
  }

  const data = await getExpiringSubscriptionsReport(ownerId, days);

  const response = new ApiResponse(
    200,
    `Subscriptions expiring in the next ${days} day(s)`,
    data
  );
  res.status(response.statusCode).json(response);
});

/**
 * GET /api/v1/reports/pending-payments
 */
export const getPendingPayments = asyncHandler(async (req, res) => {
  const ownerId = req.user.role === "admin" ? null : req.user.userId;
  const data = await getPendingPaymentsReport(ownerId);

  const response = new ApiResponse(200, "Pending payments report fetched", data);
  res.status(response.statusCode).json(response);
});
