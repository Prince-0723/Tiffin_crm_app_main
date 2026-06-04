import mongoose from "mongoose";

/**
 * Per-day delivery rows / cancellation overrides for the customer details deliveries tab.
 */
const deliveryScheduleSchema = new mongoose.Schema(
  {
    ownerId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },
    customerId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Customer",
      required: true,
      index: true,
    },
    date: {
      type: Date,
      required: true,
    },
    items: {
      type: String,
      default: "",
      trim: true,
    },
    status: {
      type: String,
      enum: ["pending", "delivered", "cancelled"],
      default: "pending",
    },
    cancelledAt: {
      type: Date,
      default: null,
    },
  },
  {
    timestamps: true,
  }
);

deliveryScheduleSchema.index(
  { customerId: 1, date: 1 },
  { unique: true }
);

const DeliverySchedule = mongoose.model("DeliverySchedule", deliveryScheduleSchema);

export default DeliverySchedule;
