import { ApiError } from "../class/apiErrorClass.js";
import Subscription from "../models/Subscription.model.js";

/**
 * "Unsecured" meal consumption: value already served from remainingBalance
 * runway but not yet covered by cash paid toward the subscription
 * (= consumed − paid, floored at 0).
 *
 * prepaid (payLater false): not used (returns 0).
 */
export function payLaterConsumptionExposure(subscription) {
  if (!subscription || subscription.payLater !== true) return 0;
  const total = Number(subscription.totalAmount ?? 0);
  const paid = Number(subscription.paidAmount ?? 0);
  const remRaw = subscription.remainingBalance;
  const rem = Number.isFinite(Number(remRaw)) ? Number(remRaw) : total;
  const consumed = Math.max(0, total - rem);
  return Math.max(0, consumed - paid);
}

/** Credit cap rupees for pay-later; defaults to contract total when unset. */
export function payLaterEffectiveCreditCap(subscription) {
  if (!subscription || subscription.payLater !== true) return Infinity;
  const total = Number(subscription.totalAmount ?? 0);
  const lim = Number(subscription.creditLimit);
  if (Number.isFinite(lim) && lim >= 0) return lim;
  return total > 0 ? total : Infinity;
}

/**
 * True if attaching `additionalConsumptionRupees` more meal value would breach cap.
 */
export function payLaterWouldExceedCreditLimit(subscription, additionalConsumptionRupees) {
  const extra = Number(additionalConsumptionRupees) || 0;
  if (extra <= 0 || !subscription || subscription.payLater !== true)
    return false;
  const cap = payLaterEffectiveCreditCap(subscription);
  const exp = payLaterConsumptionExposure(subscription);
  return exp + extra > cap + 1e-6;
}

export function assertPayLaterAllowsConsumption(subscription, orderAmountRupees) {
  if (!subscription || subscription.payLater !== true) return;
  const amt = Number(orderAmountRupees) || 0;
  if (amt <= 0) return;
  if (!payLaterWouldExceedCreditLimit(subscription, amt)) return;

  const cap = payLaterEffectiveCreditCap(subscription);
  const exp = payLaterConsumptionExposure(subscription);
  throw new ApiError(
    400,
    `Credit limit exceeded for this subscription after this charge. Outstanding meal exposure would be ₹${(exp + amt).toFixed(
      0
    )} (limit ₹${cap.toFixed(0)}). Take a payment toward the plan or raise the credit limit.`
  );
}

/**
 * Cash still due on a pay-later subscription (plan total − recorded payments).
 */
export function subscriptionCashOwed(subscription) {
  if (!subscription || !subscription.payLater) return 0;
  const total = Number(subscription.totalAmount ?? 0);
  const paid = Number(subscription.paidAmount ?? 0);
  if (!Number.isFinite(total) || total <= 0) return 0;
  return Math.max(0, total - paid);
}

/**
 * Applies up to `amount` rupees to already-consumed, unpaid pay-later meals.
 * Future plan value stays unpaid until it is actually delivered; any excess goes to wallet.
 * Returns { remainder, appliedToSubscription } — remainder goes to caller (e.g. wallet).
 */
export async function settlePayLaterSubscriptions({
  session,
  ownerId,
  customerId,
  amount,
}) {
  let remainder = Number(amount);
  if (!Number.isFinite(remainder) || remainder <= 0) {
    return { remainder: Number(amount) || 0, appliedToSubscription: 0 };
  }

  let appliedTotal = 0;
  const now = new Date();

  // Process multiple overlapping credit subs defensively (oldest consumed first).
  const subscriptions = await Subscription.find({
    ownerId,
    customerId,
    payLater: true,
    status: { $in: ["active", "paused"] },
    endDate: { $gte: now },
  })
    .sort({ startDate: 1 })
    .session(session)
    .lean();

  for (const sub of subscriptions) {
    if (remainder <= 0) break;

    const owed = payLaterConsumptionExposure(sub);
    if (owed <= 0) continue;

    const apply = Math.min(remainder, owed);
    await Subscription.findByIdAndUpdate(
      sub._id,
      { $inc: { paidAmount: apply } },
      { session }
    );
    appliedTotal += apply;
    remainder -= apply;
  }

  return { remainder, appliedToSubscription: appliedTotal };
}
