import Notification from "../models/Notification.model.js";
import { sendPushToUser } from "./onesignal.service.js";

/**
 * Send a push notification + create a Notification document.
 *
 * @param {object} opts
 * @param {string} [opts.userId]     - Vendor/user ObjectId → OneSignal external_id
 * @param {string} [opts.customerId] - Customer ObjectId → OneSignal external_id
 * @param {string} [opts.ownerId]    - Explicit vendor ownerId for scoping the Notification doc
 * @param {string} [opts.type]       - Notification type constant (from notificationTypes.js)
 * @param {string}  opts.title       - Notification title
 * @param {string}  opts.message     - Notification body (stored in DB; full text for in-app list)
 * @param {string} [opts.pushBody]   - Shorter body for mobile push only (defaults to message)
 * @param {object} [opts.data]       - Extra payload
 */
export const sendNotification = async ({
  userId,
  customerId,
  ownerId,
  type = "system",
  title,
  message,
  pushBody,
  data = {},
}) => {
  const targetId = userId || customerId || null;
  const pushText =
    pushBody != null && String(pushBody).length > 0 ? pushBody : message;

  let pushResult = null;
  if (targetId) {
    try {
      pushResult = await sendPushToUser(String(targetId), title, pushText, {
        ...data,
        type: type || "system",
      });
    } catch (err) {
      console.error("[OneSignal] push failed:", err.message);
      pushResult = { success: false, error: err.message };
    }
  }

  const notifOwnerId = ownerId || userId || undefined;

  await Notification.create({
    ownerId: notifOwnerId,
    customerId,
    type,
    title,
    message,
    data,
    channel: "in_app",
  });

  return pushResult;
};
