import mongoose from "mongoose";

const INCOME_PAYMENT_METHODS = ["cash", "upi", "bank_transfer", "card"];

const incomeSchema = new mongoose.Schema(
  {
    ownerId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },
    source: {
      type: String,
      required: true,
      trim: true,
    },
    amount: {
      type: Number,
      required: true,
      min: 0,
    },
    date: {
      type: Date,
      required: true,
    },
    notes: {
      type: String,
      trim: true,
    },
    paymentMethod: {
      type: String,
      enum: INCOME_PAYMENT_METHODS,
    },
    referenceId: {
      type: String,
      trim: true,
    },
  },
  {
    timestamps: true,
  }
);

incomeSchema.index({ ownerId: 1, date: -1 });

const Income = mongoose.model("Income", incomeSchema);

export default Income;
export { INCOME_PAYMENT_METHODS };
