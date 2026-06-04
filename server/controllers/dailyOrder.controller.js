import Joi from "joi";
import mongoose from "mongoose";
import DailyOrder from "../models/DailyOrder.model.js";
import Subscription from "../models/Subscription.model.js";
import Customer from "../models/Customer.model.js";
import User from "../models/User.model.js";
import DeliveryStaff from "../models/DeliveryStaff.model.js";
import Transaction from "../models/Transaction.model.js";
import { asyncHandler } from "../utils/asyncHandler.js";
import { ApiResponse } from "../class/apiResponseClass.js";
import { ApiError } from "../class/apiErrorClass.js";
import { readSpendableWalletFromDb } from "../utils/customerWallet.js";
import { sendToToken } from "../services/notification.service.js";
import {
  getTodayDailyOrders,
  generateDailyOrdersForDate,
  generateOrdersForNextDays,
} from "../services/dailyOrder.service.js";
import { sendNotification } from "../services/inAppNotification.service.js";
import { NOTIFICATION_TYPES } from "../utils/notificationTypes.js";
import {
  buildDeliveredDescription,
  orderDeliveredLineItems,
  planNamesByIds,
} from "../utils/deliveryLedger.js";
import { assertPayLaterAllowsConsumption } from "../utils/subscriptionPayLater.js";

function emitVendorDailyOrdersChanged(req, ownerId, data = {}) {
  const io = req.app.get("io");
  if (!io) return;
  io.of("/delivery")
    .to(`admin:${String(ownerId)}`)
    .emit("daily_orders_changed", data);
}

const todayOrdersQuerySchema = Joi.object({
  mealPeriod: Joi.string()
    .valid("breakfast", "lunch", "dinner", "snack")
    .optional()
    .messages({
      "any.only": "mealPeriod must be one of: breakfast, lunch, dinner, snack",
    }),
  dietType: Joi.string().valid("veg", "non_veg", "mixed").optional().messages({
    "any.only": "dietType must be one of: veg, non_veg, mixed",
  }),
});

const parseUTC = (d) => {
  const [y, m, day] = d.split("-").map(Number);
  return new Date(Date.UTC(y, m - 1, day));
};

/**
 * Valid forward-only status transitions for an order.
 * `processing` is vendor/admin only (see updateOrderStatus).
 */
const VALID_TRANSITIONS = {
  processing: ["pending"],
  out_for_delivery: ["pending", "processing"],
  delivered: ["pending", "processing", "out_for_delivery"],
};

/**
 * Deduct order.amount from Subscription.remainingBalance within the given session.
 * Returns { newSubscriptionBalance, deducted, walletDeducted } or throws ApiError on insufficient funds.
 */
const deductBalanceForOrder = async (
  order,
  _vendorSettings,
  session,
  ownerId
) => {
  const orderAmount = order.amount || 0;
  if (orderAmount <= 0) {
    return { newSubscriptionBalance: null, deducted: 0, walletDeducted: 0 };
  }

  // Some orders can be wallet-paid (no/expired subscription, migrated data, etc.).
  // In that case, allow delivery using wallet balance.
  if (!order.customerId) {
    throw new ApiError(400, "Order has no customer for deduction");
  }

  const spendableWallet = await readSpendableWalletFromDb(
    Customer,
    order.customerId,
    ownerId ?? order.ownerId
  );

  if (!order.subscriptionId) {
    if (spendableWallet < orderAmount) {
      throw new ApiError(
        400,
        `Insufficient wallet balance. Available: ₹${spendableWallet}, Required: ₹${orderAmount}`
      );
    }
    return {
      newSubscriptionBalance: null,
      deducted: orderAmount,
      walletDeducted: orderAmount,
    };
  }

  const subscription = await Subscription.findById(
    order.subscriptionId
  ).session(session);

  // If the linked subscription no longer exists, fall back to wallet.
  if (!subscription) {
    if (spendableWallet < orderAmount) {
      throw new ApiError(
        400,
        `Insufficient wallet balance. Available: ₹${spendableWallet}, Required: ₹${orderAmount}`
      );
    }
    return {
      newSubscriptionBalance: null,
      deducted: orderAmount,
      walletDeducted: orderAmount,
    };
  }

  const rawCurrent = Number(
    subscription.remainingBalance ?? subscription.totalAmount ?? 0
  );
  const current = Math.max(0, rawCurrent);
  const newSubscriptionBalance = current - orderAmount;

  // If subscription is insufficient but wallet can cover, allow delivery and only debit wallet.
  if (newSubscriptionBalance < 0) {
    if (spendableWallet < orderAmount) {
      throw new ApiError(
        400,
        `Insufficient subscription balance. Available: ₹${current}, Required: ₹${orderAmount}`
      );
    }
    return {
      newSubscriptionBalance: null,
      deducted: orderAmount,
      walletDeducted: orderAmount,
    };
  }

  let walletDeducted = 0;
  if (subscription.payLater === true) {
    walletDeducted = Math.min(Math.max(0, spendableWallet), orderAmount);
    const unpaidAmount = Math.max(0, orderAmount - walletDeducted);
    assertPayLaterAllowsConsumption(subscription, unpaidAmount);
  }

  const subscriptionInc = { remainingBalance: -orderAmount };
  if (walletDeducted > 0) {
    subscriptionInc.paidAmount = walletDeducted;
  }

  await Subscription.findByIdAndUpdate(
    subscription._id,
    { $inc: subscriptionInc },
    { session }
  );

  return { newSubscriptionBalance, deducted: orderAmount, walletDeducted };
};

/**
 * GET /api/v1/daily-orders/today
 */
export const getToday = asyncHandler(async (req, res) => {
  const ownerId = req.user.userId;

  const { error, value } = todayOrdersQuerySchema.validate(req.query, {
    stripUnknown: true,
    abortEarly: false,
  });
  if (error) {
    throw new ApiError(400, error.details.map((d) => d.message).join("; "));
  }

  const orders = await getTodayDailyOrders(ownerId, value);

  res.status(200).json(
    new ApiResponse(200, "Today's orders fetched", {
      data: orders,
      total: orders.length,
      filters: {
        mealPeriod: value.mealPeriod ?? null,
        dietType: value.dietType ?? null,
      },
    })
  );
});

/**
 * POST /api/v1/daily-orders/process
 * Moves all pending orders to processing, notifies customers.
 */
export const processToday = asyncHandler(async (req, res) => {
  const ownerId = req.user.userId;
  const { date } = req.body;

  const targetDate = date
    ? parseUTC(date)
    : parseUTC(new Date().toISOString().slice(0, 10));

  const result = await DailyOrder.updateMany(
    { ownerId, orderDate: targetDate, status: "pending" },
    { $set: { status: "processing", processedAt: new Date() } }
  );

  const processedCount = result.modifiedCount || 0;

  if (processedCount > 0) {
    const orders = await DailyOrder.find({
      ownerId,
      orderDate: targetDate,
      status: "processing",
    })
      .select("customerId")
      .lean();

    const customerIds = [
      ...new Set(orders.map((o) => o.customerId.toString())),
    ];

    // Create in-app Notification doc + send FCM for each unique customer
    await Promise.all(
      customerIds.map((cid) =>
        sendNotification({
          customerId: cid,
          ownerId,
          type: NOTIFICATION_TYPES.ORDER_PROCESSING,
          title: "Tiffin Ready 🍱",
          message: "Your tiffin is ready!",
          data: { screen: "orderDetail", status: "processing" },
        })
      )
    );
  }

  const io = req.app.get("io");
  if (io) {
    io.of("/delivery")
      .to(`admin:${ownerId}`)
      .emit("orders_processed", {
        count: processedCount,
        date: targetDate.toISOString().slice(0, 10),
      });
  }

  res
    .status(200)
    .json(new ApiResponse(200, "Orders processed", { processedCount }));
});

const cancelVendorHolidaySchema = Joi.object({
  date: Joi.string()
    .pattern(/^\d{4}-\d{2}-\d{2}$/)
    .optional()
    .messages({
      "string.pattern.base": "date must be YYYY-MM-DD",
    }),
});

/**
 * POST /api/v1/daily-orders/cancel-vendor-holiday
 * Vendor: cancel all daily orders for a calendar day (default: today UTC).
 * Only affects orders not yet delivered — wallet/subscription are charged on "delivered",
 * so cancelling here does not deduct that day's meal balance.
 */
export const cancelVendorHoliday = asyncHandler(async (req, res) => {
  const { error, value } = cancelVendorHolidaySchema.validate(req.body ?? {}, {
    stripUnknown: true,
    abortEarly: false,
  });
  if (error) {
    throw new ApiError(400, error.details.map((d) => d.message).join("; "));
  }

  const ownerId = req.user.userId;
  const targetDate = value.date
    ? parseUTC(value.date)
    : parseUTC(new Date().toISOString().slice(0, 10));

  const result = await DailyOrder.updateMany(
    {
      ownerId,
      orderDate: targetDate,
      status: { $nin: ["delivered", "cancelled", "failed", "skipped"] },
    },
    {
      $set: {
        status: "cancelled",
        cancelledBy: "owner",
        cancellationReason: "vendor_holiday",
        cancelledAt: new Date(),
        deliveryStaffId: null,
        acceptedAt: null,
        outForDeliveryAt: null,
      },
    }
  );

  const cancelledCount = result.modifiedCount || 0;

  const io = req.app.get("io");
  if (io) {
    io.of("/delivery")
      .to(`admin:${ownerId}`)
      .emit("orders_processed", {
        count: cancelledCount,
        date: targetDate.toISOString().slice(0, 10),
        reason: "vendor_holiday",
      });
  }
  emitVendorDailyOrdersChanged(req, ownerId, {
    date: targetDate.toISOString().slice(0, 10),
    reason: "vendor_holiday",
  });

  res.status(200).json(
    new ApiResponse(200, "Holiday cancellations applied", {
      cancelledCount,
      date: targetDate.toISOString().slice(0, 10),
    })
  );
});

/**
 * Applies a validated forward status transition. Mutates and saves [order].
 * Caller must verify transition is allowed for the current [order.status].
 * @returns {{ message: string, data: object }}
 */
async function applyDailyOrderStatusCore(req, order, status) {
  const role = req.user.role;
  const ownerId = req.user.ownerId || req.user.userId;
  const orderIdStr = order._id.toString();

  if (status === "processing") {
    if (role === "delivery_staff") {
      throw new ApiError(
        403,
        "Delivery staff cannot mark an order as processing"
      );
    }
    order.status = "processing";
    order.processedAt = new Date();
    await order.save();

    await sendNotification({
      customerId: order.customerId,
      ownerId,
      type: NOTIFICATION_TYPES.ORDER_PROCESSING,
      title: "Tiffin Ready 🍱",
      message: "Your tiffin is ready!",
      data: {
        screen: "orderDetail",
        status: "processing",
        orderId: orderIdStr,
      },
    });

    const io = req.app.get("io");
    if (io && order.orderDate) {
      const d =
        order.orderDate instanceof Date
          ? order.orderDate
          : new Date(order.orderDate);
      io.of("/delivery")
        .to(`admin:${ownerId}`)
        .emit("orders_processed", {
          count: 1,
          date: d.toISOString().slice(0, 10),
        });
    }

    return {
      message: "Order marked as processing",
      data: { order },
    };
  }

  const vendorAlertUserIds = [
    ...new Set([
      String(ownerId),
      ...(role === "delivery_staff" &&
      req.user.userId &&
      String(req.user.userId) !== String(ownerId)
        ? [String(req.user.userId)]
        : []),
    ]),
  ];

  if (status === "out_for_delivery") {
    order.status = "out_for_delivery";
    order.outForDeliveryAt = new Date();
    await order.save();

    await Promise.all([
      sendNotification({
        customerId: order.customerId,
        ownerId,
        type: NOTIFICATION_TYPES.OUT_FOR_DELIVERY,
        title: "Out for delivery! 🛵",
        message: "Your tiffin is on the way",
        data: { orderId: orderIdStr, status: "out_for_delivery" },
      }),
      ...vendorAlertUserIds.map((userId) =>
        sendNotification({
          userId,
          ownerId,
          type: NOTIFICATION_TYPES.OUT_FOR_DELIVERY,
          title: "Order out for delivery",
          message: "An order is out for delivery",
          data: {
            orderId: orderIdStr,
            customerId: order.customerId.toString(),
            status: "out_for_delivery",
          },
        })
      ),
    ]);

    return {
      message: "Order marked out for delivery",
      data: { order },
    };
  }

  const vendor = await User.findById(ownerId).select("settings").lean();

  const session = await mongoose.startSession();
  session.startTransaction();

  try {
    const { newSubscriptionBalance, deducted, walletDeducted } =
      await deductBalanceForOrder(order, vendor?.settings, session, ownerId);

    if (deducted > 0) {
      if (walletDeducted > 0) {
        await Customer.findByIdAndUpdate(
          order.customerId,
          { $inc: { walletBalance: -walletDeducted, balance: -walletDeducted } },
          { session }
        );
      }

      const planMap = await planNamesByIds([order.planId]);
      const planLabel = planMap[order.planId?.toString()] || "Meal plan";
      const description = buildDeliveredDescription({
        planName: planLabel,
        mealType: order.mealType,
        orderDate: order.orderDate,
      });
      const items = orderDeliveredLineItems(order);

      await Transaction.create(
        [
          {
            ownerId,
            customerId: order.customerId,
            date: new Date(),
            description,
            amount: deducted,
            type: "debit",
            paymentMode: "wallet",
            source: "order_delivered",
            items,
          },
        ],
        { session }
      );
    }

    order.status = "delivered";
    order.deliveredAt = new Date();
    await order.save({ session });

    await session.commitTransaction();
    session.endSession();

    const balanceMsg =
      newSubscriptionBalance !== null
        ? ` Subscription balance: ₹${newSubscriptionBalance}`
        : "";

    await Promise.all([
      sendNotification({
        customerId: order.customerId,
        ownerId,
        type: NOTIFICATION_TYPES.DELIVERED,
        title: "Order Delivered 🛵",
        message: `Your tiffin has been delivered!${balanceMsg}`,
        data: {
          orderId: orderIdStr,
          status: "delivered",
          newSubscriptionBalance,
        },
      }),
      ...vendorAlertUserIds.map((userId) =>
        sendNotification({
          userId,
          ownerId,
          type: NOTIFICATION_TYPES.DELIVERED,
          title: "Order delivered",
          message: "An order has been successfully delivered",
          data: {
            orderId: orderIdStr,
            customerId: order.customerId.toString(),
            status: "delivered",
          },
        })
      ),
    ]);

    if (newSubscriptionBalance !== null && newSubscriptionBalance < 100) {
      const customerDoc = await Customer.findById(order.customerId)
        .select("name")
        .lean();
      await Promise.all([
        sendNotification({
          customerId: order.customerId,
          ownerId,
          type: NOTIFICATION_TYPES.LOW_BALANCE,
          title: "Low subscription balance ⚠️",
          message: `₹${newSubscriptionBalance.toFixed(2)} subscription balance remaining.`,
          data: { balance: newSubscriptionBalance, screen: "wallet" },
        }),
        ...vendorAlertUserIds.map((userId) =>
          sendNotification({
            userId,
            ownerId,
            type: NOTIFICATION_TYPES.LOW_BALANCE,
            title: "Customer subscription balance low",
            message: `${customerDoc?.name || "A customer"} has low subscription balance (₹${newSubscriptionBalance.toFixed(2)})`,
            data: {
              customerId: order.customerId.toString(),
              balance: newSubscriptionBalance,
            },
          })
        ),
      ]);
    }

    emitVendorDailyOrdersChanged(req, ownerId, {
      orderId: orderIdStr,
      status: "delivered",
    });

    return {
      message: "Order marked delivered",
      data: {
        order,
        balanceDeducted: deducted,
        customerNewBalance: newSubscriptionBalance,
      },
    };
  } catch (err) {
    if (session.inTransaction()) {
      await session.abortTransaction();
    }
    session.endSession();
    throw err;
  }
}

/**
 * PATCH /api/v1/daily-orders/:id/status
 * Body: { status: 'processing' | 'out_for_delivery' | 'delivered' }
 *
 * Drives the order lifecycle:
 *   pending → processing  (vendor/admin; notifies customer — same as bulk process)
 *   pending/processing → out_for_delivery  (notifies customer + vendor)
 *   pending/processing/out_for_delivery → delivered  (deducts balance + notifies)
 *
 * Vendor can update any of their orders.
 * Delivery staff: only out_for_delivery / delivered on assigned orders (not processing).
 */
export const updateOrderStatus = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { status } = req.body;

  if (!status || !VALID_TRANSITIONS[status]) {
    throw new ApiError(
      400,
      `status must be one of: ${Object.keys(VALID_TRANSITIONS).join(", ")}`
    );
  }

  const role = req.user.role;
  const ownerId = req.user.ownerId || req.user.userId;

  // Delivery staff can only update orders assigned to them
  const orderFilter = { _id: id, ownerId };
  const order = await DailyOrder.findOne(orderFilter);
  if (!order) throw new ApiError(404, "Order not found");

  console.log("[FCM DEBUG] updateOrderStatus", {
    orderId: id,
    requestedStatus: status,
    role,
    ownerId: String(ownerId),
    jwtUserId: String(req.user.userId),
    customerId: order.customerId?.toString?.(),
    orderStatus: order.status,
  });

  if (role === "delivery_staff") {
    const staffId = req.user.staffId;
    if (
      !order.deliveryStaffId ||
      order.deliveryStaffId.toString() !== staffId
    ) {
      throw new ApiError(403, "This order is not assigned to you");
    }
  }

  // Idempotent — already in target status
  if (order.status === status) {
    return res
      .status(200)
      .json(new ApiResponse(200, "Order already in this status", { order }));
  }

  if (!VALID_TRANSITIONS[status].includes(order.status)) {
    throw new ApiError(
      400,
      `Cannot move order from "${order.status}" to "${status}"`
    );
  }

  const result = await applyDailyOrderStatusCore(req, order, status);

  return res
    .status(200)
    .json(new ApiResponse(200, result.message, result.data));
});

/**
 * POST /api/v1/daily-orders/mark-delivered
 * Legacy bulk endpoint — marks all matching orders as delivered and deducts subscription balance.
 * Prefer PATCH /:id/status for single-order flow (used by delivery boy).
 */
export const markDelivered = asyncHandler(async (req, res) => {
  const ownerId = req.user.userId;
  const { orderDate, customerId } = req.body;

  if (!orderDate) throw new ApiError(400, "orderDate is required");

  const date = parseUTC(orderDate);

  const filter = {
    ownerId,
    orderDate: date,
    status: { $in: ["pending", "processing", "out_for_delivery"] },
  };
  if (customerId) filter.customerId = customerId;

  const orders = await DailyOrder.find(filter)
    .select(
      "_id customerId subscriptionId amount status planId mealType orderDate resolvedItems"
    )
    .lean();

  if (!orders.length) {
    return res
      .status(200)
      .json(
        new ApiResponse(200, "No orders to deliver", { deliveredCount: 0 })
      );
  }

  const session = await mongoose.startSession();
  session.startTransaction();

  // Track new balances per subscription to fire low-balance alerts after commit
  const newBalanceMap = {};

  try {
    // Update all orders to delivered
    await DailyOrder.updateMany(
      { _id: { $in: orders.map((o) => o._id) } },
      { $set: { status: "delivered", deliveredAt: new Date() } },
      { session }
    );

    const planNameMap = await planNamesByIds(orders.map((o) => o.planId));

    // Record debit ledger entries per delivered order for customer history.
    const debitDocs = orders
      .filter((o) => (o.amount || 0) > 0 && o.customerId)
      .map((o) => ({
        ownerId,
        customerId: o.customerId,
        date: new Date(),
        description: buildDeliveredDescription({
          planName: planNameMap[o.planId?.toString()] || "Meal plan",
          mealType: o.mealType,
          orderDate: o.orderDate,
        }),
        amount: Number(o.amount) || 0,
        type: "debit",
        paymentMode: "wallet",
        source: "order_delivered",
        items: orderDeliveredLineItems(o),
      }));
    if (debitDocs.length) {
      await Transaction.create(debitDocs, { session, ordered: true });
    }

    for (const order of orders) {
      const { newSubscriptionBalance, walletDeducted } =
        await deductBalanceForOrder(order, null, session, ownerId);

      if (walletDeducted > 0) {
        await Customer.findByIdAndUpdate(
          order.customerId,
          { $inc: { walletBalance: -walletDeducted, balance: -walletDeducted } },
          { session }
        );
      }

      if (order.subscriptionId && newSubscriptionBalance != null) {
        newBalanceMap[order.subscriptionId.toString()] = {
          newBalance: newSubscriptionBalance,
        };
      }
    }

    await session.commitTransaction();
    session.endSession();
  } catch (err) {
    await session.abortTransaction();
    session.endSession();
    throw err;
  }

  const threshold = 100;

  // Send delivery + low-balance notifications after transaction
  await Promise.all(
    orders.map((order) =>
      sendNotification({
        customerId: order.customerId,
        ownerId,
        type: NOTIFICATION_TYPES.DELIVERED,
        title: "Order Delivered 🛵",
        message: "Your tiffin has been delivered!",
        data: { orderId: order._id.toString(), status: "delivered" },
      })
    )
  );

  // Low balance alerts for subscriptions whose balance dropped below threshold
  const lowBalanceCustomers = Object.entries(newBalanceMap).filter(
    ([, { newBalance }]) => newBalance < threshold
  );

  await Promise.all(
    lowBalanceCustomers.flatMap(([sid, { newBalance }]) => [
      sendNotification({
        customerId: orders.find((o) => o.subscriptionId?.toString() === sid)
          ?.customerId,
        ownerId,
        type: NOTIFICATION_TYPES.LOW_BALANCE,
        title: "Low subscription balance ⚠️",
        message: `₹${newBalance.toFixed(2)} subscription balance remaining.`,
        data: { balance: newBalance, screen: "wallet" },
      }),
      sendNotification({
        userId: ownerId,
        type: NOTIFICATION_TYPES.LOW_BALANCE,
        title: "Subscription low balance",
        message: `Subscription ${sid} has low balance (₹${newBalance.toFixed(2)})`,
        data: { subscriptionId: sid, balance: newBalance },
      }),
    ])
  );

  emitVendorDailyOrdersChanged(req, ownerId, {
    date: date.toISOString().slice(0, 10),
    deliveredCount: orders.length,
  });

  res.status(200).json(
    new ApiResponse(200, "Orders marked as delivered", {
      deliveredCount: orders.length,
      date: date.toISOString().slice(0, 10),
    })
  );
});

/**
 * POST /api/v1/daily-orders/generate
 */
export const generateOrders = asyncHandler(async (req, res) => {
  const ownerId = req.user.userId;
  const { date } = req.body;

  if (!date) throw new ApiError(400, "date is required (YYYY-MM-DD)");

  const targetDate = parseUTC(date);
  const { generatedCount, existingCount, skippedCreditLimit } =
    await generateDailyOrdersForDate(ownerId, targetDate);

  res.status(200).json(
    new ApiResponse(200, "Orders generated", {
      generatedCount,
      existingCount,
      skippedCreditLimit,
      date,
    })
  );
});

/**
 * POST /api/v1/daily-orders/generate-week
 */
export const generateNextWeekOrders = asyncHandler(async (req, res) => {
  const ownerId = req.user.userId;
  const results = await generateOrdersForNextDays(ownerId, 7);

  res
    .status(200)
    .json(
      new ApiResponse(200, "Orders generated for next 7 days", { results })
    );
});

/**
 * DEBUG: list all subscriptions for this vendor
 */
export const debugSubscriptions = asyncHandler(async (req, res) => {
  const ownerId = req.user.userId;

  const subs = await Subscription.find({ ownerId })
    .populate("customerId", "name phone")
    .populate("planId", "planName price")
    .lean();

  res.status(200).json(
    new ApiResponse(200, "Debug subscriptions", {
      data: subs,
      total: subs.length,
    })
  );
});

/**
 * DEBUG: fetch all orders for a subscription
 */
export const debugOrders = asyncHandler(async (req, res) => {
  const ownerId = req.user.userId;
  const { subscriptionId } = req.params;

  const orders = await DailyOrder.find({ ownerId, subscriptionId })
    .populate("customerId", "name phone")
    .populate("planId", "planName price")
    .sort({ orderDate: 1 })
    .lean();

  res.status(200).json(
    new ApiResponse(200, "Debug orders fetched", {
      data: orders,
      total: orders.length,
      TODAY: new Date().toISOString().slice(0, 10),
    })
  );
});

/**
 * PATCH /api/v1/daily-orders/:id/assign
 * Vendor assigns a delivery staff member to one order.
 * Body: { deliveryStaffId }
 */
export const assignDeliveryStaff = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { deliveryStaffId } = req.body;

  if (!deliveryStaffId || !mongoose.Types.ObjectId.isValid(deliveryStaffId)) {
    throw new ApiError(400, "deliveryStaffId is required");
  }

  const ownerId = req.user.userId;

  const [order, staff] = await Promise.all([
    DailyOrder.findOne({ _id: id, ownerId }),
    DeliveryStaff.findOne({ _id: deliveryStaffId, ownerId, isActive: true }),
  ]);

  if (!order) throw new ApiError(404, "Order not found");
  if (!staff) throw new ApiError(404, "Delivery staff not found or inactive");

  if (["delivered", "cancelled", "failed"].includes(order.status)) {
    throw new ApiError(
      400,
      `Cannot assign staff to an order with status "${order.status}"`
    );
  }

  order.deliveryStaffId = deliveryStaffId;
  await order.save();

  // Notify delivery staff — use linked userId (User.fcmToken) if available,
  // fall back to direct FCM to staff.fcmToken on DeliveryStaff record
  if (staff.userId) {
    await sendNotification({
      userId: staff.userId.toString(),
      type: NOTIFICATION_TYPES.TASK_ASSIGNED,
      title: "New delivery assigned 🛵",
      message: "You have a new delivery task today",
      data: { orderId: id, screen: "myDeliveries" },
    }).catch(() => {});
  } else if (staff.fcmToken) {
    await sendToToken(
      staff.fcmToken,
      "New delivery assigned 🛵",
      "You have a new delivery task today",
      { orderId: id, screen: "myDeliveries" }
    ).catch(() => {});
  }

  const updated = await DailyOrder.findById(id)
    .populate("customerId", "name phone address area")
    .populate("deliveryStaffId", "name phone")
    .lean();

  res
    .status(200)
    .json(new ApiResponse(200, "Delivery staff assigned", updated));
});

const BULK_STATUS_ALLOWED = ["processing", "out_for_delivery", "delivered"];

/**
 * POST /api/v1/daily-orders/bulk-status
 * Vendor/admin applies the same status transition to many orders (partial success).
 * Body: { orderIds: string[], status: 'processing' | 'out_for_delivery' | 'delivered' }
 */
export const bulkUpdateOrderStatus = asyncHandler(async (req, res) => {
  const { orderIds, status } = req.body || {};

  if (!Array.isArray(orderIds) || orderIds.length === 0) {
    throw new ApiError(400, "orderIds must be a non-empty array");
  }

  if (!status || !BULK_STATUS_ALLOWED.includes(status)) {
    throw new ApiError(
      400,
      `status must be one of: ${BULK_STATUS_ALLOWED.join(", ")}`
    );
  }

  const ownerId = req.user.ownerId || req.user.userId;
  const role = req.user.role;

  if (role !== "vendor" && role !== "admin") {
    throw new ApiError(403, "Only vendor or admin can use bulk status");
  }

  let updatedCount = 0;
  let skippedSameStatus = 0;
  let skippedInvalidTransition = 0;
  let notFoundCount = 0;
  const failures = [];

  const uniqueIds = [...new Set(orderIds.map((x) => String(x).trim()))];

  for (const rawId of uniqueIds) {
    if (!mongoose.Types.ObjectId.isValid(rawId)) {
      failures.push({ orderId: rawId, message: "Invalid order id" });
      continue;
    }

    try {
      const order = await DailyOrder.findOne({ _id: rawId, ownerId });
      if (!order) {
        notFoundCount += 1;
        continue;
      }

      if (order.status === status) {
        skippedSameStatus += 1;
        continue;
      }

      if (
        !VALID_TRANSITIONS[status] ||
        !VALID_TRANSITIONS[status].includes(order.status)
      ) {
        skippedInvalidTransition += 1;
        continue;
      }

      await applyDailyOrderStatusCore(req, order, status);
      updatedCount += 1;
    } catch (err) {
      const message =
        err instanceof ApiError
          ? err.message
          : err?.message
            ? String(err.message)
            : "Unknown error";
      failures.push({ orderId: rawId, message });
    }
  }

  const io = req.app.get("io");
  if (io && updatedCount > 0) {
    io.of("/delivery").to(`admin:${ownerId}`).emit("daily_orders_changed", {
      bulkStatus: status,
      updatedCount,
    });
  }

  res.status(200).json(
    new ApiResponse(200, "Bulk status update complete", {
      status,
      requestedCount: uniqueIds.length,
      updatedCount,
      skippedSameStatus,
      skippedInvalidTransition,
      notFoundCount,
      failures,
    })
  );
});

/**
 * POST /api/v1/daily-orders/assign-bulk
 * Vendor assigns one delivery staff to multiple orders.
 * Body: { orderIds: [], deliveryStaffId }
 */
export const assignBulk = asyncHandler(async (req, res) => {
  const { orderIds, deliveryStaffId } = req.body;

  if (!Array.isArray(orderIds) || orderIds.length === 0) {
    throw new ApiError(400, "orderIds must be a non-empty array");
  }
  if (!deliveryStaffId || !mongoose.Types.ObjectId.isValid(deliveryStaffId)) {
    throw new ApiError(400, "deliveryStaffId is required");
  }

  const ownerId = req.user.userId;

  const staff = await DeliveryStaff.findOne({
    _id: deliveryStaffId,
    ownerId,
    isActive: true,
  });
  if (!staff) throw new ApiError(404, "Delivery staff not found or inactive");

  const result = await DailyOrder.updateMany(
    {
      _id: { $in: orderIds },
      ownerId,
      status: { $nin: ["delivered", "cancelled", "failed"] },
    },
    { $set: { deliveryStaffId } }
  );

  // Notify delivery staff once for the batch
  if (result.modifiedCount > 0) {
    const msg = `You have ${result.modifiedCount} delivery task(s) today`;
    if (staff.userId) {
      await sendNotification({
        userId: staff.userId.toString(),
        type: NOTIFICATION_TYPES.TASK_ASSIGNED,
        title: "New deliveries assigned 🛵",
        message: msg,
        data: { screen: "myDeliveries", count: result.modifiedCount },
      }).catch(() => {});
    } else if (staff.fcmToken) {
      await sendToToken(staff.fcmToken, "New deliveries assigned 🛵", msg, {
        screen: "myDeliveries",
        count: result.modifiedCount,
      }).catch(() => {});
    }
  }

  res.status(200).json(
    new ApiResponse(200, "Bulk assignment complete", {
      assignedCount: result.modifiedCount,
      deliveryStaffId,
      staffName: staff.name,
    })
  );
});

/**
 * POST /api/v1/daily-orders/:id/accept
 * Delivery staff accepts their assigned task.
 */
export const acceptTask = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const staffId = req.user.staffId;
  const ownerId = req.user.ownerId;

  if (!staffId) throw new ApiError(403, "Staff ID not found in token");

  const order = await DailyOrder.findOne({ _id: id, ownerId })
    .populate("customerId", "name phone")
    .lean();

  if (!order) throw new ApiError(404, "Order not found");

  if (!order.deliveryStaffId || order.deliveryStaffId.toString() !== staffId) {
    throw new ApiError(403, "This order is not assigned to you");
  }

  if (["delivered", "cancelled", "failed"].includes(order.status)) {
    throw new ApiError(
      400,
      `Cannot accept an order with status "${order.status}"`
    );
  }

  await DailyOrder.findByIdAndUpdate(id, { $set: { acceptedAt: new Date() } });

  await sendNotification({
    userId: ownerId,
    type: NOTIFICATION_TYPES.TASK_ACCEPTED,
    title: "Delivery accepted ✅",
    message: `Delivery for ${order.customerId?.name || "customer"} was accepted`,
    data: { orderId: id, action: "accepted" },
  });

  res.status(200).json(new ApiResponse(200, "Task accepted", { orderId: id }));
});

/**
 * POST /api/v1/daily-orders/:id/reject
 * Delivery staff rejects their assigned task.
 * Body: { reason? }
 * Clears deliveryStaffId; resets status to 'processing'; notifies vendor.
 */
export const rejectTask = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { reason } = req.body || {};
  const staffId = req.user.staffId;
  const ownerId = req.user.ownerId;

  if (!staffId) throw new ApiError(403, "Staff ID not found in token");

  const order = await DailyOrder.findOne({ _id: id, ownerId })
    .populate("customerId", "name phone")
    .lean();

  if (!order) throw new ApiError(404, "Order not found");

  if (!order.deliveryStaffId || order.deliveryStaffId.toString() !== staffId) {
    throw new ApiError(403, "This order is not assigned to you");
  }

  if (["delivered", "cancelled", "failed"].includes(order.status)) {
    throw new ApiError(
      400,
      `Cannot reject an order with status "${order.status}"`
    );
  }

  // Look up staff name for notification
  const staff = await DeliveryStaff.findById(staffId).select("name").lean();

  await DailyOrder.findByIdAndUpdate(id, {
    $set: {
      deliveryStaffId: null,
      acceptedAt: null,
      status: "processing",
    },
  });

  await sendNotification({
    userId: ownerId,
    type: NOTIFICATION_TYPES.TASK_REJECTED,
    title: "⚠️ Delivery rejected",
    message: `${staff?.name || "Delivery boy"} rejected delivery for ${order.customerId?.name || "customer"}. Please reassign.`,
    data: { orderId: id, action: "rejected", reason: reason || "" },
  });

  res
    .status(200)
    .json(
      new ApiResponse(200, "Task rejected — please reassign", { orderId: id })
    );
});

/**
 * PATCH /api/v1/daily-orders/:id/quantities   (customer role)
 * Body: [{ itemId, quantity }]
 * Rules: only existing item IDs, quantity ≥ 1, cannot add or remove items.
 * Daily charge (`amount`) stays the plan/slot meal price — quantities are fulfilment-only.
 */
const quantitiesSchema = Joi.array()
  .items(
    Joi.object({
      itemId: Joi.string().hex().length(24).required().messages({
        "string.length": "itemId must be a 24-character hex string",
        "string.pattern.base": "itemId must be a valid ObjectId",
      }),
      quantity: Joi.number().integer().min(1).required().messages({
        "number.min": "quantity must be at least 1",
        "number.base": "quantity must be a number",
      }),
    })
  )
  .min(1)
  .required();

export const updateOrderQuantities = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { customerId } = req.user;

  if (!customerId) throw new ApiError(403, "Customer ID not found in token");

  const { error, value } = quantitiesSchema.validate(req.body, {
    abortEarly: false,
  });
  if (error) {
    throw new ApiError(400, error.details.map((d) => d.message).join("; "));
  }

  const order = await DailyOrder.findOne({ _id: id, customerId });
  if (!order) throw new ApiError(404, "Order not found");

  if (["delivered", "cancelled", "failed", "skipped"].includes(order.status)) {
    throw new ApiError(
      400,
      `Cannot update quantities on a ${order.status} order`
    );
  }

  // Validate: only existing itemIds allowed — no add/remove
  const existingItemIds = new Set(
    order.resolvedItems.map((i) => i.itemId.toString())
  );
  for (const { itemId } of value) {
    if (!existingItemIds.has(itemId)) {
      throw new ApiError(
        400,
        `Item ${itemId} is not part of this order. You can only adjust quantities of existing items.`
      );
    }
  }

  // Build qty map and apply
  const qtyMap = Object.fromEntries(
    value.map(({ itemId, quantity }) => [itemId, quantity])
  );

  const preservedAmount = typeof order.amount === "number" ? order.amount : 0;
  const updatedItems = order.resolvedItems.map((item) => {
    const newQty = qtyMap[item.itemId.toString()] ?? item.quantity;
    return {
      itemId: item.itemId,
      itemName: item.itemName,
      quantity: newQty,
      unitPrice: 0,
      subtotal: 0,
    };
  });

  order.resolvedItems = updatedItems;
  order.amount = preservedAmount;

  await order.save();

  res.status(200).json(
    new ApiResponse(200, "Order quantities updated", {
      orderId: id,
      resolvedItems: order.resolvedItems,
      amount: preservedAmount,
    })
  );
});

/**
 * DEBUG: find subscriptions matching a specific date
 */
export const debugMatchForDate = asyncHandler(async (req, res) => {
  const ownerId = req.user.userId;
  const { date } = req.query;

  if (!date) throw new ApiError(400, "date query param required");

  const day = parseUTC(date);
  const dow = day.getUTCDay();

  const subs = await Subscription.find({
    ownerId,
    status: "active",
    startDate: { $lte: day },
    endDate: { $gte: day },
    deliveryDays: { $in: [dow] },
  })
    .populate("customerId", "name phone")
    .populate("planId", "planName price")
    .lean();

  res.status(200).json(
    new ApiResponse(200, "Debug match subscriptions", {
      date: day.toISOString(),
      dow,
      data: subs,
      total: subs.length,
    })
  );
});
