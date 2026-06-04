import mongoose from "mongoose";

const dailyOrderSchema = new mongoose.Schema(
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
    subscriptionId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Subscription",
    },
    orderId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Order",
    },
    planId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "MealPlan",
    },
    orderDate: {
      type: Date,
      required: true,
    },
    /** Which meal(s) this order covers — breakfast / lunch / dinner / snack, or both/all for multi-slot plans. */
    mealType: {
      type: String,
      enum: ["breakfast", "lunch", "dinner", "snack", "both", "all"],
      required: true,
    },
    /**
     * Which meal slot this row belongs to (from plan.mealSlots[].slot).
     * `combined` = legacy / plans without per-slot items (one row per subscription per day).
     */
    planMealSlot: {
      type: String,
      trim: true,
      default: "combined",
    },
    /** Aggregated from plan items: all veg, all non-veg, or mixed. */
    dietType: {
      type: String,
      enum: ["veg", "non_veg", "mixed"],
      default: "veg",
    },
    deliverySlot: {
      type: String,
      enum: ["morning", "afternoon", "evening"],
    },
    deliveryStaffId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "DeliveryStaff",
    },
    resolvedItems: [
      {
        itemId: {
          type: mongoose.Schema.Types.ObjectId,
          ref: "Item",
        },
        itemName: {
          type: String,
        },
        quantity: {
          type: Number,
          min: 1,
        },
        unitPrice: {
          type: Number,
          min: 0,
        },
        subtotal: {
          type: Number,
          min: 0,
        },
      },
    ],
    amount: {
      type: Number,
    },
    isCharged: {
      type: Boolean,
      default: false,
    },
    status: {
      type: String,
      enum: [
        "pending",
        "processing",
        "out_for_delivery",
        "delivered",
        "cancelled",
        "failed",
        "skipped",
      ],
      default: "pending",
    },
    cancelledBy: {
      type: String,
      enum: ["customer", "owner", null],
      default: null,
    },
    cancellationReason: {
      type: String,
    },
    cancelledAt: {
      type: Date,
    },
    processedAt: {
      type: Date,
    },
    acceptedAt: {
      type: Date,
    },
    outForDeliveryAt: {
      type: Date,
    },
    deliveredAt: {
      type: Date,
    },
    deliveryNote: {
      type: String,
    },
    deliveryPhotoUrl: {
      type: String,
    },
    customerRating: {
      type: Number,
      min: 1,
      max: 5,
    },
    customerFeedback: {
      type: String,
    },
    ratedAt: {
      type: Date,
    },
  },
  {
    timestamps: true,
  }
);

dailyOrderSchema.index({ ownerId: 1, orderDate: 1, status: 1 });
dailyOrderSchema.index({ ownerId: 1, orderDate: 1, mealType: 1, dietType: 1 });
dailyOrderSchema.index({ customerId: 1, orderDate: -1 });
dailyOrderSchema.index({ ownerId: 1, orderDate: 1, deliveryStaffId: 1 });
// One row per subscription per calendar day per slot (or `combined` for legacy single-row plans).
dailyOrderSchema.index(
  { subscriptionId: 1, orderDate: 1, planMealSlot: 1 },
  { unique: true, sparse: true }
);

const DailyOrder = mongoose.model("DailyOrder", dailyOrderSchema);

export default DailyOrder;

