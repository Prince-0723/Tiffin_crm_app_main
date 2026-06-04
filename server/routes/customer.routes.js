import { Router } from "express";
import rateLimit from "express-rate-limit";
import {
  listCustomers,
  getCustomerById,
  createCustomer,
  updateCustomer,
  bulkCreateCustomers,
  deleteCustomer,
  walletCredit,
  walletDebit,
} from "../controllers/customer.controller.js";
import { createCustomerPlan } from "../controllers/plan.controller.js";
import { authMiddleware } from "../middleware/auth.middleware.js";
import { requireRole } from "../middleware/rbac.middleware.js";

const router = Router();
router.use(authMiddleware);
router.use(requireRole(["vendor", "admin"]));

const bulkRateLimit = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 5,
  message: { success: false, message: "Too many bulk import attempts, try again later" },
});

router.get("/", listCustomers);
router.get("/:id", getCustomerById);
router.post("/", createCustomer);
router.post("/bulk", bulkRateLimit, bulkCreateCustomers);
router.put("/:id", updateCustomer);
router.delete("/:id", deleteCustomer);
router.post("/:id/wallet/credit", walletCredit);
router.post("/:id/wallet/debit", walletDebit);

// Create a custom meal plan directly for a specific customer
router.post("/:customerId/plans", createCustomerPlan);

export default router;
