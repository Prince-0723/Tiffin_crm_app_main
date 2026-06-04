import Joi from "joi";
import mongoose from "mongoose";
import DailyOrder from "../models/DailyOrder.model.js";
import Payment from "../models/Payment.model.js";
import Expense from "../models/Expense.model.js";
import Income from "../models/Income.model.js";
import { parseUTC } from "../services/dailyOrder.service.js";
import { asyncHandler } from "../utils/asyncHandler.js";
import { ApiResponse } from "../class/apiResponseClass.js";
import { ApiError } from "../class/apiErrorClass.js";

const monthQuerySchema = Joi.object({
  month: Joi.string()
    .pattern(/^\d{4}-(0[1-9]|1[0-2])$/)
    .required()
    .messages({
      "string.pattern.base": "month must be YYYY-MM (e.g. 2026-04)",
    }),
});

function daysInCalendarMonth(year, month1to12) {
  return new Date(year, month1to12, 0).getDate();
}

/** YYYY-MM-DD strings for each day in the month (calendar). */
function* iterateMonthDates(year, month1to12) {
  const dim = daysInCalendarMonth(year, month1to12);
  const ym = `${year}-${String(month1to12).padStart(2, "0")}`;
  for (let d = 1; d <= dim; d += 1) {
    yield `${ym}-${String(d).padStart(2, "0")}`;
  }
}

function roundMoney(n) {
  return Math.round((Number(n) || 0) * 100) / 100;
}

function toMapByYmd(rows, keyField = "_id") {
  const m = new Map();
  for (const row of rows) {
    const k = row[keyField];
    if (k) m.set(k, row);
  }
  return m;
}

/**
 * GET /api/v1/vendor/finance/monthly?month=YYYY-MM
 *
 * Per-day: processed (delivered daily orders), refunds, expenses, manual income, deposits.
 * Summary: revenue (from delivered orders), expenses, manual incomes, refunds, deposits, profit.
 */
export const getMonthlyFinance = asyncHandler(async (req, res) => {
  const { error, value } = monthQuerySchema.validate(req.query, {
    stripUnknown: true,
    abortEarly: false,
  });
  if (error) {
    throw new ApiError(400, error.details.map((d) => d.message).join("; "));
  }

  const ownerId = req.user.userId;
  const ownerOid = new mongoose.Types.ObjectId(ownerId);

  const [yStr, mStr] = value.month.split("-");
  const year = parseInt(yStr, 10);
  const month = parseInt(mStr, 10);

  const monthStart = parseUTC(`${value.month}-01`);
  let nextY = year;
  let nextM = month + 1;
  if (nextM > 12) {
    nextM = 1;
    nextY += 1;
  }
  const monthEndExclusive = parseUTC(
    `${nextY}-${String(nextM).padStart(2, "0")}-01`
  );

  const rangeMatch = {
    $gte: monthStart,
    $lt: monthEndExclusive,
  };

  const [
    processedAgg,
    refundAgg,
    expenseAgg,
    incomeNonDepositAgg,
    depositIncomeAgg,
    depositPaymentAgg,
  ] = await Promise.all([
    DailyOrder.aggregate([
      {
        $match: {
          ownerId: ownerOid,
          orderDate: rangeMatch,
          status: "delivered",
        },
      },
      {
        $group: {
          _id: {
            $dateToString: {
              format: "%Y-%m-%d",
              date: "$orderDate",
              timezone: "UTC",
            },
          },
          count: { $sum: 1 },
          amount: { $sum: { $ifNull: ["$amount", 0] } },
        },
      },
    ]),
    Payment.aggregate([
      {
        $match: {
          ownerId: ownerOid,
          status: "refunded",
          paymentDate: rangeMatch,
        },
      },
      {
        $group: {
          _id: {
            $dateToString: {
              format: "%Y-%m-%d",
              date: "$paymentDate",
              timezone: "UTC",
            },
          },
          amount: { $sum: "$amount" },
        },
      },
    ]),
    Expense.aggregate([
      {
        $match: {
          ownerId: ownerOid,
          date: rangeMatch,
        },
      },
      {
        $group: {
          _id: {
            $dateToString: {
              format: "%Y-%m-%d",
              date: "$date",
              timezone: "UTC",
            },
          },
          amount: { $sum: "$amount" },
        },
      },
    ]),
    Income.aggregate([
      {
        $match: {
          ownerId: ownerOid,
          date: rangeMatch,
          $nor: [{ source: { $regex: /deposit/i } }],
        },
      },
      {
        $group: {
          _id: {
            $dateToString: {
              format: "%Y-%m-%d",
              date: "$date",
              timezone: "UTC",
            },
          },
          amount: { $sum: "$amount" },
        },
      },
    ]),
    Income.aggregate([
      {
        $match: {
          ownerId: ownerOid,
          date: rangeMatch,
          source: { $regex: /deposit/i },
        },
      },
      {
        $group: {
          _id: {
            $dateToString: {
              format: "%Y-%m-%d",
              date: "$date",
              timezone: "UTC",
            },
          },
          amount: { $sum: "$amount" },
        },
      },
    ]),
    Payment.aggregate([
      {
        $match: {
          ownerId: ownerOid,
          status: "captured",
          paymentDate: rangeMatch,
          notes: { $regex: /deposit/i },
        },
      },
      {
        $group: {
          _id: {
            $dateToString: {
              format: "%Y-%m-%d",
              date: "$paymentDate",
              timezone: "UTC",
            },
          },
          amount: { $sum: "$amount" },
        },
      },
    ]),
  ]);

  const processedMap = toMapByYmd(processedAgg);
  const refundMap = toMapByYmd(refundAgg);
  const expenseMap = toMapByYmd(expenseAgg);
  const incomeMap = toMapByYmd(incomeNonDepositAgg);
  const depInMap = toMapByYmd(depositIncomeAgg);
  const depPayMap = toMapByYmd(depositPaymentAgg);

  const daily = [];
  let totalRevenue = 0;
  let totalRefunds = 0;
  let totalExpenses = 0;
  let totalIncomes = 0;
  let totalDeposits = 0;

  for (const ymd of iterateMonthDates(year, month)) {
    const p = processedMap.get(ymd) || {};
    const count = p.count || 0;
    const procAmount = roundMoney(p.amount || 0);
    totalRevenue += procAmount;

    const ref = roundMoney((refundMap.get(ymd) || {}).amount || 0);
    totalRefunds += ref;

    const exp = roundMoney((expenseMap.get(ymd) || {}).amount || 0);
    totalExpenses += exp;

    const inc = roundMoney((incomeMap.get(ymd) || {}).amount || 0);
    totalIncomes += inc;

    const depI = roundMoney((depInMap.get(ymd) || {}).amount || 0);
    const depP = roundMoney((depPayMap.get(ymd) || {}).amount || 0);
    const dep = roundMoney(depI + depP);
    totalDeposits += dep;

    daily.push({
      date: ymd,
      processed: {
        count,
        amount: procAmount,
      },
      refund: ref,
      expenses: exp,
      income: inc,
      deposit: dep,
    });
  }

  daily.reverse();

  const profit = roundMoney(totalRevenue - totalExpenses);

  const chartOrders = [...daily]
    .reverse()
    .map((d) => ({
      date: d.date,
      ordersDelivered: d.processed.count,
    }));

  const response = new ApiResponse(200, "Finance summary", {
    month: value.month,
    calendar: "gregorian",
    note:
      "Dates align with stored UTC calendar days (same as DailyOrder.orderDate).",
    summary: {
      revenue: roundMoney(totalRevenue),
      expenses: roundMoney(totalExpenses),
      incomes: roundMoney(totalIncomes),
      refunds: roundMoney(totalRefunds),
      deposits: roundMoney(totalDeposits),
      profit,
    },
    daily,
    chart: {
      ordersProcessed: chartOrders,
    },
  });

  res.status(response.statusCode).json({
    success: response.success,
    message: response.message,
    data: response.data,
  });
});
