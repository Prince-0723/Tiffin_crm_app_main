import mongoose from "mongoose";

const TiffinLedgerSchema = new mongoose.Schema(
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
    action: {
      type: String,
      enum: ["increment", "decrement"],
      required: true,
    },
    /** Customer's tiffin count immediately after this action. */
    countAfter: {
      type: Number,
      required: true,
      min: 0,
    },
  },
  { timestamps: true }
);

TiffinLedgerSchema.index({ customerId: 1, createdAt: -1 });

const TiffinLedger = mongoose.model("TiffinLedger", TiffinLedgerSchema);

export default TiffinLedger;
