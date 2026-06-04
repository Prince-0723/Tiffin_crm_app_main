import mongoose from "mongoose";
import Customer from "../models/Customer.model.js";
import TiffinLedger from "../models/TiffinLedger.model.js";
import { asyncHandler } from "../utils/asyncHandler.js";
import { ApiResponse } from "../class/apiResponseClass.js";
import { ApiError } from "../class/apiErrorClass.js";

const HISTORY_LIMIT = 50;

function assertValidCustomerId(id) {
  if (!mongoose.Types.ObjectId.isValid(id)) {
    throw new ApiError(400, "Invalid customer id");
  }
}

/**
 * GET /api/v1/vendor/customers/:customerId/tiffin
 * Query: history=true — include recent ledger entries (newest first).
 */
export const getCustomerTiffin = asyncHandler(async (req, res) => {
  const ownerId = req.user.userId;
  const { customerId } = req.params;
  assertValidCustomerId(customerId);

  const customer = await Customer.findOne({
    _id: customerId,
    ownerId,
    isDeleted: { $ne: true },
  })
    .select("tiffinCount")
    .lean();

  if (!customer) {
    throw new ApiError(404, "Customer not found");
  }

  const tiffinCount = customer.tiffinCount ?? 0;
  const payload = { tiffinCount };

  const wantHistory =
    String(req.query.history || "").toLowerCase() === "true" ||
    String(req.query.history || "") === "1";

  if (wantHistory) {
    const history = await TiffinLedger.find({ customerId, ownerId })
      .sort({ createdAt: -1 })
      .limit(HISTORY_LIMIT)
      .select("action countAfter createdAt")
      .lean();
    payload.history = history;
  }

  const response = new ApiResponse(200, "Tiffin count fetched", payload);
  res.status(response.statusCode).json({
    success: response.success,
    message: response.message,
    data: response.data,
  });
});

/**
 * PATCH /api/v1/vendor/customers/:customerId/tiffin/increment
 */
export const incrementCustomerTiffin = asyncHandler(async (req, res) => {
  const ownerId = req.user.userId;
  const { customerId } = req.params;
  assertValidCustomerId(customerId);

  const session = await mongoose.startSession();
  session.startTransaction();

  try {
    const updated = await Customer.findOneAndUpdate(
      {
        _id: customerId,
        ownerId,
        isDeleted: { $ne: true },
      },
      { $inc: { tiffinCount: 1 } },
      { new: true, session }
    )
      .select("tiffinCount")
      .lean();

    if (!updated) {
      throw new ApiError(404, "Customer not found");
    }

    const tiffinCount = updated.tiffinCount ?? 0;

    await TiffinLedger.create(
      [
        {
          ownerId,
          customerId,
          action: "increment",
          countAfter: tiffinCount,
        },
      ],
      { session }
    );

    await session.commitTransaction();

    const response = new ApiResponse(200, "Tiffin count increased", {
      tiffinCount,
    });
    res.status(response.statusCode).json({
      success: response.success,
      message: response.message,
      data: response.data,
    });
  } catch (err) {
    if (session.inTransaction()) {
      await session.abortTransaction();
    }
    throw err;
  } finally {
    session.endSession();
  }
});

/**
 * PATCH /api/v1/vendor/customers/:customerId/tiffin/decrement
 */
export const decrementCustomerTiffin = asyncHandler(async (req, res) => {
  const ownerId = req.user.userId;
  const { customerId } = req.params;
  assertValidCustomerId(customerId);

  const session = await mongoose.startSession();
  session.startTransaction();

  try {
    const updated = await Customer.findOneAndUpdate(
      {
        _id: customerId,
        ownerId,
        isDeleted: { $ne: true },
        tiffinCount: { $gt: 0 },
      },
      { $inc: { tiffinCount: -1 } },
      { new: true, session }
    )
      .select("tiffinCount")
      .lean();

    if (!updated) {
      const exists = await Customer.findOne({
        _id: customerId,
        ownerId,
        isDeleted: { $ne: true },
      })
        .select("_id")
        .session(session)
        .lean();

      if (!exists) {
        throw new ApiError(404, "Customer not found");
      }

      throw new ApiError(400, "Tiffin count is already zero");
    }

    const tiffinCount = updated.tiffinCount ?? 0;

    await TiffinLedger.create(
      [
        {
          ownerId,
          customerId,
          action: "decrement",
          countAfter: tiffinCount,
        },
      ],
      { session }
    );

    await session.commitTransaction();

    const response = new ApiResponse(200, "Tiffin count decreased", {
      tiffinCount,
    });
    res.status(response.statusCode).json({
      success: response.success,
      message: response.message,
      data: response.data,
    });
  } catch (err) {
    if (session.inTransaction()) {
      await session.abortTransaction();
    }
    throw err;
  } finally {
    session.endSession();
  }
});
