import cron from "node-cron";
import User from "../models/User.model.js";
import {
  generateDailyOrdersForDate,
  parseUTC,
} from "../services/dailyOrder.service.js";

const schedule = process.env.DELIVERY_CRON_SCHEDULE || "0 0 * * *";
const timeZone =
  process.env.DELIVERY_CRON_TIMEZONE || "Asia/Kolkata";
const daysAhead = Math.min(
  31,
  Math.max(1, parseInt(process.env.DELIVERY_CRON_DAYS_AHEAD || "7", 10) || 7)
);

/**
 * Calendar YYYY-MM-DD in the given IANA zone (e.g. Asia/Kolkata) at this instant.
 * Matches how vendors think of "today" when the job runs at local midnight.
 */
const ymdInTimeZone = (instant, tz) => {
  const dtf = new Intl.DateTimeFormat("en-CA", {
    timeZone: tz,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  });
  const parts = dtf.formatToParts(instant);
  const get = (t) => parts.find((p) => p.type === t)?.value;
  const yyyy = get("year");
  const mm = get("month");
  const dd = get("day");
  if (!yyyy || !mm || !dd) {
    throw new Error(`[DailyOrderCron] ymdInTimeZone failed for zone ${tz}`);
  }
  return `${yyyy}-${mm}-${dd}`;
};

export const runDailyOrderGenerationJob = async () => {
  const ymd = ymdInTimeZone(new Date(), timeZone);
  const startDay = parseUTC(ymd);

  const owners = await User.find({ role: "vendor", isActive: true })
    .select("_id")
    .lean();

  let succeeded = 0;
  let failed = 0;

  for (const o of owners) {
    for (let i = 0; i < daysAhead; i++) {
      const date = new Date(startDay);
      date.setUTCDate(startDay.getUTCDate() + i);

      try {
        await generateDailyOrdersForDate(o._id, date);
        succeeded++;
      } catch (err) {
        console.error(
          `[DailyOrderCron] Failed for owner ${o._id} on ${date.toISOString().slice(0, 10)}: ${err.message}`
        );
        failed++;
      }
    }
  }

  console.log(
    `[DailyOrderCron] Done — anchor ${ymd} (${timeZone}) | ${owners.length} vendors × ${daysAhead} days | ok: ${succeeded} | failed: ${failed}`
  );
};

export const startDeliveryCron = () => {
  if (String(process.env.DELIVERY_CRON_ENABLED).toLowerCase() === "false") {
    console.log("[DailyOrderCron] Disabled (DELIVERY_CRON_ENABLED=false)");
    return;
  }

  cron.schedule(
    schedule,
    () => {
      runDailyOrderGenerationJob().catch((err) => {
        console.error("[DailyOrderCron] Unhandled error:", err);
      });
    },
    { timezone: timeZone }
  );

  console.log(
    `[DailyOrderCron] Scheduled: "${schedule}" (timezone: ${timeZone}, days ahead: ${daysAhead})`
  );
};
