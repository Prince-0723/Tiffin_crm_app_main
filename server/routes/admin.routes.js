import { Router } from "express";
import {
  listVendors,
  listAllCustomers,
  listAllDeliveryStaff,
  listAllPlans,
  listAllItems,
  listAllSubscriptions,
  listAllOrders,
  listAllPayments,
  listAllInvoices,
  listAllNotifications,
  getSystemStats,
  getVendorStats,
} from "../controllers/admin.controller.js";
import { authMiddleware } from "../middleware/auth.middleware.js";
import { requireRole } from "../middleware/rbac.middleware.js";

const router = Router();

router.use(authMiddleware);
router.use(requireRole(["admin"]));

// System-wide stats
router.get("/stats", getSystemStats);

// Vendors (specific routes before generic /vendors list)
router.get("/vendors/stats", getVendorStats);
router.get("/vendors", listVendors);

// Customers (all vendors)
router.get("/customers", listAllCustomers);

// Delivery staff (all vendors)
router.get("/delivery-staff", listAllDeliveryStaff);

// Meal plans (all vendors)
router.get("/plans", listAllPlans);

// Items (all vendors)
router.get("/items", listAllItems);

// Subscriptions (all vendors)
router.get("/subscriptions", listAllSubscriptions);

// Daily orders (all vendors)
router.get("/orders", listAllOrders);

// Payment transactions (all vendors)
router.get("/payments", listAllPayments);

// Invoices (all vendors)
router.get("/invoices", listAllInvoices);

// In-app notifications (all vendors)
router.get("/notifications", listAllNotifications);

export default router;
