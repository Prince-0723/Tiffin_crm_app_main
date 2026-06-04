import { Router } from "express";
import { authMiddleware } from "../middleware/auth.middleware.js";
import { requireRole } from "../middleware/rbac.middleware.js";
import {
  createProcessed,
  createIncomeTxn,
  createDeposit,
  createExpenseTxn,
  createRefund,
  getDailyFinance,
  getFinanceCalendar,
  getMonthlySummary,
  getPendingByCustomer,
} from "../controllers/financeController.js";

const router = Router();

router.use(authMiddleware);
router.use(requireRole(["vendor"]));

router.post("/finance/processed", createProcessed);
router.post("/finance/income", createIncomeTxn);
router.post("/finance/deposit", createDeposit);
router.post("/finance/expense", createExpenseTxn);
router.post("/finance/refund", createRefund);

router.get("/finance/daily", getDailyFinance);
router.get("/finance/calendar", getFinanceCalendar);
router.get("/finance/summary", getMonthlySummary);
router.get("/finance/pending", getPendingByCustomer);

export default router;

