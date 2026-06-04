import { Router } from "express";
import rateLimit, { ipKeyGenerator } from "express-rate-limit";
import {
  sendOtpController,
  verifyOtpController,
  refreshTokenController,
  logoutController,
  updateMe,
  forgotPasswordController,
  resetPasswordController,
  getMeController,
  changePasswordController,
  vendorOnboardingController,
} from "../controllers/auth.controller.js";
import { authMiddleware } from "../middleware/auth.middleware.js";
import { requireRole } from "../middleware/rbac.middleware.js";

const router = Router();

const AUTH_WINDOW_MS = 15 * 60 * 1000;

const normalizePhone = (phone) =>
  String(phone || "")
    .replace(/\D/g, "")
    .slice(-10);

// Strict throttle for OTP send to reduce abuse/cost.
const sendOtpLimiter = rateLimit({
  windowMs: AUTH_WINDOW_MS,
  max: 30, // per IP
  message: {
    success: false,
    message: "Too many OTP requests, try again later",
  },
});

const sendOtpPhoneLimiter = rateLimit({
  windowMs: AUTH_WINDOW_MS,
  max: 8, // per phone
  keyGenerator: (req) => {
    const phone = normalizePhone(req.body?.phone);
    return phone ? `send-otp:${phone}` : `send-otp-ip:${ipKeyGenerator(req)}`;
  },
  message: { success: false, message: "Too many OTP requests for this number" },
});

const verifyOtpLimiter = rateLimit({
  windowMs: AUTH_WINDOW_MS,
  max: 100, // per IP
  message: {
    success: false,
    message: "Too many OTP verification attempts, try again later",
  },
});

const verifyOtpPhoneLimiter = rateLimit({
  windowMs: AUTH_WINDOW_MS,
  max: 25, // per phone
  keyGenerator: (req) => {
    const phone = normalizePhone(req.body?.phone);
    return phone
      ? `verify-otp:${phone}`
      : `verify-otp-ip:${ipKeyGenerator(req)}`;
  },
  message: {
    success: false,
    message: "Too many OTP verification attempts for this number",
  },
});

const refreshTokenLimiter = rateLimit({
  windowMs: AUTH_WINDOW_MS,
  max: 200,
  message: {
    success: false,
    message: "Too many refresh requests, try again later",
  },
});

router.post(
  "/send-otp",
  sendOtpLimiter,
  sendOtpPhoneLimiter,
  sendOtpController
);
router.post(
  "/verify-otp",
  verifyOtpLimiter,
  verifyOtpPhoneLimiter,
  verifyOtpController
);
router.post("/forgot-password", forgotPasswordController);
router.post("/reset-password", resetPasswordController);
router.post("/refresh-token", refreshTokenLimiter, refreshTokenController);
router.post("/logout", authMiddleware, logoutController);
router.put("/me", authMiddleware, updateMe);
router.post(
  "/vendor/onboarding",
  authMiddleware,
  requireRole(["vendor"]),
  vendorOnboardingController
);

router.get("/me", authMiddleware, getMeController);
router.put("/change-password", authMiddleware, changePasswordController);

export default router;
