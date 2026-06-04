import { Router } from "express";
import Joi from "joi";
import { authMiddleware } from "../middleware/auth.middleware.js";
import { requireRole } from "../middleware/rbac.middleware.js";
import { asyncHandler } from "../utils/asyncHandler.js";
import { ApiResponse } from "../class/apiResponseClass.js";
import { ApiError } from "../class/apiErrorClass.js";
import { sendToToken } from "../services/notification.service.js";

const router = Router();

const sendSchema = Joi.object({
  token: Joi.string().trim().required(),
  title: Joi.string().trim().required(),
  body: Joi.string().trim().required(),
  data: Joi.object().unknown(true).optional(),
});

router.post(
  "/",
  authMiddleware,
  requireRole(["vendor", "admin"]),
  asyncHandler(async (req, res) => {
    const { error, value } = sendSchema.validate(req.body, {
      stripUnknown: true,
      abortEarly: false,
    });
    if (error) {
      throw new ApiError(400, error.details.map((d) => d.message).join("; "));
    }

    const responseId = await sendToToken(
      value.token,
      value.title,
      value.body,
      value.data || {}
    );

    res.status(200).json(
      new ApiResponse(200, "Notification sent successfully", {
        responseId,
      })
    );
  })
);

export default router;
