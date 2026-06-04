import twilio from "twilio";
import config from "../config/index.js";

function getTwilioClient() {
  const { TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_SERVICE_SID } = config;
  if (!TWILIO_ACCOUNT_SID || !TWILIO_AUTH_TOKEN || !TWILIO_SERVICE_SID) {
    return null;
  }
  return twilio(TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN);
}

/** Verify API requires a Service SID (starts with VA), not Account SID (AC). */
function isVerifyServiceSid(sid) {
  return typeof sid === "string" && sid.trim().startsWith("VA");
}

/**
 * Send OTP using Twilio Verify
 */
export const sendOtp = async (phone) => {
  try {
    const client = getTwilioClient();
    if (!client) {
      return {
        success: false,
        message:
          "OTP service is not configured. Set TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, and TWILIO_SERVICE_SID in environment.",
      };
    }

    const serviceSid = config.TWILIO_SERVICE_SID?.trim();
    if (!isVerifyServiceSid(serviceSid)) {
      const prefix = serviceSid ? `${serviceSid.substring(0, 2)}...` : "empty or missing";
      return {
        success: false,
        message: `TWILIO_SERVICE_SID must be a Verify Service SID (starts with VA). Current value appears to be: ${prefix} Get the correct SID from Twilio Console → Verify → Services (create a service if needed) and set TWILIO_SERVICE_SID=VA... in config/.env. Do not use the Account SID (AC...).`,
      };
    }

    const digits = String(phone).replace(/\D/g, "");
    const formattedPhone = digits.length === 10 ? `+91${digits}` : `+91${digits.replace(/^91/, "")}`;
    if (!/^\+91[6-9]\d{9}$/.test(formattedPhone)) {
      return {
        success: false,
        message: "Phone must be a valid 10-digit Indian mobile number.",
      };
    }

    await client.verify.v2
      .services(serviceSid)
      .verifications.create({
        to: formattedPhone,
        channel: "sms",
      });

    return { success: true };
  } catch (error) {
    const msg = error.message || "";
    const code = error.code;
    if (code === 60200 || msg.includes("Invalid parameter")) {
      console.error("[sendOtp] Twilio 60200 Invalid parameter:", {
        code: error.code,
        message: error.message,
        moreInfo: error.moreInfo,
      });
      return {
        success: false,
        message:
          "Could not send OTP. Check that TWILIO_SERVICE_SID is a Verify Service SID (VA...) and the phone number is valid. On trial accounts, the number may need to be verified in Twilio Console.",
      };
    }
    return {
      success: false,
      message: msg || "Failed to send OTP",
    };
  }
};

/**
 * Verify OTP using Twilio Verify
 */
export const verifyOtp = async (phone, otp) => {
  try {
    const client = getTwilioClient();
    if (!client) return false;

    const serviceSid = config.TWILIO_SERVICE_SID?.trim();
    if (!isVerifyServiceSid(serviceSid)) return false;

    const digits = String(phone).replace(/\D/g, "");
    const formattedPhone = digits.length === 10 ? `+91${digits}` : `+91${digits.replace(/^91/, "")}`;

    const response = await client.verify.v2
      .services(serviceSid)
      .verificationChecks.create({
        to: formattedPhone,
        code: otp,
      });

    return response.status === "approved";
  } catch (error) {
    return false;
  }
};
