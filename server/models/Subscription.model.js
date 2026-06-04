import mongoose from "mongoose";

const SUBSCRIPTION_STATUSES = ["active", "paused", "expired", "cancelled"];

const subscriptionSchema = new mongoose.Schema(
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
    planId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "MealPlan",
      required: true,
    },
    startDate: {
      type: Date,
      required: true,
    },
    endDate: {
      type: Date,
      required: true,
    },
    deliverySlot: {
      type: String,
      enum: ["morning", "afternoon", "evening"],
      default: "morning",
    },
    deliveryDays: {
      type: [Number],
      default: [0, 1, 2, 3, 4, 5, 6], // 0=Sun ... 6=Sat
    },
    status: {
      type: String,
      enum: SUBSCRIPTION_STATUSES,
      default: "active",
    },
    totalAmount: {
      type: Number,
      required: true,
    },
    paidAmount: {
      type: Number,
      default: 0,
    },
    /** Remaining prepaid value on this subscription (defaults to totalAmount on create). */
    remainingBalance: {
      type: Number,
      default: null,
    },
    pausedFrom: {
      type: Date,
    },
    pausedUntil: {
      type: Date,
    },
    autoRenew: {
      type: Boolean,
      default: false,
    },
    notes: {
      type: String,
    },
    /**
     * When true, subscription was created/renewed without debiting wallet;
     * `paidAmount` tracks cash settled toward `totalAmount` while meals use `remainingBalance`.
     */
    payLater: {
      type: Boolean,
      default: false,
    },
    /** Max unpaid plan rupees allowed (defaults to totalAmount on create); informational / future caps. */
    creditLimit: {
      type: Number,
      default: null,
    },
    /** Vendor / customer-agreed payment target date (informational). */
    paymentDueDate: {
      type: Date,
      default: null,
    },
  },
  {
    timestamps: true,
  }
);

subscriptionSchema.pre("save", function () {
  if (this.remainingBalance == null && this.totalAmount != null) {
    this.remainingBalance = this.totalAmount;
  }
});

subscriptionSchema.index({ ownerId: 1, customerId: 1, status: 1 });
subscriptionSchema.index({ ownerId: 1, endDate: 1 });

const Subscription = mongoose.model("Subscription", subscriptionSchema);

export default Subscription;
export { SUBSCRIPTION_STATUSES };
