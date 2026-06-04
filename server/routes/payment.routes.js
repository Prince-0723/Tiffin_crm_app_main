import { Router } from "express";
import {
  listPayments,
  createPayment,
  createOrder,
  getInvoice,
} from "../controllers/payment.controller.js";
import { authMiddleware } from "../middleware/auth.middleware.js";
import { requireRole } from "../middleware/rbac.middleware.js";

const router = Router();
router.use(authMiddleware);
router.use(requireRole(["vendor", "admin"]));

router.get("/", listPayments);
router.get("/:id/invoice", getInvoice);
router.post("/", createPayment);
router.post("/create-order", createOrder);

export default router;
