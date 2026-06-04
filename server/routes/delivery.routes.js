import { Router } from "express";
import { authMiddleware } from "../middleware/auth.middleware.js";
import { requireRole } from "../middleware/rbac.middleware.js";
import { getToday } from "../controllers/dailyOrder.controller.js";
import { getMyDeliveries } from "../controllers/delivery.controller.js";

const router = Router();

router.use(authMiddleware);

// Vendor sees all today's deliveries
router.get("/", requireRole(["vendor", "admin"]), getToday);

// Delivery staff sees only their assigned deliveries for today
router.get("/my-deliveries", requireRole(["delivery_staff"]), getMyDeliveries);

export default router;
