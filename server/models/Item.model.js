import mongoose from "mongoose";

const itemSchema = new mongoose.Schema(
  {
    ownerId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    name: {
      type: String,
      required: true,
      trim: true,
    },
    unitPrice: {
      type: Number,
      required: false,
    },
    unit: {
      type: String,
      enum: ["piece", "bowl", "plate", "glass", "other"],
      default: "piece",
    },
    category: {
      type: String,
      trim: true,
      default: "",
    },
    /** Vegetarian vs non-vegetarian — used for order filtering and kitchen prep. */
    dietType: {
      type: String,
      enum: ["veg", "non_veg"],
      default: "veg",
    },
    isActive: {
      type: Boolean,
      default: true,
    },
  },
  {
    timestamps: true,
  }
);

itemSchema.index({ ownerId: 1, isActive: 1 });
itemSchema.index({ ownerId: 1, name: 1 });

const Item = mongoose.model("Item", itemSchema);

export default Item;
