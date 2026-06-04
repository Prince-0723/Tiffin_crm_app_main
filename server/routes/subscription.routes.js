import { Router } from "express";
import {
  listSubscriptions,
  getSubscriptionById,
  createSubscription,
  renewSubscription,
  cancelSubscription,
  deleteSubscription,
  pauseSubscription,
  unpauseSubscription,
} from "../controllers/subscription.controller.js";
import { authMiddleware } from "../middleware/auth.middleware.js";
import { requireRole } from "../middleware/rbac.middleware.js";

const router = Router();

router.use(authMiddleware);

// Vendor/admin-only routes
router.get("/", requireRole(["vendor", "admin"]), listSubscriptions);
router.get("/:id", requireRole(["vendor", "admin"]), getSubscriptionById);
router.post("/", requireRole(["vendor", "admin"]), createSubscription);
router.put("/:id/renew", requireRole(["vendor", "admin"]), renewSubscription);
router.put("/:id/cancel", requireRole(["vendor", "admin"]), cancelSubscription);
router.delete("/:id", requireRole(["vendor", "admin"]), deleteSubscription);

// Vendor/admin + customer can pause/unpause
router.put("/:id/pause", requireRole(["vendor", "admin", "customer"]), pauseSubscription);
router.put("/:id/unpause", requireRole(["vendor", "admin", "customer"]), unpauseSubscription);

export default router;
