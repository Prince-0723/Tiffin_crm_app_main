import config from "../config/index.js";

// Current OneSignal API (not legacy onesignal.com/api/v1)
const BASE_URL = "https://api.onesignal.com/notifications";

const appId = () => config.ONESIGNAL_APP_ID || "";
const restKey = () => config.ONESIGNAL_REST_API_KEY || "";

/**
 * Send push to one OneSignal external_id (MongoDB User or Customer _id string).
 * Client must call OneSignal.login(externalId) with the same id.
 */
export const sendPushToUser = async (externalId, title, body, data = {}) => {
  if (!externalId) return null;

  const id = appId();
  const key = restKey();
  if (!id || !key) {
    console.warn(
      "[OneSignal] Missing ONESIGNAL_APP_ID or ONESIGNAL_REST_API_KEY — skip push"
    );
    return null;
  }

  const stringData = Object.fromEntries(
    Object.entries(data || {}).map(([k, v]) => [k, v == null ? "" : String(v)])
  );

  const payload = {
    app_id: id,
    include_aliases: { external_id: [String(externalId)] },
    target_channel: "push",
    headings: { en: title },
    contents: { en: body },
    data: stringData,
    priority: 10,
    android_accent_color: "FF4CAF50",
    small_icon: "ic_launcher",
  };

  const res = await fetch(BASE_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Key ${key}`,
    },
    body: JSON.stringify(payload),
  });

  const json = await res.json().catch(() => ({}));
  if (!res.ok || json.errors) {
    console.error(
      "[OneSignal] HTTP",
      res.status,
      res.statusText,
      "body:",
      json.errors || json
    );
    return json;
  }
  return json;
};

// Raw FCM device tokens → use `./fcm.service.js` via `notification.service.js` export [sendToToken].
