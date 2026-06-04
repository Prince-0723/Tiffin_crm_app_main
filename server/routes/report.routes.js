import { Router } from "express";
import {
  getSummary,
  getTodayDeliveries,
  getDeliveredOrderAmount,
  getExpiringSubscriptions,
  getPendingPayments,
} from "../controllers/report.controller.js";
import { authMiddleware } from "../middleware/auth.middleware.js";
import { requireRole } from "../middleware/rbac.middleware.js";

const router = Router();

router.use(authMiddleware);
router.use(requireRole(["vendor", "admin"]));

router.get("/summary", getSummary);
router.get("/today-deliveries", getTodayDeliveries);
router.get("/delivered-amount", getDeliveredOrderAmount);
router.get("/expiring-subscriptions", getExpiringSubscriptions);
router.get("/pending-payments", getPendingPayments);

export default router;
