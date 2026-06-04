import { Router } from "express";
import {
  listItems,
  getItemById,
  createItem,
  updateItem,
  deleteItem,
} from "../controllers/item.controller.js";
import { authMiddleware } from "../middleware/auth.middleware.js";
import { requireRole } from "../middleware/rbac.middleware.js";

const router = Router();

router.use(authMiddleware);
router.use(requireRole(["vendor", "admin"]));

router.get("/", listItems);
router.get("/:id", getItemById);
router.post("/", createItem);
router.put("/:id", updateItem);
router.delete("/:id", deleteItem);

export default router;
