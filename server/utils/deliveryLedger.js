import MealPlan from "../models/Plan.model.js";

/** Map DailyOrder.resolvedItems → Transaction line items (legacy item-priced rows). */
export function resolvedToLineItems(resolvedItems = []) {
  if (!Array.isArray(resolvedItems)) return [];
  return resolvedItems
    .filter((it) => it && (it.itemName || it.subtotal != null))
    .map((it) => ({
      name: (it.itemName && String(it.itemName).trim()) || "Meal item",
      quantity: Number(it.quantity) > 0 ? Number(it.quantity) : 1,
      unitPrice: Math.max(0, Number(it.unitPrice) || 0),
    }));
}

/**
 * Ledger lines for a delivered daily order — billable total is always `order.amount`
 * (plan price / slot share), not catalog item totals.
 */
export function orderDeliveredLineItems(order) {
  const amt = Number(order?.amount);
  if (Number.isFinite(amt) && amt > 0) {
    const ri = Array.isArray(order?.resolvedItems) ? order.resolvedItems : [];
    const names = ri
      .map((it) =>
        it?.itemName != null ? String(it.itemName).trim() : ""
      )
      .filter(Boolean);
    const label =
      names.length > 0 ? names.join(", ") : "Meal delivery";
    return [{ name: label, quantity: 1, unitPrice: amt }];
  }
  const legacy = resolvedToLineItems(order?.resolvedItems);
  return legacy.length ? legacy : [];
}

/**
 * One-line summary for customer transaction list (amount is on the Transaction).
 */
export function buildDeliveredDescription({ planName, mealType, orderDate }) {
  const label = (planName && String(planName).trim()) || "Meal delivery";
  const slot = mealType ? String(mealType).replace(/_/g, " ") : "";
  let dayPart = "";
  if (orderDate) {
    const d = new Date(orderDate);
    if (!Number.isNaN(d.getTime())) dayPart = d.toISOString().slice(0, 10);
  }
  const bits = [label];
  if (slot) bits.push(`(${slot})`);
  if (dayPart) bits.push(`· ${dayPart}`);
  return bits.join(" ");
}

/** planId (ObjectId|string)[] → { [id]: planName } */
export async function planNamesByIds(planIds) {
  const ids = [
    ...new Set(
      (planIds || [])
        .filter(Boolean)
        .map((id) => (id && id.toString ? id.toString() : String(id)))
    ),
  ];
  if (!ids.length) return {};
  const docs = await MealPlan.find({ _id: { $in: ids } })
    .select("planName")
    .lean();
  const out = {};
  for (const p of docs) {
    out[p._id.toString()] = (p.planName && String(p.planName).trim()) || "Meal plan";
  }
  return out;
}
