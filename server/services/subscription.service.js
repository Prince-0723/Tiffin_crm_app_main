/**
 * Compute endDate from startDate + billingPeriod.
 * @param {Date} startDate - Subscription start date
 * @param {string} billingPeriod - "daily" | "weekly" | "monthly" | "custom"
 * @param {number} [customDays] - Required when billingPeriod is "custom"
 * @returns {Date} endDate (exclusive of last day: e.g. monthly = start + 1 month at 00:00)
 */
export const computeEndDate = (startDate, billingPeriod, customDays = 30) => {
  const date = new Date(startDate);

  switch (billingPeriod) {
    case "daily":
      date.setDate(date.getDate() + 1);
      break;
    case "weekly":
      date.setDate(date.getDate() + 7);
      break;
    case "monthly":
      date.setMonth(date.getMonth() + 1);
      break;
    case "custom":
      date.setDate(date.getDate() + (customDays || 30));
      break;
    default:
      date.setMonth(date.getMonth() + 1);
  }

  return date;
};
