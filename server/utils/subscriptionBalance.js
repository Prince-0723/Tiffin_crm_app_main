/**
 * Display / API remaining subscription balance.
 * Prefer stored remainingBalance; else prepaid total; else legacy paidAmount fallback.
 * Used by customer portal and vendor customer-details so values stay aligned.
 */
export function effectiveRemaining(subscription) {
  if (!subscription) return 0;
  if (subscription.remainingBalance != null) {
    return Number(subscription.remainingBalance);
  }
  const total = Number(subscription.totalAmount ?? 0);
  if (total > 0) return total;
  return Number(subscription.paidAmount ?? 0);
}
