import { Router } from "express";
import { authMiddleware } from "../middleware/auth.middleware.js";
import { requireRole } from "../middleware/rbac.middleware.js";
import { getMonthlyFinance } from "../controllers/vendorFinance.controller.js";

const router = Router();

router.use(authMiddleware);
router.use(requireRole(["vendor"]));

router.get("/monthly", getMonthlyFinance);

export default router;
