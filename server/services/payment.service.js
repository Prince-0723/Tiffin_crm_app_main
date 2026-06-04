import Razorpay from "razorpay";
import config from "../config/index.js";

let razorpayInstance = null;

const getRazorpay = () => {
  if (!razorpayInstance) {
    if (!config.RAZORPAY_KEY_ID || !config.RAZORPAY_KEY_SECRET) {
      throw new Error("Razorpay keys not configured");
    }
    razorpayInstance = new Razorpay({
      key_id: config.RAZORPAY_KEY_ID,
      key_secret: config.RAZORPAY_KEY_SECRET,
    });
  }
  return razorpayInstance;
};

/**
 * Create Razorpay order.
 * @param {number} amount - Amount in INR (Razorpay expects paise, so we multiply by 100)
 * @param {string} receiptId - Unique receipt id (e.g. paymentId or subscriptionId)
 * @returns {Promise<{ orderId: string, keyId: string }>}
 */
export const createRazorpayOrder = async (amount, receiptId) => {
  const razorpay = getRazorpay();
  const amountPaise = Math.round(amount * 100);

  const order = await razorpay.orders.create({
    amount: amountPaise,
    currency: "INR",
    receipt: String(receiptId),
  });

  return {
    orderId: order.id,
    keyId: config.RAZORPAY_KEY_ID,
  };
};
