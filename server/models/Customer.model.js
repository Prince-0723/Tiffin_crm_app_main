import mongoose from "mongoose";

const CUSTOMER_STATUSES = ["active", "inactive", "blocked"];

const customerSchema = new mongoose.Schema(
  {
    ownerId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
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
    // Optional: if the customer's WhatsApp number is different from their registered phone.
    // When blank/null, the registered phone is used for WhatsApp links.
    whatsapp: {
      type: String,
      trim: true,
      default: null,
    },
    email: {
      type: String,
      lowercase: true,
      trim: true,
    },
    address: {
      type: String,
      required: true,
      trim: true,
    },
    area: {
      type: String,
      trim: true,
    },
    zoneId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Zone",
      default: null,
      index: true,
    },
    landmark: {
      type: String,
      trim: true,
    },
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
    photoUrl: {
      type: String,
    },
    notes: {
      type: String,
    },
    tags: [
      {
        type: String,
      },
    ],
    customerCode: {
      type: String, // Auto: C001, C002...
    },
    status: {
      type: String,
      enum: CUSTOMER_STATUSES,
      default: "active",
    },
    balance: {
      type: Number,
      default: 0,
    },
    /** Canonical wallet balance. Keep in sync with legacy `balance` during migration. */
    walletBalance: {
      type: Number,
      default: 0,
    },
    /** Extra charges billed separately (not deducted from subscription yet). */
    pendingDue: {
      type: Number,
      default: 0,
    },
    creditLimit: {
      type: Number,
      default: 0,
    },
    totalDue: {
      type: Number,
      default: 0,
    },
    fcmToken: {
      type: String,
      default: null,
    },
    portalEnabled: {
      type: Boolean,
      default: true,
    },
    reportToken: {
      type: String,
    },
    reportTokenExpiresAt: {
      type: Date,
    },
    loginToken: {
      type: String,
      default: null,
    },
    loginTokenExpiry: {
      type: Date,
      default: null,
    },
    isDeleted: {
      type: Boolean,
      default: false,
    },
    deletedAt: {
      type: Date,
    },
    /** Number of tiffin boxes currently held by the customer (vendor-adjusted). */
    tiffinCount: {
      type: Number,
      default: 0,
      min: 0,
    },
  },
  {
    timestamps: true,
  }
);

customerSchema.index({ ownerId: 1, phone: 1 });
customerSchema.index({ ownerId: 1, balance: 1 }); // low balance queries
customerSchema.index({ ownerId: 1, zoneId: 1 });
customerSchema.index({ location: "2dsphere" });
customerSchema.index({ status: 1 });
customerSchema.index({ createdAt: -1 });
customerSchema.index({ isDeleted: 1 });

const Customer = mongoose.model("Customer", customerSchema);

export default Customer;
export { CUSTOMER_STATUSES };
