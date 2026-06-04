import { Router } from "express";
import {
  createExpense,
  listExpenses,
  deleteExpense,
  getExpenseSummary,
} from "../controllers/expense.controller.js";
import { authMiddleware } from "../middleware/auth.middleware.js";
import { requireRole } from "../middleware/rbac.middleware.js";

const router = Router();

router.use(authMiddleware);
router.use(requireRole(["vendor"]));

router.get("/summary", getExpenseSummary);
router.get("/", listExpenses);
router.post("/", createExpense);
router.delete("/:id", deleteExpense);

export default router;
