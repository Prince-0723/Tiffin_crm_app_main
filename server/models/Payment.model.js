import mongoose from "mongoose";

const PAYMENT_METHODS = [
  "cash",
  "upi",
  "bank_transfer",
  "cheque",
  "razorpay",
  "other",
];

const PAYMENT_STATUSES = ["pending", "captured", "failed", "refunded"];
const PAYMENT_TYPES = ["payment", "wallet_credit", "order_deduction"];

const paymentSchema = new mongoose.Schema(
  {
    ownerId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    customerId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Customer",
      required: true,
    },
    invoiceId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Invoice",
      required: false,
    },
    subscriptionId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Subscription",
      required: false,
    },
    amount: {
      type: Number,
      required: true,
      min: 0.01,
    },
    paymentMethod: {
      type: String,
      enum: PAYMENT_METHODS,
      required: true,
    },
    paymentDate: {
      type: Date,
      default: Date.now,
    },
    status: {
      type: String,
      enum: PAYMENT_STATUSES,
      default: "captured",
    },
    type: {
      type: String,
      enum: PAYMENT_TYPES,
      default: "payment",
    },
    transactionRef: {
      type: String,
    },
    notes: {
      type: String,
    },
    receiptUrl: {
      type: String,
    },
    razorpayOrderId: {
      type: String,
    },
    razorpayPaymentId: {
      type: String,
    },
    razorpaySignature: {
      type: String,
    },
  },
  {
    timestamps: true,
  }
);

paymentSchema.index({ ownerId: 1, customerId: 1 });
paymentSchema.index({ ownerId: 1, status: 1 });
paymentSchema.index({ razorpayPaymentId: 1 }, { sparse: true, unique: true });

const Payment = mongoose.model("Payment", paymentSchema);

export default Payment;
export { PAYMENT_METHODS, PAYMENT_STATUSES, PAYMENT_TYPES };
