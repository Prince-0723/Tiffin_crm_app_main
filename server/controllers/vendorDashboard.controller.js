import mongoose from "mongoose";
import Subscription from "../models/Subscription.model.js";
import MealPlan from "../models/Plan.model.js";
import Item from "../models/Item.model.js";
import { parseUTC } from "../services/dailyOrder.service.js";
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
  const dow = day.getUTCDay();

  const subscriptions = await Subscription.find({
    ownerId,
    status: "active",
    startDate: { $lte: day },
    endDate: { $gte: day },
    deliveryDays: { $in: [dow] },
  }).lean();

  if (!subscriptions.length) {
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

  const planIds = [
    ...new Set(subscriptions.map((s) => s.planId.toString())),
  ].map((id) => new mongoose.Types.ObjectId(id));

  const plans = await MealPlan.find({ _id: { $in: planIds } }).lean();
  const planById = {};
  for (const p of plans) {
    planById[p._id.toString()] = p;
  }

  const itemIdsNeeded = new Set();
  for (const sub of subscriptions) {
    const plan = planById[sub.planId.toString()];
    if (!plan?.mealSlots?.length) continue;
    for (const slot of plan.mealSlots) {
      if (mealPeriod && slot?.slot !== mealPeriod) continue;
      for (const row of slot.items || []) {
        if (row.itemId) itemIdsNeeded.add(row.itemId.toString());
      }
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

  for (const sub of subscriptions) {
    const plan = planById[sub.planId.toString()];
    if (!plan?.mealSlots?.length) continue;

    for (const slot of plan.mealSlots) {
      if (mealPeriod && slot?.slot !== mealPeriod) continue;
      for (const row of slot.items || []) {
        const idStr = row.itemId?.toString();
        if (!idStr || !itemById[idStr]) continue;
        const q = Number(row.quantity);
        if (!Number.isFinite(q) || q <= 0) continue;
        totals.set(idStr, (totals.get(idStr) || 0) + q);
        contributingCustomerIds.add(sub.customerId.toString());
      }
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
