/**
 * Build Mongo date range for calendar-day query params (YYYY-MM-DD or ISO).
 * Inclusive of both ends in UTC (start 00:00:00.000Z, end 23:59:59.999Z).
 */
export function utcDayRangeFilter(dateFrom, dateTo) {
  const filter = {};
  if (dateFrom) {
    const d = new Date(dateFrom);
    if (!Number.isNaN(d.getTime())) {
      filter.$gte = new Date(
        Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate(), 0, 0, 0, 0)
      );
    }
  }
  if (dateTo) {
    const d = new Date(dateTo);
    if (!Number.isNaN(d.getTime())) {
      filter.$lte = new Date(
        Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate(), 23, 59, 59, 999)
      );
    }
  }
  return Object.keys(filter).length ? filter : null;
}
