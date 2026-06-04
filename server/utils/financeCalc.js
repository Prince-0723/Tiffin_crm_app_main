import mongoose from "mongoose";
import Income from "../models/Income.model.js";
import Expense from "../models/Expense.model.js";
import DailyOrder from "../models/DailyOrder.model.js";
import Transaction from "../models/Transaction.model.js";

function asObjectId(id) {
  if (!id) return null;
  if (id instanceof mongoose.Types.ObjectId) return id;
  if (!mongoose.Types.ObjectId.isValid(id)) return null;
  return new mongoose.Types.ObjectId(id);
}

function money(n) {
  const v = Number(n || 0);
  return Number.isFinite(v) ? v : 0;
}

/**
 * Unified finance summary across:
 * - Income model (manual income entries)
 * - Expense model (manual expense entries)
 * - Transaction model (processed/deposit/refund/manual ledger entries)
 */
export async function getFinanceSummary(ownerId, startDate, endDate) {
  const ownerOid = asObjectId(ownerId);
  if (!ownerOid) throw new Error("Invalid ownerId");

  const start = new Date(startDate);
  const end = new Date(endDate);

  const dateFilter = { date: { $gte: start, $lte: end } };
  const ownerFilter = { ownerId: ownerOid };
  const orderDateFilter = { orderDate: { $gte: start, $lte: end } };

  const [incomes, expenses, transactions, deliveredOrders] = await Promise.all([
    Income.find({ ...ownerFilter, ...dateFilter }).lean(),
    Expense.find({ ...ownerFilter, ...dateFilter }).lean(),
    Transaction.find({
      ...ownerFilter,
      ...dateFilter,
      status: "completed",
    }).lean(),
    DailyOrder.find({
      ...ownerFilter,
      ...orderDateFilter,
      status: "delivered",
    })
      .select("amount orderDate")
      .lean(),
  ]);

  const sum = (arr) =>
    arr.reduce((s, r) => s + (parseFloat(r.amount) || 0), 0);

  const byFinanceType = (financeType) =>
    transactions
      .filter((t) => String(t.financeType || "").toLowerCase() === financeType)
      .reduce((s, r) => s + (parseFloat(r.amount) || 0), 0);

  const totalIncome = sum(incomes);
  const totalExpense = sum(expenses);
  const deliveredProcessed = deliveredOrders.reduce(
    (s, o) => s + (parseFloat(o.amount) || 0),
    0
  );
  // "processed" must represent delivered/completed orders.
  // We add delivered DailyOrder amounts (primary source) + any explicit processed Transactions (if you also create them elsewhere).
  const totalProcessed = byFinanceType("processed") + deliveredProcessed;
  const totalDeposit = byFinanceType("deposit");
  const totalRefund = byFinanceType("refund");
  const totalManual = byFinanceType("manual");

  // NOTE: keep these semantics aligned with the frontend expectation:
  // income = Income model total
  // expense = Expense model total
  // processed/deposit/refund/manual = Transaction buckets
  const revenue = totalIncome + totalProcessed + totalDeposit + totalManual;
  const profit = revenue - totalExpense - totalRefund;

  return {
    revenue: +money(revenue).toFixed(2),
    expenses: +money(totalExpense).toFixed(2),
    incomes: +money(totalIncome).toFixed(2),
    deposit: +money(totalDeposit).toFixed(2),
    processed: +money(totalProcessed).toFixed(2),
    refund: +money(totalRefund).toFixed(2),
    manual: +money(totalManual).toFixed(2),
    profit: +money(profit).toFixed(2),
  };
}

function daysInMonth(year, month1to12) {
  return new Date(year, month1to12, 0).getDate();
}

function pad2(n) {
  return String(n).padStart(2, "0");
}

function keyDdMm(d) {
  const date = new Date(d);
  return `${pad2(date.getUTCDate())}/${pad2(date.getUTCMonth() + 1)}`;
}

export async function getDailyBreakdown(ownerId, startDate, endDate) {
  const ownerOid = asObjectId(ownerId);
  if (!ownerOid) throw new Error("Invalid ownerId");

  const start = new Date(startDate);
  const end = new Date(endDate);

  const dateFilter = { date: { $gte: start, $lte: end } };
  const ownerFilter = { ownerId: ownerOid };
  const orderDateFilter = { orderDate: { $gte: start, $lte: end } };

  const [incomes, expenses, transactions, deliveredOrders] = await Promise.all([
    Income.find({ ...ownerFilter, ...dateFilter }).lean(),
    Expense.find({ ...ownerFilter, ...dateFilter }).lean(),
    Transaction.find({
      ...ownerFilter,
      ...dateFilter,
      status: "completed",
    }).lean(),
    DailyOrder.find({
      ...ownerFilter,
      ...orderDateFilter,
      status: "delivered",
    })
      .select("amount orderDate")
      .lean(),
  ]);

  const dailyMap = {};

  const ensure = (key) => {
    if (!dailyMap[key]) {
      dailyMap[key] = {
        processed: 0,
        processedCount: 0,
        income: 0,
        deposit: 0,
        expense: 0,
        refund: 0,
        manual: 0,
      };
    }
  };

  for (const r of incomes) {
    const key = keyDdMm(r.date);
    ensure(key);
    dailyMap[key].income += parseFloat(r.amount) || 0;
  }

  for (const r of expenses) {
    const key = keyDdMm(r.date);
    ensure(key);
    dailyMap[key].expense += parseFloat(r.amount) || 0;
  }

  for (const r of transactions) {
    const key = keyDdMm(r.date);
    ensure(key);
    const t = String(r.financeType || "").toLowerCase();
    if (t && dailyMap[key][t] !== undefined) {
      dailyMap[key][t] += parseFloat(r.amount) || 0;
    }
  }

  // Delivered orders -> processed (grouped by orderDate, which is the delivery day).
  for (const o of deliveredOrders) {
    const key = keyDdMm(o.orderDate);
    ensure(key);
    dailyMap[key].processed += parseFloat(o.amount) || 0;
    dailyMap[key].processedCount += 1;
  }

  // Ensure ALL days in the requested month are present (frontend calendar/table)
  const year = start.getUTCFullYear();
  const month = start.getUTCMonth() + 1;
  const dim = daysInMonth(year, month);
  for (let d = 1; d <= dim; d += 1) {
    const key = `${pad2(d)}/${pad2(month)}`;
    ensure(key);
  }

  return Object.entries(dailyMap)
    .map(([date, values]) => ({
      date,
      processed: +money(values.processed).toFixed(2),
      processedCount: values.processedCount || 0,
      income: +money(values.income).toFixed(2),
      deposit: +money(values.deposit).toFixed(2),
      expense: +money(values.expense).toFixed(2),
      refund: +money(values.refund).toFixed(2),
      manual: +money(values.manual).toFixed(2),
    }))
    .sort((a, b) => {
      const [da, ma] = a.date.split("/").map(Number);
      const [db, mb] = b.date.split("/").map(Number);
      return mb !== ma ? mb - ma : db - da;
    });
}

