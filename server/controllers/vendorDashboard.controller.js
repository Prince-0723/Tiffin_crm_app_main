import mongoose from "mongoose";
import Item from "../models/Item.model.js";
import DailyOrder from "../models/DailyOrder.model.js";
import {
  parseUTC,
  generateDailyOrdersForDate,
  getVendorDashboardOrderScope,
  applyVendorDashboardOrderScope,
  applyMealPeriodSlotFilter,
} from "../services/dailyOrder.service.js";
import { istTodayYmd } from "../utils/subscriptionCalendarDays.js";
import { asyncHandler } from "../utils/asyncHandler.js";
import { ApiResponse } from "../class/apiResponseClass.js";
import { ApiError } from "../class/apiErrorClass.js";

const YMD_RE = /^\d{4}-\d{2}-\d{2}$/;
const MEAL_PERIOD_VALUES = ["breakfast", "lunch", "dinner", "snack", "early_morning"];

/**
 * GET /api/v1/vendor/dashboard/daily-items
 * Optional query: date=YYYY-MM-DD (defaults to today in Asia/Kolkata)
 * Optional query: mealPeriod=breakfast|lunch|dinner|snack|early_morning
 *
 * Aggregates quantities from all active subscriptions that deliver on that date,
 * using each plan's mealSlots → items (linked Item docs for name/unit).
 */
export const getDailyItems = asyncHandler(async (req, res) => {
  const ownerId = req.user.userId;

  const rawDate = req.query.date;
  const rawMealPeriod = req.query.mealPeriod;
  let mealPeriod;
  if (rawMealPeriod != null && String(rawMealPeriod).trim() !== "") {
    const s = String(rawMealPeriod).trim();
    if (!MEAL_PERIOD_VALUES.includes(s)) {
      throw new ApiError(
        400,
        `Invalid mealPeriod; must be one of: ${MEAL_PERIOD_VALUES.join(", ")}`
      );
    }
    mealPeriod = s;
  }

  let dateStr;
  if (rawDate != null && String(rawDate).trim() !== "") {
    const s = String(rawDate).trim();
    if (!YMD_RE.test(s)) {
      throw new ApiError(400, "Invalid date; use YYYY-MM-DD");
    }
    const parsed = parseUTC(s);
    if (Number.isNaN(parsed.getTime())) {
      throw new ApiError(400, "Invalid date; use YYYY-MM-DD");
    }
    dateStr = s;
  } else {
    dateStr = istTodayYmd();
  }

  const day = parseUTC(dateStr);

  // Guarantee that daily orders are generated for the target day
  await generateDailyOrdersForDate(ownerId, day).catch(() => {});

  const scope = await getVendorDashboardOrderScope(ownerId);

  // Only non-delivered orders that still need preparation
  const dailyOrderFilter = {
    ownerId,
    orderDate: day,
    status: { $in: ["pending", "processing", "out_for_delivery"] },
  };

  applyVendorDashboardOrderScope(dailyOrderFilter, scope);
  if (mealPeriod) {
    Object.assign(dailyOrderFilter, applyMealPeriodSlotFilter({}, mealPeriod));
  }

  const orders = await DailyOrder.find(dailyOrderFilter)
    .populate({
      path: "customerId",
      match: { isDeleted: { $ne: true } },
    })
    .populate({
      path: "planId",
      match: { isActive: true },
    })
    .populate({
      path: "subscriptionId",
      match: { status: { $in: ["active", "paused"] } },
      select: "status",
    })
    .lean();

  const activeOrders = orders.filter(
    (o) => o.customerId && o.planId && o.subscriptionId
  );

  if (!activeOrders.length) {
    const response = new ApiResponse(200, "Daily items aggregated", {
      date: dateStr,
      customerCount: 0,
      filters: {
        mealPeriod: mealPeriod ?? null,
      },
      items: [],
    });
    return res.status(response.statusCode).json({
      success: response.success,
      message: response.message,
      data: response.data,
    });
  }

  const itemIdsNeeded = new Set();
  for (const ord of activeOrders) {
    for (const row of ord.resolvedItems || []) {
      if (row.itemId) itemIdsNeeded.add(row.itemId.toString());
    }
  }

  if (itemIdsNeeded.size === 0) {
    const response = new ApiResponse(200, "Daily items aggregated", {
      date: dateStr,
      customerCount: 0,
      filters: {
        mealPeriod: mealPeriod ?? null,
      },
      items: [],
    });
    return res.status(response.statusCode).json({
      success: response.success,
      message: response.message,
      data: response.data,
    });
  }

  const itemDocs = await Item.find({
    _id: {
      $in: [...itemIdsNeeded].map((id) => new mongoose.Types.ObjectId(id)),
    },
    ownerId,
  }).lean();

  const itemById = {};
  for (const it of itemDocs) {
    itemById[it._id.toString()] = it;
  }

  /** itemId -> total quantity */
  const totals = new Map();
  /** Customers who contribute at least one line item for this date + meal filter. */
  const contributingCustomerIds = new Set();

  for (const ord of activeOrders) {
    for (const row of ord.resolvedItems || []) {
      const idStr = row.itemId?.toString();
      if (!idStr || !itemById[idStr]) continue;
      const q = Number(row.quantity);
      if (!Number.isFinite(q) || q <= 0) continue;
      totals.set(idStr, (totals.get(idStr) || 0) + q);
      contributingCustomerIds.add(ord.customerId._id.toString());
    }
  }

  const items = [...totals.entries()]
    .map(([itemId, total_quantity]) => {
      const doc = itemById[itemId];
      return {
        name: doc.name,
        unit: doc.unit,
        total_quantity,
      };
    })
    .sort((a, b) => a.name.localeCompare(b.name, undefined, { sensitivity: "base" }));

  const response = new ApiResponse(200, "Daily items aggregated", {
    date: dateStr,
    customerCount: contributingCustomerIds.size,
    filters: {
      mealPeriod: mealPeriod ?? null,
    },
    items,
  });

  res.status(response.statusCode).json({
    success: response.success,
    message: response.message,
    data: response.data,
  });
});
