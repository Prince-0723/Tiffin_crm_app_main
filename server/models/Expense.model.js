import mongoose from "mongoose";

const EXPENSE_CATEGORIES = [
  "food",
  "transport",
  "salary",
  "rent",
  "utilities",
  "marketing",
  "equipment",
  "maintenance",
  "misc",
];

const EXPENSE_PAYMENT_METHODS = ["cash", "upi", "bank_transfer", "card"];

const expenseSchema = new mongoose.Schema(
  {
    ownerId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },
    title: {
      type: String,
      required: true,
      trim: true,
    },
    amount: {
      type: Number,
      required: true,
      min: 0,
    },
    category: {
      type: String,
      enum: EXPENSE_CATEGORIES,
      required: true,
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
      enum: EXPENSE_PAYMENT_METHODS,
    },
    tags: {
      type: [String],
      default: [],
    },
    attachmentUrl: {
      type: String,
    },
  },
  {
    timestamps: true,
  }
);

expenseSchema.index({ ownerId: 1, date: -1 });
expenseSchema.index({ ownerId: 1, category: 1 });

const Expense = mongoose.model("Expense", expenseSchema);

export default Expense;
export { EXPENSE_CATEGORIES, EXPENSE_PAYMENT_METHODS };
