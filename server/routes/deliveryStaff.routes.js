import { Router } from "express";
import {
  listStaff,
  getStaffById,
  createStaff,
  updateStaff,
  deleteStaff,
  getMyStaffProfile,
  updateMyStaffProfile,
} from "../controllers/deliveryStaff.controller.js";
import { authMiddleware } from "../middleware/auth.middleware.js";
import { requireRole } from "../middleware/rbac.middleware.js";

const router = Router();
router.use(authMiddleware);

// Self-service routes for delivery staff — declared before the vendor/admin gate
router.get("/me", requireRole(["delivery_staff"]), getMyStaffProfile);
router.patch("/me", requireRole(["delivery_staff"]), updateMyStaffProfile);

// Vendor / admin management routes
router.use(requireRole(["vendor", "admin"]));
router.get("/", listStaff);
router.get("/:id", getStaffById);
router.post("/", createStaff);
router.put("/:id", updateStaff);
router.delete("/:id", deleteStaff);

export default router;
