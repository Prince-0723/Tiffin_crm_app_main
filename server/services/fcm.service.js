/**
 * Sends FCM to a device token (User/DeliveryStaff [fcmToken] from Flutter).
 * Requires FIREBASE_PROJECT_ID, FIREBASE_CLIENT_EMAIL, FIREBASE_PRIVATE_KEY in .env.
 */
import { firebaseMessagingOrNull } from "../config/firebase.js";

/** All [data] values must be strings for FCM data map — we stringify here. */
function stringifyData(data = {}) {
  const merged = {
    ...data,
    click_action: data.click_action ?? "FLUTTER_NOTIFICATION_CLICK",
  };
  return Object.fromEntries(
    Object.entries(merged).map(([k, v]) => [
      String(k),
      v == null ? "" : typeof v === "string" ? v : String(v),
    ])
  );
}

export const sendToToken = async (token, title, body, data = {}) => {
  if (!token || String(token).length < 10) return null;

  const messaging = firebaseMessagingOrNull();
  if (!messaging) {
    console.warn(
      "[FCM] Firebase Admin not configured — set FIREBASE_PROJECT_ID, FIREBASE_CLIENT_EMAIL, FIREBASE_PRIVATE_KEY"
    );
    return null;
  }

  const dataPayload = stringifyData(data);

  try {
    const messageId = await messaging.send({
      token: String(token).trim(),
      notification: title || body ? { title: title || "Tiffin CRM", body: body || "" } : undefined,
      data: Object.keys(dataPayload).length ? dataPayload : undefined,
      android: {
        priority: "high",
        notification: {
          channelId: String(
            dataPayload.channel_id || dataPayload.android_channel_id || "tiffin_crm_channel"
          ),
          sound: "default",
          clickAction: "FLUTTER_NOTIFICATION_CLICK",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    });
    return { success: true, messageId };
  } catch (err) {
    console.error("[FCM] send failed:", err.code || "", err.message);
    return { success: false, error: err.message };
  }
};
