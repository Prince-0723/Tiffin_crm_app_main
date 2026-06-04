/**
 * Subscription window day counts in Asia/Kolkata (IST), matching delivery rows.
 * Inclusive of both start and end calendar dates; "remaining" counts from
 * today (IST) through end, including today when the window is still active.
 */

const DAY_MS = 86400000;

/** IST calendar date string YYYY-MM-DD for "today". */
export function istTodayYmd() {
  return new Date().toLocaleDateString("en-CA", { timeZone: "Asia/Kolkata" });
}

/** YYYY-MM-DD in Asia/Kolkata for a stored Date. */
export function ymdIST(d) {
  if (!d) return "";
  return new Date(d).toLocaleDateString("en-CA", {
    timeZone: "Asia/Kolkata",
  });
}

/**
 * Inclusive calendar days from start → end (IST midnight boundaries).
 * Matches the delivery list row count for the subscription window.
 */
export function totalDaysInclusiveIST(startDate, endDate) {
  const startYmd = ymdIST(startDate);
  const endYmd = ymdIST(endDate);
  if (!startYmd || !endYmd) return 0;
  const startMs = new Date(`${startYmd}T00:00:00+05:30`).getTime();
  const endMs = new Date(`${endYmd}T00:00:00+05:30`).getTime();
  if (startMs > endMs) return 0;
  return Math.floor((endMs - startMs) / DAY_MS) + 1;
}

/**
 * Days left in the subscription window from today (IST) through end (inclusive).
 */
export function remainingDaysInclusiveIST(startDate, endDate) {
  const startYmd = ymdIST(startDate);
  const endYmd = ymdIST(endDate);
  if (!startYmd || !endYmd) return 0;
  const startMs = new Date(`${startYmd}T00:00:00+05:30`).getTime();
  const endMs = new Date(`${endYmd}T00:00:00+05:30`).getTime();
  const todayYmd = istTodayYmd();
  const todayMs = new Date(`${todayYmd}T00:00:00+05:30`).getTime();
  const remStartMs = Math.max(startMs, todayMs);
  let remainingDays = 0;
  if (remStartMs <= endMs) {
    for (let t = remStartMs; t <= endMs; t += DAY_MS) {
      remainingDays += 1;
    }
  }
  return remainingDays;
}
