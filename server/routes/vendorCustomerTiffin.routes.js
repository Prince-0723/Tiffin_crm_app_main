import { Router } from "express";
import { authMiddleware } from "../middleware/auth.middleware.js";
import { requireRole } from "../middleware/rbac.middleware.js";
import {
  getCustomerTiffin,
  incrementCustomerTiffin,
  decrementCustomerTiffin,
} from "../controllers/vendorCustomerTiffin.controller.js";

const router = Router();

router.use(authMiddleware);
router.use(requireRole(["vendor"]));

router.get("/:customerId/tiffin", getCustomerTiffin);
router.patch("/:customerId/tiffin/increment", incrementCustomerTiffin);
router.patch("/:customerId/tiffin/decrement", decrementCustomerTiffin);

export default router;
