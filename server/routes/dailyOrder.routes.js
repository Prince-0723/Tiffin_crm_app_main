import { Router } from "express";
import { authMiddleware } from "../middleware/auth.middleware.js";
import { requireRole } from "../middleware/rbac.middleware.js";
import {
  getToday,
  processToday,
  cancelVendorHoliday,
  markDelivered,
  updateOrderStatus,
  assignDeliveryStaff,
  bulkUpdateOrderStatus,
  assignBulk,
  acceptTask,
  rejectTask,
  debugOrders,
  generateOrders,
  debugSubscriptions,
  debugMatchForDate,
  generateNextWeekOrders,
  updateOrderQuantities,
} from "../controllers/dailyOrder.controller.js";

const router = Router();

router.use(authMiddleware);

// Vendor/admin only routes
router.get("/today", requireRole(["vendor", "admin"]), getToday);
router.post("/process", requireRole(["vendor", "admin"]), processToday);
router.post(
  "/cancel-vendor-holiday",
  requireRole(["vendor", "admin"]),
  cancelVendorHoliday
);
router.post("/mark-delivered", requireRole(["vendor", "admin"]), markDelivered);
router.post("/bulk-status", requireRole(["vendor", "admin"]), bulkUpdateOrderStatus);
router.post("/assign-bulk", requireRole(["vendor", "admin"]), assignBulk);
router.post("/generate", requireRole(["vendor", "admin"]), generateOrders);
router.post("/generate-week", requireRole(["vendor", "admin"]), generateNextWeekOrders);
router.get("/debug/subscriptions", requireRole(["vendor", "admin"]), debugSubscriptions);
router.get("/debug/subscription/:subscriptionId", requireRole(["vendor", "admin"]), debugOrders);
router.get("/debug/match", requireRole(["vendor", "admin"]), debugMatchForDate);

// Vendor assigns; delivery_staff acts on their own; customer adjusts quantities
router.patch("/:id/assign", requireRole(["vendor", "admin"]), assignDeliveryStaff);
router.patch("/:id/status", requireRole(["vendor", "admin", "delivery_staff"]), updateOrderStatus);
router.patch("/:id/quantities", requireRole(["customer"]), updateOrderQuantities);
router.post("/:id/accept", requireRole(["delivery_staff"]), acceptTask);
router.post("/:id/reject", requireRole(["delivery_staff"]), rejectTask);

export default router;
