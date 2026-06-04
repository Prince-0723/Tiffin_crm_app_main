import Joi from "joi";
import DailyOrder from "../models/DailyOrder.model.js";
import { asyncHandler } from "../utils/asyncHandler.js";
import { ApiResponse } from "../class/apiResponseClass.js";
import { ApiError } from "../class/apiErrorClass.js";
import { applyMealDietToFilter } from "../services/dailyOrder.service.js";

const deliveryOrdersQuerySchema = Joi.object({
  mealPeriod: Joi.string()
    .valid("breakfast", "lunch", "dinner", "snack")
    .optional(),
  dietType: Joi.string().valid("veg", "non_veg", "mixed").optional(),
});

const parseUTC = (d) => {
  const date = new Date(d);
  date.setUTCHours(0, 0, 0, 0);
  return date;
};

/**
 * GET /api/v1/delivery/my-deliveries
 * Delivery staff sees their assigned orders for today.
 * Sorted by area for efficient routing.
 */
export const getMyDeliveries = asyncHandler(async (req, res) => {
  const staffId = req.user.staffId;
  if (!staffId) {
    throw new ApiError(
      403,
      "Staff ID not found in token. Please log out and log in again."
    );
  }

  const { error, value } = deliveryOrdersQuerySchema.validate(req.query, {
    stripUnknown: true,
    abortEarly: false,
  });
  if (error) {
    throw new ApiError(400, error.details.map((d) => d.message).join("; "));
  }

  const today = parseUTC(new Date());

  const filter = {
    deliveryStaffId: staffId,
    orderDate: today,
    status: { $nin: ["cancelled", "failed", "skipped"] },
  };
  applyMealDietToFilter(filter, value);

  const orders = await DailyOrder.find(filter)
    .populate(
      "customerId",
      "name phone address area landmark location fcmToken"
    )
    .populate("planId", "planName price")
    .populate("resolvedItems.itemId", "name unitPrice unit dietType")
    .sort({ "customerId.area": 1 })
    .lean();

  // Add WhatsApp URL for each customer (click to open chat)
  const enriched = orders.map((order) => {
    const customer = order.customerId;
    const phone = customer?.phone;
    return {
      ...order,
      customerId: customer
        ? {
            ...customer,
            whatsappUrl: phone
              ? `https://wa.me/91${phone.replace(/^\+?91/, "")}`
              : null,
          }
        : null,
    };
  });

  res.status(200).json(
    new ApiResponse(200, "My deliveries fetched", {
      data: enriched,
      total: enriched.length,
      date: today.toISOString().slice(0, 10),
      filters: {
        mealPeriod: value.mealPeriod ?? null,
        dietType: value.dietType ?? null,
      },
    })
  );
});
