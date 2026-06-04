import { Router } from "express";
import { authMiddleware } from "../middleware/auth.middleware.js";
import { requireRole } from "../middleware/rbac.middleware.js";
import {
  listZones,
  getZoneById,
  createZone,
  updateZone,
  deactivateZone,
} from "../controllers/zone.controller.js";

const router = Router();

router.use(authMiddleware);
router.use(requireRole(["vendor", "admin"]));

router.get("/", listZones);
router.get("/:id", getZoneById);
router.post("/", createZone);
router.put("/:id", updateZone);
router.delete("/:id", deactivateZone);

export default router;

