import { Router } from "express";
import { authMiddleware } from "../middleware/auth.middleware.js";
import { requireRole } from "../middleware/rbac.middleware.js";
import {
  updateFcmToken,
  getPortalAnnouncement,
  updatePortalAnnouncement,
} from "../controllers/user.controller.js";

const router = Router();

router.put("/fcm-token", authMiddleware, updateFcmToken);

router.get(
  "/portal-announcement",
  authMiddleware,
  requireRole(["vendor"]),
  getPortalAnnouncement
);
router.put(
  "/portal-announcement",
  authMiddleware,
  requireRole(["vendor"]),
  updatePortalAnnouncement
);

export default router;
