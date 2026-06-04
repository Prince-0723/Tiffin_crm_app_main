import path from "path";
import dotenv from "dotenv";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: path.join(__dirname, ".env") });

const required = ["MONGODB_URL", "JWT_ACCESS_SECRET", "JWT_REFRESH_SECRET"];

const optional = {
  PORT: 5000,
  NODE_ENV: "development",

  JWT_ACCESS_SECRET: process.env.JWT_ACCESS_SECRET || "",
  JWT_REFRESH_SECRET: process.env.JWT_REFRESH_SECRET || "",
  JWT_ACCESS_EXPIRY: process.env.JWT_ACCESS_EXPIRY || "15m",
  JWT_REFRESH_EXPIRY: process.env.JWT_REFRESH_EXPIRY || "7d",

  // Razorpay
  RAZORPAY_KEY_ID: process.env.RAZORPAY_KEY_ID || "",
  RAZORPAY_KEY_SECRET: process.env.RAZORPAY_KEY_SECRET || "",
  RAZORPAY_WEBHOOK_SECRET: process.env.RAZORPAY_WEBHOOK_SECRET || "",

  // Firebase (optional — legacy; push uses OneSignal)
  FIREBASE_PROJECT_ID: process.env.FIREBASE_PROJECT_ID || "",
  FIREBASE_CLIENT_EMAIL: process.env.FIREBASE_CLIENT_EMAIL || "",
  FIREBASE_PRIVATE_KEY: process.env.FIREBASE_PRIVATE_KEY || "",

  ONESIGNAL_APP_ID: process.env.ONESIGNAL_APP_ID || "",
  ONESIGNAL_REST_API_KEY: process.env.ONESIGNAL_REST_API_KEY || "",

  MSG91_AUTH_KEY: process.env.MSG91_AUTH_KEY || "",
  MSG91_TEMPLATE_ID: process.env.MSG91_TEMPLATE_ID || "",

  // 🔥 ADD THIS FOR TWILIO
  TWILIO_ACCOUNT_SID: process.env.TWILIO_ACCOUNT_SID || "",
  TWILIO_AUTH_TOKEN: process.env.TWILIO_AUTH_TOKEN || "",
  TWILIO_SERVICE_SID: process.env.TWILIO_SERVICE_SID || "",

  RATE_LIMIT: {
    windowMs: Number(process.env.RATE_LIMIT_WINDOW_MS) || 15 * 60 * 1000,
    max: Number(process.env.RATE_LIMIT_MAX) || 100,
    message:
      process.env.RATE_LIMIT_MESSAGE ||
      "Too many requests, please try again later.",
  },
};

for (const key of required) {
  if (!process.env[key]) {
    throw new Error(`Missing required env: ${key}`);
  }
}

export default {
  PORT: Number(process.env.PORT) || optional.PORT,
  NODE_ENV: process.env.NODE_ENV || optional.NODE_ENV,
  MONGODB_URL: process.env.MONGODB_URL,

  JWT_ACCESS_SECRET:
    process.env.JWT_ACCESS_SECRET || optional.JWT_ACCESS_SECRET,
  JWT_REFRESH_SECRET:
    process.env.JWT_REFRESH_SECRET || optional.JWT_REFRESH_SECRET,
  JWT_ACCESS_EXPIRY:
    process.env.JWT_ACCESS_EXPIRY || optional.JWT_ACCESS_EXPIRY,
  JWT_REFRESH_EXPIRY:
    process.env.JWT_REFRESH_EXPIRY || optional.JWT_REFRESH_EXPIRY,

  RAZORPAY_KEY_ID: process.env.RAZORPAY_KEY_ID || optional.RAZORPAY_KEY_ID,
  RAZORPAY_KEY_SECRET:
    process.env.RAZORPAY_KEY_SECRET || optional.RAZORPAY_KEY_SECRET,
  RAZORPAY_WEBHOOK_SECRET:
    process.env.RAZORPAY_WEBHOOK_SECRET || optional.RAZORPAY_WEBHOOK_SECRET,

  FIREBASE_PROJECT_ID:
    process.env.FIREBASE_PROJECT_ID || optional.FIREBASE_PROJECT_ID,
  FIREBASE_CLIENT_EMAIL:
    process.env.FIREBASE_CLIENT_EMAIL || optional.FIREBASE_CLIENT_EMAIL,
  FIREBASE_PRIVATE_KEY:
    process.env.FIREBASE_PRIVATE_KEY || optional.FIREBASE_PRIVATE_KEY,

  ONESIGNAL_APP_ID:
    process.env.ONESIGNAL_APP_ID || optional.ONESIGNAL_APP_ID,
  ONESIGNAL_REST_API_KEY:
    process.env.ONESIGNAL_REST_API_KEY || optional.ONESIGNAL_REST_API_KEY,

  MSG91_AUTH_KEY: process.env.MSG91_AUTH_KEY || optional.MSG91_AUTH_KEY,
  MSG91_TEMPLATE_ID:
    process.env.MSG91_TEMPLATE_ID || optional.MSG91_TEMPLATE_ID,

  // 🔥 EXPORT TWILIO
  TWILIO_ACCOUNT_SID:
    process.env.TWILIO_ACCOUNT_SID || optional.TWILIO_ACCOUNT_SID,
  TWILIO_AUTH_TOKEN:
    process.env.TWILIO_AUTH_TOKEN || optional.TWILIO_AUTH_TOKEN,
  TWILIO_SERVICE_SID:
    process.env.TWILIO_SERVICE_SID || optional.TWILIO_SERVICE_SID,

  CORS_ORIGIN: process.env.CORS_ORIGIN || "",

  // email settings (SendGrid)
  SENDGRID_API_KEY: process.env.SENDGRID_API_KEY || "",
  FROM_EMAIL: process.env.FROM_EMAIL || "noreply@tiffincrm.com",
  FRONTEND_URL: process.env.FRONTEND_URL || "",

  RATE_LIMIT: {
    windowMs:
      Number(process.env.RATE_LIMIT_WINDOW_MS) || optional.RATE_LIMIT.windowMs,
    max: Number(process.env.RATE_LIMIT_MAX) || optional.RATE_LIMIT.max,
    message: process.env.RATE_LIMIT_MESSAGE || optional.RATE_LIMIT.message,
  },
};
