import mongoose from "mongoose";

const dailyMenuSchema = new mongoose.Schema(
  {
    ownerId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    date: {
      type: Date,
      required: true,
    },
    mealTime: {
      type: String,
      enum: ["breakfast", "lunch", "dinner"],
    },
    items: [
      {
        placeholder: String,
        actualName: String,
        quantity: Number,
      },
    ],
    notes: {
      type: String,
    },
  },
  {
    timestamps: true,
  }
);

dailyMenuSchema.index({ ownerId: 1, date: 1, mealTime: 1 }, { unique: true });

const DailyMenu = mongoose.model("DailyMenu", dailyMenuSchema);

export default DailyMenu;

