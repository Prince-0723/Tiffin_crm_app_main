import mongoose from "mongoose";

const deliveryStaffSchema = new mongoose.Schema(
  {
    ownerId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    // Linked User account — set automatically when staff first logs in via OTP
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      default: null,
    },
    name: {
      type: String,
      required: true,
      trim: true,
    },
    phone: {
      type: String,
      required: true,
      trim: true,
    },
    areas: [
      {
        type: String,
      },
    ],
    zones: [
      {
        type: mongoose.Schema.Types.ObjectId,
        ref: "Zone",
      },
    ],
    fcmToken: {
      type: String,
      default: null,
    },
    // Last known GPS location — updated via PATCH /delivery-staff/me or socket events.
    location: {
      type: {
        type: String,
        enum: ["Point"],
        default: "Point",
      },
      coordinates: {
        type: [Number], // [longitude, latitude]
        default: [0, 0],
      },
    },
    isActive: {
      type: Boolean,
      default: true,
    },
    joiningDate: {
      type: Date,
    },
  },
  {
    timestamps: true,
  }
);

deliveryStaffSchema.index({ ownerId: 1, isActive: 1 });
deliveryStaffSchema.index({ ownerId: 1, phone: 1 }, { unique: true });
deliveryStaffSchema.index({ userId: 1 }, { sparse: true });
deliveryStaffSchema.index({ location: "2dsphere" });

const DeliveryStaff = mongoose.model("DeliveryStaff", deliveryStaffSchema);

export default DeliveryStaff;
