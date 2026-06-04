import DailyOrder from "../models/DailyOrder.model.js";
import Subscription from "../models/Subscription.model.js";
import MealPlan from "../models/Plan.model.js";
import Item from "../models/Item.model.js";
import { payLaterWouldExceedCreditLimit } from "../utils/subscriptionPayLater.js";

export const parseUTC = (d) => {
  if (!d) return new Date();
  if (d instanceof Date) {
    const date = new Date(d);
    date.setUTCHours(0, 0, 0, 0);
    return date;
  }
  const parts = String(d)
    .split("-")
    .map((x) => parseInt(x, 10));
  if (parts.length === 3) {
    const [y, m, day] = parts;
    return new Date(Date.UTC(y, m - 1, day));
  }
  const date = new Date(d);
  date.setUTCHours(0, 0, 0, 0);
  return date;
};

/**
 * Determine mealType string from the plan's mealSlots.
 * Falls back to includesLunch/includesDinner for legacy plans without mealSlots.
 */
const resolveMealType = (plan) => {
  if (plan.mealSlots && plan.mealSlots.length > 0) {
    const slots = plan.mealSlots.map((s) => s.slot);
    if (slots.length === 1) {
      const s = slots[0];
      if (s === "lunch") return "lunch";
      if (s === "dinner") return "dinner";
      if (s === "breakfast" || s === "early_morning") return "breakfast";
      if (s === "snack") return "snack";
    }
    const hasLunch = slots.includes("lunch");
    const hasDinner = slots.includes("dinner");
    if (hasLunch && hasDinner) return "both";
    return "all";
  }
  // legacy fallback
  if (plan.includesLunch && plan.includesDinner) return "both";
  if (plan.includesDinner) return "dinner";
  return "lunch";
};

/**
 * Map filter values to stored DailyOrder.mealType values.
 * "both" = lunch+dinner; "all" = multiple slots (may include breakfast/snack).
 */
export const MEAL_PERIOD_TO_MEALTYPES = {
  breakfast: ["breakfast", "all"],
  lunch: ["lunch", "both", "all"],
  dinner: ["dinner", "both", "all"],
  snack: ["snack", "all"],
};

/**
 * Mutates `filter` (Mongo query object) with mealPeriod + dietType constraints.
 */
export function applyMealDietToFilter(filter, { mealPeriod, dietType } = {}) {
  if (mealPeriod) {
    const allowed = MEAL_PERIOD_TO_MEALTYPES[mealPeriod];
    if (allowed?.length) {
      filter.mealType = { $in: allowed };
    }
  }

  if (dietType === "veg") {
    filter.$or = [{ dietType: "veg" }, { dietType: { $exists: false } }];
  } else if (dietType === "non_veg") {
    filter.dietType = { $in: ["non_veg", "mixed"] };
  } else if (dietType === "mixed") {
    filter.dietType = "mixed";
  }
}

function computeOrderDietType(plan, itemMap) {
  const kinds = new Set();
  for (const slot of plan.mealSlots || []) {
    for (const slotItem of slot.items || []) {
      const id = slotItem.itemId?.toString();
      const doc = id ? itemMap[id] : null;
      if (doc) kinds.add(doc.dietType || "veg");
    }
  }
  if (kinds.size === 0) return "veg";
  if (kinds.size === 1) return [...kinds][0];
  if (kinds.has("veg") && kinds.has("non_veg")) return "mixed";
  return [...kinds][0];
}

/** One DailyOrder row per subscription/day when the plan has no per-slot items. */
export const COMBINED_PLAN_MEAL_SLOT = "combined";

/**
 * `plan.price` is the billed amount for one calendar day for the whole plan.
 * Split it evenly across configured meal slots (paise-rounded; remainder spread on first slots).
 */
export function splitPlanDailyPriceAcrossMealSlots(planPrice, slotCount) {
  const n = Number(slotCount) || 0;
  if (n <= 0) return [];
  const paiseTotal = Math.round(Math.max(0, Number(planPrice) || 0) * 100);
  const base = Math.floor(paiseTotal / n);
  const remainder = paiseTotal - base * n;
  return Array.from(
    { length: n },
    (_, i) => (base + (i < remainder ? 1 : 0)) / 100
  );
}

function slotToOrderMealType(slot) {
  if (slot === "early_morning") return "breakfast";
  if (
    slot === "breakfast" ||
    slot === "lunch" ||
    slot === "dinner" ||
    slot === "snack"
  ) {
    return slot;
  }
  return "lunch";
}

/**
 * Builds one row per plan.mealSlots entry: each row `amount` is this slot's share of
 * `plan.price` (per-day plan rate). Menu items are stored for fulfilment only; billing
 * does not use catalog item prices. Plans without mealSlots use one row at `plan.price`.
 */
const buildOrderRowsForPlan = async (plan) => {
  if (!plan.mealSlots?.length) {
    return [
      {
        planMealSlot: COMBINED_PLAN_MEAL_SLOT,
        mealType: resolveMealType(plan),
        resolvedItems: [],
        amount: Number(plan.price) || 0,
        orderDietType: "veg",
      },
    ];
  }

  const allItemIds = [
    ...new Set(
      plan.mealSlots.flatMap((slot) =>
        (slot.items || []).map((i) => i.itemId.toString())
      )
    ),
  ];

  let itemMap = {};
  if (allItemIds.length) {
    const itemDocs = await Item.find({ _id: { $in: allItemIds } })
      .select("name unitPrice dietType")
      .lean();
    for (const item of itemDocs) {
      itemMap[item._id.toString()] = item;
    }
  }

  const slotShares = splitPlanDailyPriceAcrossMealSlots(
    plan.price ?? 0,
    plan.mealSlots.length
  );

  return plan.mealSlots.map((mealSlot, idx) => {
    const resolvedItems = [];
    for (const slotItem of mealSlot.items || []) {
      const itemData = itemMap[slotItem.itemId.toString()];
      if (!itemData) continue;

      resolvedItems.push({
        itemId: slotItem.itemId,
        itemName: itemData.name,
        quantity: slotItem.quantity,
        unitPrice: 0,
        subtotal: 0,
      });
    }

    const orderDietType = computeOrderDietType(
      { mealSlots: [mealSlot] },
      itemMap
    );

    const amount = typeof slotShares[idx] === "number" ? slotShares[idx] : 0;

    return {
      planMealSlot: mealSlot.slot,
      mealType: slotToOrderMealType(mealSlot.slot),
      resolvedItems,
      amount,
      orderDietType,
    };
  });
};

/**
 * Generate DailyOrder records for a given date and owner.
 * Used by POST /subscriptions and the midnight cron.
 */
export const generateDailyOrdersForDate = async (ownerId, date) => {
  const day = parseUTC(date || new Date());
  const dow = day.getUTCDay(); // 0-6 Sunday-Saturday

  console.log("🔍 generateDailyOrdersForDate:", {
    ownerId: ownerId.toString(),
    date: day.toISOString(),
    dayOfWeek: dow,
  });

  // Fetch active + paused subscriptions; paused ones are filtered per-date below
  const subscriptions = await Subscription.find({
    ownerId,
    startDate: { $lte: day },
    endDate: { $gte: day },
    status: { $in: ["active", "paused"] },
    deliveryDays: { $in: [dow] },
  }).lean();

  console.log("📦 Found subscriptions:", subscriptions.length);

  if (!subscriptions.length)
    return { generatedCount: 0, existingCount: 0, skippedCreditLimit: 0 };

  // Skip subscription+slot pairs that already have a row (supports one row per meal slot).
  const existing = await DailyOrder.find({
    ownerId,
    orderDate: day,
    subscriptionId: { $in: subscriptions.map((s) => s._id) },
  })
    .select("subscriptionId planMealSlot")
    .lean();

  const existingSet = new Set(
    existing.map((d) => {
      const slot =
        d.planMealSlot != null && String(d.planMealSlot).trim() !== ""
          ? String(d.planMealSlot).trim()
          : COMBINED_PLAN_MEAL_SLOT;
      return `${d.subscriptionId.toString()}|${slot}`;
    })
  );

  const planIds = [...new Set(subscriptions.map((s) => s.planId.toString()))];

  // Fetch all plans in one query
  const plans = await MealPlan.find({ _id: { $in: planIds } }).lean();
  const planMap = {};
  for (const plan of plans) {
    planMap[plan._id.toString()] = plan;
  }

  const toInsert = [];
  let skippedCreditLimit = 0;
  const orderRowsByPlanId = new Map();

  const getRowsForPlan = async (plan) => {
    const pid = plan._id.toString();
    if (!orderRowsByPlanId.has(pid)) {
      orderRowsByPlanId.set(pid, await buildOrderRowsForPlan(plan));
    }
    return orderRowsByPlanId.get(pid);
  };

  for (const sub of subscriptions) {
    const plan = planMap[sub.planId.toString()];
    if (!plan) {
      console.warn(
        `⚠️  Plan ${sub.planId} not found for subscription ${sub._id}`
      );
      continue;
    }

    // Skip paused subscriptions for this date range
    if (
      sub.status === "paused" &&
      sub.pausedFrom &&
      sub.pausedUntil &&
      day >= parseUTC(sub.pausedFrom) &&
      day <= parseUTC(sub.pausedUntil)
    ) {
      console.log(
        `⏸  Skipping paused subscription ${sub._id} for ${day.toISOString()}`
      );
      continue;
    }

    const slotRows = await getRowsForPlan(plan);

    let tentativeExtraForDay = 0;
    for (const row of slotRows) {
      const dedupeKey = `${sub._id.toString()}|${row.planMealSlot}`;
      if (existingSet.has(dedupeKey)) continue;

      const rowAmt = Number(row.amount) || 0;
      if (
        sub.payLater === true &&
        payLaterWouldExceedCreditLimit(sub, tentativeExtraForDay + rowAmt)
      ) {
        skippedCreditLimit += 1;
        console.warn(
          `[dailyOrder] Skipping order (credit limit): sub=${sub._id} date=${day.toISOString().slice(0, 10)} slot=${row.planMealSlot} amt=${rowAmt}`
        );
        continue;
      }

      tentativeExtraForDay += rowAmt;

      toInsert.push({
        ownerId,
        customerId: sub.customerId,
        subscriptionId: sub._id,
        planId: sub.planId,
        orderDate: day,
        planMealSlot: row.planMealSlot,
        mealType: row.mealType,
        dietType: row.orderDietType,
        deliverySlot: sub.deliverySlot,
        resolvedItems: row.resolvedItems,
        amount: row.amount,
        status: "pending",
      });
      existingSet.add(dedupeKey);
    }
  }

  if (!toInsert.length) {
    return {
      generatedCount: 0,
      existingCount: existing.length,
      skippedCreditLimit,
    };
  }

  await DailyOrder.insertMany(toInsert);

  console.log(
    `✅ Generated ${toInsert.length} orders for ${day.toISOString().slice(0, 10)}`
  );

  return {
    generatedCount: toInsert.length,
    existingCount: existing.length,
    skippedCreditLimit,
  };
};

/**
 * @param {object} [filters]
 * @param {string} [filters.mealPeriod] - breakfast | lunch | dinner | snack (filters mealType)
 * @param {string} [filters.dietType] - veg | non_veg | mixed
 */
export const getTodayDailyOrders = async (ownerId, filters = {}) => {
  const today = parseUTC(new Date());
  const base = {
    ownerId,
    orderDate: today,
    status: { $ne: "cancelled" },
  };

  applyMealDietToFilter(base, filters);

  return DailyOrder.find(base)
    .populate("customerId", "name phone address area")
    .populate("planId", "planName price")
    .populate("deliveryStaffId", "name phone")
    .populate("resolvedItems.itemId", "name unitPrice unit dietType")
    .sort({ createdAt: 1 })
    .lean();
};

export const generateOrdersForNextDays = async (ownerId, days = 7) => {
  const results = [];

  // Build dates in UTC to avoid local-midnight / IST timezone footgun.
  const nowUtc = new Date();
  const todayUtc = new Date(
    Date.UTC(nowUtc.getUTCFullYear(), nowUtc.getUTCMonth(), nowUtc.getUTCDate())
  );

  for (let i = 0; i < days; i++) {
    const date = new Date(todayUtc);
    date.setUTCDate(todayUtc.getUTCDate() + i);

    const result = await generateDailyOrdersForDate(ownerId, date);

    results.push({
      date: date.toISOString().slice(0, 10),
      ...result,
    });
  }

  return results;
};
