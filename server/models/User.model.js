import mongoose from "mongoose";

const userSchema = new mongoose.Schema(
  {
    // Core business owner fields (from spec)
    businessName: {
      type: String,
      trim: true,
      default: "",
    },
    ownerName: {
      type: String,
      trim: true,
      default: "",
    },
    phone: {
      type: String,
      required: true,
      unique: true,
      trim: true,
    },
    email: {
      type: String,
      sparse: true,
      lowercase: true,
      trim: true,
    },
    address: {
      type: String,
      trim: true,
    },
    city: {
      type: String,
      trim: true,
    },
    state: {
      type: String,
      default: "Maharashtra",
      trim: true,
    },
    logoUrl: {
      type: String,
    },
    /** Shown on customer app for UPI payments (e.g. name@paytm). */
    upiId: {
      type: String,
      trim: true,
      default: "",
    },
    fcmToken: {
      type: String,
      default: null,
    },
    appVersion: {
      type: String,
    },
    isActive: {
      type: Boolean,
      default: true,
    },
    invoiceCounter: {
      type: Number,
      default: 0,
    },
    settings: {
      timezone: {
        type: String,
        default: "Asia/Kolkata",
      },
      currency: {
        type: String,
        default: "INR",
      },
      orderProcessCutoff: {
        type: String,
        default: "10:00",
      },
      autoGenerateInvoice: {
        type: Boolean,
        default: false,
      },
      whatsappEnabled: {
        type: Boolean,
        default: true,
      },
      emailEnabled: {
        type: Boolean,
        default: false,
      },
      notifyCustomerOnProcess: {
        type: Boolean,
        default: true,
      },
      notifyCustomerOnDelivery: {
        type: Boolean,
        default: true,
      },
      allowNegativeBalance: {
        type: Boolean,
        default: false,
      },
      lowBalanceThreshold: {
        type: Number,
        default: 100,
      },
      /** Shown to customers on the portal (e.g. imeals.in). */
      portalAnnouncementText: {
        type: String,
        trim: true,
        default: "",
        maxlength: 5000,
      },
      portalAnnouncementUpdatedAt: {
        type: Date,
        default: null,
      },
    },
    lastLoginAt: {
      type: Date,
    },

    // Password support (added during week‑1 upgrade)
    passwordHash: {
      type: String,
    },

    // track login events (used for analytics/security)
    loginHistory: [
      {
        ip: String,
        userAgent: String,
        at: {
          type: Date,
          default: Date.now,
        },
      },
    ],

    truecallerId: {
      type: String,
      unique: true,
      sparse: true,
    },

    name: {
      type: String,
      trim: true,
    },
    role: {
      type: String,
      enum: ["admin", "vendor", "customer", "delivery_staff"],
      default: "vendor",
    },
  },
  {
    timestamps: true,
  }
);

const User = mongoose.model("User", userSchema);

export default User;
