/**
 * Firebase Admin for FCM (`sendToToken`). Optional: set FIREBASE_* env vars.
 */
import admin from "firebase-admin";
import config from "./index.js";

let _inited = false;

export function firebaseMessagingOrNull() {
  const {
    FIREBASE_PROJECT_ID: projectId,
    FIREBASE_CLIENT_EMAIL: clientEmail,
    FIREBASE_PRIVATE_KEY: privateKeyRaw,
  } = config;
  if (!projectId || !clientEmail || !privateKeyRaw) {
    return null;
  }
  if (!_inited) {
    const privateKey = String(privateKeyRaw).replace(/\\n/g, "\n");
    if (!admin.apps.length) {
      admin.initializeApp({
        credential: admin.credential.cert({
          projectId,
          clientEmail,
          privateKey,
        }),
      });
    }
    _inited = true;
  }
  return admin.messaging();
}
