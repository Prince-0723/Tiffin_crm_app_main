import crypto from "crypto";
import mongoose from "mongoose";
import Payment from "../models/Payment.model.js";
import Subscription from "../models/Subscription.model.js";
import config from "../config/index.js";

/**
 * Verify Razorpay webhook signature.
 */
const verifyRazorpaySignature = (body, signature) => {
  const secret = config.RAZORPAY_WEBHOOK_SECRET;
  if (!secret) {
    throw new Error("Webhook secret not configured");
  }
  const expected = crypto
    .createHmac("sha256", secret)
    .update(body)
    .digest("hex");
  const sigBuf = Buffer.from(signature || "", "utf8");
  const expBuf = Buffer.from(expected, "utf8");
  if (sigBuf.length !== expBuf.length) return false;
  return crypto.timingSafeEqual(sigBuf, expBuf);
};

/**
 * POST /api/v1/webhooks/razorpay
 * Raw body required for signature verification.
 */
export const razorpayWebhook = async (req, res) => {
  const signature = req.headers["x-razorpay-signature"];
  const rawBody = req.body; // Buffer from express.raw()

  if (!rawBody || !Buffer.isBuffer(rawBody)) {
    return res.status(400).json({ success: false, message: "Invalid body" });
  }

  const bodyStr = rawBody.toString("utf8");

  try {
    if (!verifyRazorpaySignature(bodyStr, signature)) {
      return res.status(400).json({ success: false, message: "Invalid signature" });
    }
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }

  let payload;
  try {
    payload = JSON.parse(bodyStr);
  } catch {
    return res.status(400).json({ success: false, message: "Invalid JSON" });
  }

  const event = payload.event;
  if (event !== "payment.captured") {
    return res.status(200).json({ success: true, message: "Event ignored" });
  }

  const entity = payload.payload?.payment?.entity;
  if (!entity) {
    return res.status(400).json({ success: false, message: "Invalid payload" });
  }

  const razorpayPaymentId = entity.id;
  const razorpayOrderId = entity.order_id;
  const amountPaise = entity.amount || 0;
  const amount = amountPaise / 100;

  try {
    const existing = await Payment.findOne({ razorpayPaymentId });
    if (existing) {
      return res.status(200).json({ success: true, message: "Already processed" });
    }

    let payment = await Payment.findOne({ razorpayOrderId });

    if (payment) {
      payment.razorpayPaymentId = razorpayPaymentId;
      payment.status = "captured";
      payment.amount = amount;
      await payment.save();
    } else {
      const receipt = entity.receipt;
      let customerId = null;
      let subscriptionId = null;
      let ownerId = null;

      if (receipt && mongoose.Types.ObjectId.isValid(receipt)) {
        const sub = await Subscription.findById(receipt).lean();
        if (sub) {
          subscriptionId = sub._id;
          customerId = sub.customerId;
          ownerId = sub.ownerId;
        }
      }

      if (!customerId || !ownerId) {
        return res.status(200).json({
          success: true,
          message: "No linked customer; payment not stored",
        });
      }

      payment = await Payment.create({
        ownerId,
        customerId,
        subscriptionId: subscriptionId || undefined,
        amount,
        paymentMethod: "razorpay",
        status: "captured",
        razorpayOrderId,
        razorpayPaymentId,
      });
    }

    return res.status(200).json({ success: true, message: "Processed" });
  } catch (err) {
    console.error("Webhook DB error:", err.message);
    return res.status(500).json({ success: false, message: "Internal error processing webhook" });
  }
};
