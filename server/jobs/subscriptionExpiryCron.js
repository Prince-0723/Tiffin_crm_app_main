import cron from "node-cron";
import Subscription from "../models/Subscription.model.js";
import { sendNotification } from "../services/inAppNotification.service.js";
import { NOTIFICATION_TYPES } from "../utils/notificationTypes.js";

export const startSubscriptionExpiryCron = () => {
  // Runs at 2:00 AM daily — safely after the midnight order-generation cron.
  cron.schedule("0 2 * * *", async () => {
    try {
      // Only expire subscriptions whose endDate is before today's UTC midnight.
      // This ensures a subscription ending "today" is NOT expired until tomorrow's
      // cron run, so today's daily orders are always generated first.
      const nowUtc = new Date();
      const todayUtcMidnight = new Date(
        Date.UTC(nowUtc.getUTCFullYear(), nowUtc.getUTCMonth(), nowUtc.getUTCDate())
      );

      const expiredSubscriptions = await Subscription.find({
        status: "active",
        endDate: { $lt: todayUtcMidnight },
      }).lean();

      if (!expiredSubscriptions.length) {
        console.log("No subscriptions to expire.");
        return;
      }

      await Subscription.updateMany(
        { _id: { $in: expiredSubscriptions.map((s) => s._id) } },
        { $set: { status: "expired" } }
      );

      console.log(
        `Subscription expiry cron ran. Expired: ${expiredSubscriptions.length}`
      );

      // FCM push + Notification doc for each expired subscription
      for (const sub of expiredSubscriptions) {
        await sendNotification({
          customerId: sub.customerId,
          ownerId: sub.ownerId,
          type: NOTIFICATION_TYPES.SUBSCRIPTION_EXPIRED,
          title: "Subscription Expired ❌",
          message:
            "Your subscription has expired. Please renew to continue service.",
          data: {
            subscriptionId: sub._id.toString(),
            screen: "subscriptions",
          },
        });
      }
    } catch (error) {
      console.error("Subscription expiry cron error:", error.message);
    }
  });
};
