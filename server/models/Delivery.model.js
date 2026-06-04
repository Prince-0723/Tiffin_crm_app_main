import mongoose from "mongoose";

const DELIVERY_STATUSES = ["pending", "in_progress", "delivered", "cancelled"];

const deliverySchema = new mongoose.Schema(
  {
    customerId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Customer",
      required: true,
    },
    subscriptionId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Subscription",
      required: true,
    },
    date: {
      type: Date,
      required: true,
    },
    status: {
      type: String,
      enum: DELIVERY_STATUSES,
      default: "pending",
    },
    deliveryBoyId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      default: null,
    },
    location: {
      type: {
        type: String,
        enum: ["Point"],
        default: "Point",
      },
      coordinates: {
        type: [Number], // [longitude, latitude]
        default: null,
      },
    },
    completedAt: {
      type: Date,
      default: null,
    },
  },
  {
    timestamps: true,
  }
);

deliverySchema.index({ date: 1 });
deliverySchema.index({ status: 1 });
deliverySchema.index({ customerId: 1 });
deliverySchema.index({ subscriptionId: 1, date: 1 }, { unique: true });

const Delivery = mongoose.model("Delivery", deliverySchema);

export default Delivery;
export { DELIVERY_STATUSES };
