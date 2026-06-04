import mongoose from "mongoose";

const mealSlotItemSchema = new mongoose.Schema(
  {
    itemId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Item",
      required: true,
    },
    quantity: {
      type: Number,
      required: true,
      min: 1,
    },
  },
  { _id: false }
);

const mealSlotSchema = new mongoose.Schema(
  {
    slot: {
      type: String,
      enum: ["breakfast", "lunch", "dinner", "snack", "early_morning"],
      required: true,
    },
    items: {
      type: [mealSlotItemSchema],
      default: [],
    },
  },
  { _id: false }
);

const mealPlanSchema = new mongoose.Schema(
  {
    ownerId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    planName: {
      type: String,
      required: true,
      trim: true,
    },
    planType: {
      type: String,
      enum: ["daily", "weekly", "monthly", "custom"],
      default: "monthly",
    },
    price: {
      type: Number,
      required: true,
      min: 0,
    },
    // mealSlots defines the actual items per meal time
    mealSlots: {
      type: [mealSlotSchema],
      default: [],
    },
    // derived convenience flags — true if plan contains that slot type
    includesBreakfast: {
      type: Boolean,
      default: false,
    },
    includesLunch: {
      type: Boolean,
      default: false,
    },
    includesDinner: {
      type: Boolean,
      default: false,
    },
    // When set, this plan is a custom plan created specifically for one customer.
    // null  → generic / reusable plan (all customers of this vendor can be subscribed).
    // ObjectId → customer-specific plan; only that customer can be subscribed to it.
    customerId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Customer",
      default: null,
    },
    isActive: {
      type: Boolean,
      default: true,
    },
    color: {
      type: String,
      default: "",
    },
  },
  {
    timestamps: true,
  }
);

// Auto-compute the convenience flags from mealSlots before save
mealPlanSchema.pre("save", async function () {
  if (this.mealSlots && this.mealSlots.length > 0) {
    const slots = this.mealSlots.map((s) => s.slot);
    this.includesBreakfast =
      slots.includes("breakfast") || slots.includes("early_morning");
    this.includesLunch = slots.includes("lunch");
    this.includesDinner = slots.includes("dinner");
  }
});

mealPlanSchema.index({ ownerId: 1, isActive: 1 });
mealPlanSchema.index({ ownerId: 1, customerId: 1 });

const MealPlan = mongoose.model("MealPlan", mealPlanSchema);

export default MealPlan;
