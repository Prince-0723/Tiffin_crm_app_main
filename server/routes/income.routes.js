import { Router } from "express";
import {
  createIncome,
  listIncomes,
  deleteIncome,
} from "../controllers/income.controller.js";
import { authMiddleware } from "../middleware/auth.middleware.js";
import { requireRole } from "../middleware/rbac.middleware.js";

const router = Router();

router.use(authMiddleware);
router.use(requireRole(["vendor"]));

router.get("/", listIncomes);
router.post("/", createIncome);
router.delete("/:id", deleteIncome);

export default router;
