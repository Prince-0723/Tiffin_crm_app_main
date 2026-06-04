import mongoose from "mongoose";

const rawMaterialSchema = new mongoose.Schema(
  {
    ownerId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    name: {
      type: String,
      required: true,
    },
    unit: {
      type: String,
      enum: ["kg", "g", "litre", "ml", "piece", "packet", "bunch"],
    },
    currentStock: {
      type: Number,
      default: 0,
    },
    minimumStock: {
      type: Number,
      default: 0,
    },
    costPerUnit: {
      type: Number,
      default: 0,
    },
    category: {
      type: String,
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

const RawMaterial = mongoose.model("RawMaterial", rawMaterialSchema);

export default RawMaterial;

