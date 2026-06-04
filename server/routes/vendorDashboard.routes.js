import { Router } from "express";
import { authMiddleware } from "../middleware/auth.middleware.js";
import { requireRole } from "../middleware/rbac.middleware.js";
import { getDailyItems } from "../controllers/vendorDashboard.controller.js";

const router = Router();

router.use(authMiddleware);
router.use(requireRole(["vendor"]));

router.get("/daily-items", getDailyItems);

export default router;
