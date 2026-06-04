import { Router } from "express";
import { authMiddleware } from "../middleware/auth.middleware.js";
import { requireRole } from "../middleware/rbac.middleware.js";
import {
  listInvoices,
  generateInvoiceForRange,
  getDailyInvoiceReceipt,
  getInvoiceById,
  updateInvoice,
  shareInvoice,
  voidInvoice,
  getOverdueInvoices,
} from "../controllers/invoice.controller.js";

const router = Router();

router.use(authMiddleware);
router.use(requireRole(["vendor", "admin"]));

router.get("/", listInvoices);
router.post("/generate", generateInvoiceForRange);
router.get("/overdue", getOverdueInvoices);
router.get("/daily", getDailyInvoiceReceipt);
router.get("/:id", getInvoiceById);
router.put("/:id", updateInvoice);
router.post("/:id/share", shareInvoice);
router.post("/:id/void", voidInvoice);

export default router;
