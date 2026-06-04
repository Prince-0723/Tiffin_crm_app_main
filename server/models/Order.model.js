import mongoose from "mongoose";

const orderSchema = new mongoose.Schema(
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
    mealTime: {
      type: String,
      enum: ["breakfast", "lunch", "dinner"],
      required: true,
    },
    itemsRaw: {
      type: String,
    },
    items: [
      {
        name: String,
        quantity: {
          type: Number,
          default: 1,
        },
      },
    ],
    price: {
      type: Number,
      required: true,
    },
    orderType: {
      type: String,
      enum: ["repeat", "one_time"],
      default: "repeat",
    },
    frequency: {
      type: String,
      enum: ["daily", "custom"],
      default: "daily",
    },
    activeDays: [
      {
        type: String,
        enum: ["mon", "tue", "wed", "thu", "fri", "sat", "sun"],
      },
    ],
    startDate: {
      type: Date,
      required: true,
    },
    endDate: {
      type: Date,
    },
    status: {
      type: String,
      enum: ["active", "paused", "cancelled", "completed"],
      default: "active",
    },
    isDeleted: {
      type: Boolean,
      default: false,
    },
  },
  {
    timestamps: true,
  }
);

orderSchema.index({ ownerId: 1, customerId: 1 });
orderSchema.index({ status: 1, startDate: 1 });

const Order = mongoose.model("Order", orderSchema);

export default Order;

