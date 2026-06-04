import Joi from "joi";
import User from "../models/User.model.js";
import DeliveryStaff from "../models/DeliveryStaff.model.js";
import config from "../config/index.js";
import { sendOtp, verifyOtp } from "../services/otp.service.js";
import * as passwordService from "../services/password.service.js";
import * as securePassword from "../services/securePassword.service.js";
import * as emailService from "../services/email.service.js";
import {
  generateAccessToken,
  generateRefreshToken,
  verifyRefreshToken,
} from "../services/token.service.js";
import {
  resolveRoleForPhone,
  hasVendorBusinessData,
} from "../services/authRole.service.js";
import { asyncHandler } from "../utils/asyncHandler.js";
import { ApiResponse } from "../class/apiResponseClass.js";
import { ApiError } from "../class/apiErrorClass.js";

/**
 * Delivery staff display name is stored on [DeliveryStaff], not [User]
 * (User is the login shell: phone + role). [getMe] and auth payloads must read it here.
 */
const getDeliveryStaffDisplayName = async (userId, staffIdFromToken) => {
  if (staffIdFromToken) {
    const byId = await DeliveryStaff.findById(staffIdFromToken)
      .select("name")
      .lean();
    if (byId?.name?.trim()) return byId.name.trim();
  }
  const byUser = await DeliveryStaff.findOne({ userId }).select("name").lean();
  if (byUser?.name?.trim()) return byUser.name.trim();
  return "";
};

/**
 * User object returned on login/refresh — includes vendor business fields from DB
 * so clients don't treat completed onboarding as "empty name" on every login.
 * Pass [staffDisplayName] in [extra] for delivery_staff (stripped from spread output).
 */
const buildAuthUserPayload = (user, role, extra = {}) => {
  const u =
    user && typeof user.toObject === "function" ? user.toObject() : user;
  const id = u._id?.toString?.() ?? String(u._id);
  const { staffDisplayName, ...restExtra } = extra;
  const name = (
    (typeof staffDisplayName === "string" && staffDisplayName.trim()) ||
    u.name ||
    u.ownerName ||
    ""
  ).trim();
  const payload = {
    id,
    phone: u.phone,
    name,
    role,
    ...restExtra,
  };
  if (role === "vendor") {
    payload.businessName = (u.businessName || "").trim();
    payload.ownerName = (u.ownerName || "").trim();
    payload.address = (u.address || "").trim();
    payload.upiId = (u.upiId || "").trim();
  }
  return payload;
};

const phoneSchema = Joi.string()
  .pattern(/^[6-9]\d{9}$/)
  .required()
  .messages({
    "string.pattern.base":
      "Phone must be a valid 10-digit Indian mobile number",
  });

// simple password strength: min 8, one lower, one upper, one digit
const passwordPattern = /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{8,}$/;
const passwordMessage =
  "Password must be at least 8 characters and include upper, lower and number";

const sendOtpSchema = Joi.object({
  phone: phoneSchema,
});

const verifyOtpSchema = Joi.object({
  phone: phoneSchema,
  otp: Joi.string().length(6).pattern(/^\d+$/).required().messages({
    "string.length": "OTP must be 6 digits",
    "string.pattern.base": "OTP must contain only digits",
  }),
});

const refreshTokenSchema = Joi.object({
  refreshToken: Joi.string().required(),
});

// ---------------- password management ----------------
const forgotPasswordSchema = Joi.object({
  phone: phoneSchema,
});

const resetPasswordSchema = Joi.object({
  token: Joi.string().required(),
  newPassword: Joi.string().pattern(passwordPattern).required().messages({
    "string.pattern.base": passwordMessage,
  }),
});

/**
 * POST /api/v1/auth/send-otp
 * Body: { phone: "9876543210" }
 */
export const sendOtpController = asyncHandler(async (req, res, next) => {
  const { error, value } = sendOtpSchema.validate(req.body, {
    stripUnknown: true,
    abortEarly: false,
  });

  if (error) {
    throw new ApiError(400, error.details.map((d) => d.message).join("; "));
  }

  const { phone } = value;
  const result = await sendOtp(phone);

  if (!result.success) {
    throw new ApiError(502, result.message || "Failed to send OTP");
  }

  const response = new ApiResponse(200, "OTP sent successfully");
  res.status(response.statusCode).json({
    success: response.success,
    message: response.message,
  });
});

// -----------------------------------------------------------------------------
// Password reset flow (Day 1)
// -----------------------------------------------------------------------------

/**
 * POST /api/v1/auth/forgot-password
 * Body: { phone: "9876543210" }
 */
export const forgotPasswordController = asyncHandler(async (req, res, next) => {
  // make sure body is an object so Joi doesn't quietly return undefined
  const { error, value } = forgotPasswordSchema.validate(req.body || {}, {
    stripUnknown: true,
    abortEarly: false,
  });

  if (error || !value || typeof value.phone === "undefined") {
    const msg = error
      ? error.details.map((d) => d.message).join("; ")
      : "phone is required";
    throw new ApiError(400, msg);
  }

  const { phone } = value;
  const user = await User.findOne({ phone }).lean();

  // always return 200 to avoid enumerating users
  const response = new ApiResponse(
    200,
    "If the phone is registered, a reset link has been sent"
  );

  // in development we return the raw token for easier testing
  const payload = {
    success: response.success,
    message: response.message,
  };

  let token;
  if (user) {
    // generate/reset token now so we can use it in email or debug output
    token = await passwordService.generateResetToken(user._id);
    if (config.NODE_ENV !== "production") {
      payload.debugToken = token;
      console.log("[forgot-password] token for", phone, token);
    }
  }

  res.status(response.statusCode).json(payload);

  if (!user) return;

  // send email if we know the address and user has enabled notifications
  if (user.email) {
    const resetLink =
      (config.FRONTEND_URL || "https://app.tiffincrm.com") + `/reset/${token}`;

    const emailResult = await emailService.sendEmail({
      to: user.email,
      subject: "Password Reset - TiffinCRM",
      template: "password-reset",
      data: {
        name: user.ownerName || user.name || "",
        resetLink,
        expiresIn: "10 minutes",
      },
    });

    if (!emailResult.success) {
      // log and continue; we don't want to reveal failure to the caller
      console.log("[forgot-password] failed to send email", emailResult.error);
    }
  } else {
    console.log("[forgot-password] no email on user", user._id);
  }
});

/**
 * POST /api/v1/auth/reset-password
 * Body: { token, newPassword }
 */
export const resetPasswordController = asyncHandler(async (req, res, next) => {
  const { error, value } = resetPasswordSchema.validate(req.body || {}, {
    stripUnknown: true,
    abortEarly: false,
  });

  if (
    error ||
    !value ||
    typeof value.token === "undefined" ||
    typeof value.newPassword === "undefined"
  ) {
    const msg = error
      ? error.details.map((d) => d.message).join("; ")
      : "token and newPassword are required";
    throw new ApiError(400, msg);
  }

  const { token, newPassword } = value;
  const user = await passwordService.resetPassword(token, newPassword);

  // Admin is never overridden
  let resolved;
  if (user.role === "admin") {
    resolved = {
      role: "admin",
      ownerId: null,
      staffId: null,
      customerId: null,
    };
  } else if (user.role === "vendor") {
    resolved = {
      role: "vendor",
      ownerId: null,
      staffId: null,
      customerId: null,
    };
  } else {
    resolved = await resolveRoleForPhone(user.phone);
  }
  const role = resolved.role;
  const ownerId =
    role === "admin"
      ? null
      : role === "vendor"
        ? user._id.toString()
        : resolved.ownerId || null;
  const staffId = resolved.staffId || null;
  const customerId = resolved.customerId || null;

  let staffDisplayName = "";
  if (role === "delivery_staff") {
    staffDisplayName = await getDeliveryStaffDisplayName(user._id, staffId);
  }

  const payload = {
    userId: user._id.toString(),
    phone: user.phone,
    role,
    ...(ownerId && { ownerId }),
    ...(staffId && { staffId }),
    ...(customerId && { customerId }),
  };

  const accessToken = generateAccessToken(payload);
  const refreshToken = generateRefreshToken(payload);

  const resp = new ApiResponse(200, "Password updated", {
    accessToken,
    refreshToken,
    user: buildAuthUserPayload(user, role, {
      ...(staffId && { staffId }),
      ...(customerId && { customerId }),
      ...(staffDisplayName && { staffDisplayName }),
    }),
  });

  res.status(resp.statusCode).json({
    success: resp.success,
    message: resp.message,
    data: resp.data,
  });
});

/**
 * POST /api/v1/auth/verify-otp
 * Body: { phone: "9876543210", otp: "123456" }
 * Returns: { accessToken, refreshToken, user }
 */
export const verifyOtpController = asyncHandler(async (req, res, next) => {
  const { error, value } = verifyOtpSchema.validate(req.body, {
    stripUnknown: true,
    abortEarly: false,
  });

  if (error) {
    throw new ApiError(400, error.details.map((d) => d.message).join("; "));
  }

  const { phone, otp } = value;
  const isValid = await verifyOtp(phone, otp);

  if (!isValid) {
    throw new ApiError(401, "Invalid or expired OTP");
  }

  const resolved = await resolveRoleForPhone(phone);
  let user = await User.findOne({ phone });

  if (!user) {
    user = await User.create({ phone, role: resolved.role });
  } else if (user.role === "admin") {
    // Admin is never overridden: resolveRoleForPhone is not used for role/ownerId
  } else if (user.role === "vendor") {
    // Override to customer/delivery_staff ONLY if they have NO vendor business data.
    // Protects real vendors from abuse: a malicious vendor could add another vendor's
    // phone as customer to hijack their role. We only override "accidental vendors"
    // (empty account, no customers/plans/subscriptions).
    if (resolved.role !== "vendor") {
      const hasBusiness = await hasVendorBusinessData(user._id);
      if (!hasBusiness) {
        await User.updateOne(
          { _id: user._id },
          { $set: { role: resolved.role } }
        );
        user.role = resolved.role;
      } else {
        resolved.role = "vendor";
        resolved.ownerId = null;
      }
    } else {
      resolved.ownerId = null;
    }
  } else {
    // Keep customer/delivery_staff in sync: if resolved role changed, update user. Never overwrite admin.
    if (user.role !== resolved.role) {
      await User.updateOne(
        { _id: user._id },
        { $set: { role: resolved.role } }
      );
      user.role = resolved.role;
    }
  }

  // record login event
  user.loginHistory = user.loginHistory || [];
  user.loginHistory.push({
    ip: req.ip,
    userAgent: req.get("User-Agent") || "",
    at: new Date(),
  });
  await user.save();
  user = user.toObject();

  // Admin is never overridden: use stored user.role and no ownerId
  const role =
    user.role === "admin"
      ? "admin"
      : user.role === "vendor"
        ? "vendor"
        : resolved.role;
  const ownerId =
    role === "admin"
      ? null
      : role === "vendor"
        ? user._id.toString()
        : resolved.ownerId || null;

  // For delivery_staff: link their User account to DeliveryStaff if not already done
  let staffId = resolved.staffId || null;
  if (role === "delivery_staff" && staffId) {
    await DeliveryStaff.findByIdAndUpdate(staffId, {
      $set: { userId: user._id },
    });
  }

  const customerId = resolved.customerId || null;

  let staffDisplayName = "";
  if (role === "delivery_staff") {
    staffDisplayName = await getDeliveryStaffDisplayName(user._id, staffId);
  }

  const payload = {
    userId: user._id.toString(),
    phone: user.phone,
    role,
    ...(ownerId && { ownerId }),
    ...(staffId && { staffId }),
    ...(customerId && { customerId }),
  };

  const accessToken = generateAccessToken(payload);
  const refreshToken = generateRefreshToken(payload);

  const response = new ApiResponse(200, "Login successful", {
    accessToken,
    refreshToken,
    user: buildAuthUserPayload(user, role, {
      ...(staffId && { staffId }),
      ...(customerId && { customerId }),
      ...(staffDisplayName && { staffDisplayName }),
    }),
  });

  res.status(response.statusCode).json({
    success: response.success,
    message: response.message,
    data: response.data,
  });
});

/**
 * POST /api/v1/auth/refresh-token
 * Body: { refreshToken: "..." }
 */
export const refreshTokenController = asyncHandler(async (req, res, next) => {
  const { error, value } = refreshTokenSchema.validate(req.body, {
    stripUnknown: true,
    abortEarly: false,
  });

  if (error) {
    throw new ApiError(400, error.details.map((d) => d.message).join("; "));
  }

  const { refreshToken } = value;

  let decoded;
  try {
    decoded = verifyRefreshToken(refreshToken);
  } catch (err) {
    throw new ApiError(401, "Invalid or expired refresh token");
  }

  const user = await User.findById(decoded.userId).lean();
  if (!user) {
    throw new ApiError(401, "User not found");
  }

  // Admin is never overridden; vendor uses stored role; others use resolveRoleForPhone
  let resolved;
  if (user.role === "admin") {
    resolved = {
      role: "admin",
      ownerId: null,
      staffId: null,
      customerId: null,
    };
  } else if (user.role === "vendor") {
    resolved = {
      role: "vendor",
      ownerId: null,
      staffId: null,
      customerId: null,
    };
  } else {
    resolved = await resolveRoleForPhone(user.phone);
  }
  const role = resolved.role;
  const ownerId =
    role === "admin"
      ? null
      : role === "vendor"
        ? user._id.toString()
        : resolved.ownerId || null;
  const staffId = resolved.staffId || null;
  const customerId = resolved.customerId || null;

  let staffDisplayName = "";
  if (role === "delivery_staff") {
    staffDisplayName = await getDeliveryStaffDisplayName(user._id, staffId);
  }

  const payload = {
    userId: user._id.toString(),
    phone: user.phone,
    role,
    ...(ownerId && { ownerId }),
    ...(staffId && { staffId }),
    ...(customerId && { customerId }),
  };

  const newAccessToken = generateAccessToken(payload);
  const newRefreshToken = generateRefreshToken(payload);

  const response = new ApiResponse(200, "Tokens refreshed", {
    accessToken: newAccessToken,
    refreshToken: newRefreshToken,
    user: buildAuthUserPayload(user, role, {
      ...(staffId && { staffId }),
      ...(customerId && { customerId }),
      ...(staffDisplayName && { staffDisplayName }),
    }),
  });

  res.status(response.statusCode).json({
    success: response.success,
    message: response.message,
    data: response.data,
  });
});

/**
 * POST /api/v1/auth/logout
 * Optional: client discards tokens; no server-side invalidation for now.
 */
export const logoutController = asyncHandler(async (req, res, next) => {
  const response = new ApiResponse(200, "Logged out successfully");
  res.status(response.statusCode).json({
    success: response.success,
    message: response.message,
  });
});

/**
 * GET /api/v1/auth/me
 * Returns profile of authenticated user
 */
export const getMeController = asyncHandler(async (req, res, next) => {
  const user = await User.findById(req.user.userId).lean();
  if (!user) throw new ApiError(404, "User not found");

  let name = (user.name || user.ownerName || "").trim();
  if (user.role === "delivery_staff") {
    const staffName = await getDeliveryStaffDisplayName(
      user._id,
      req.user.staffId || null
    );
    if (staffName) name = staffName;
  }

  const response = new ApiResponse(200, "User profile", {
    id: user._id.toString(),
    phone: user.phone,
    name,
    role: user.role,
    email: user.email,
    businessName: user.businessName || "",
    ownerName: user.ownerName || "",
    address: user.address || "",
    city: user.city,
    upiId: (user.upiId || "").trim(),
    fcmToken: user.fcmToken,
    settings: user.settings,
    loginHistory: user.loginHistory || [],
  });

  res.status(response.statusCode).json(response);
});

/**
 * PUT /api/v1/auth/change-password
 * Body: { currentPassword, newPassword }
 */
export const changePasswordController = asyncHandler(async (req, res, next) => {
  const schema = Joi.object({
    currentPassword: Joi.string().min(8).required(),
    newPassword: Joi.string().pattern(passwordPattern).required().messages({
      "string.pattern.base": passwordMessage,
    }),
  });

  const { error, value } = schema.validate(req.body || {}, {
    stripUnknown: true,
    abortEarly: false,
  });
  if (
    error ||
    !value ||
    typeof value.currentPassword === "undefined" ||
    typeof value.newPassword === "undefined"
  ) {
    const msg = error
      ? error.details.map((d) => d.message).join("; ")
      : "currentPassword and newPassword are required";
    throw new ApiError(400, msg);
  }

  const user = await User.findById(req.user.userId);
  if (!user) throw new ApiError(404, "User not found");

  if (!user.passwordHash) {
    // no password set yet.
    throw new ApiError(400, "No password exists for this account");
  }

  const isValid = await securePassword.validatePassword(
    value.currentPassword,
    user.passwordHash
  );
  if (!isValid) throw new ApiError(401, "Current password incorrect");

  user.passwordHash = await securePassword.hashPassword(value.newPassword);
  await user.save();

  res
    .status(200)
    .json(new ApiResponse(200, "Password changed, please login again"));
});

/**
 * PUT /api/v1/auth/me
 * Update logged-in user's profile (fcmToken, businessName, ownerName, city, etc.)
 */
export const updateMe = asyncHandler(async (req, res) => {
  const schema = Joi.object({
    fcmToken: Joi.string().optional(),
    businessName: Joi.string().trim().optional(),
    ownerName: Joi.string().trim().optional(),
    name: Joi.string().trim().optional(),
    city: Joi.string().trim().optional(),
    address: Joi.string().trim().optional(),
    email: Joi.string().email().optional(),
    logoUrl: Joi.string().uri().optional(),
    upiId: Joi.string().trim().max(100).allow("", null).optional(),
  }).min(1);

  const { error, value } = schema.validate(req.body, {
    stripUnknown: true,
    abortEarly: false,
  });
  if (error) {
    throw new ApiError(400, error.details.map((d) => d.message).join("; "));
  }

  const updatePayload = { ...value };
  if (updatePayload.ownerName && !updatePayload.name) {
    updatePayload.name = updatePayload.ownerName;
  }
  if (updatePayload.upiId !== undefined && updatePayload.upiId !== null) {
    updatePayload.upiId = String(updatePayload.upiId).trim();
  }

  const existingUser = await User.findById(req.user.userId).select("role").lean();
  if (!existingUser) throw new ApiError(404, "User not found");
  if (existingUser.role !== "vendor") {
    delete updatePayload.upiId;
  }

  const user = await User.findByIdAndUpdate(
    req.user.userId,
    { $set: updatePayload },
    { new: true }
  ).lean();

  let responseName = (user.name || user.ownerName || "").trim();
  if (user.role === "delivery_staff") {
    if (value.name?.trim() && req.user.staffId) {
      await DeliveryStaff.findByIdAndUpdate(req.user.staffId, {
        $set: { name: value.name.trim() },
      });
    }
    responseName =
      (await getDeliveryStaffDisplayName(user._id, req.user.staffId || null)) ||
      responseName;
  }

  const response = new ApiResponse(200, "Profile updated", {
    user: {
      id: user._id.toString(),
      phone: user.phone,
      name: responseName,
      businessName: user.businessName || "",
      ownerName: user.ownerName || "",
      address: user.address || "",
      city: user.city,
      upiId: (user.upiId || "").trim(),
      fcmToken: user.fcmToken,
    },
  });

  res.status(response.statusCode).json(response);
});

/**
 * POST /api/v1/auth/vendor/onboarding
 * Idempotent: updates the same vendor user; safe to call again after completion.
 */
export const vendorOnboardingController = asyncHandler(async (req, res) => {
  const user = await User.findById(req.user.userId).lean();
  if (!user) throw new ApiError(404, "User not found");
  if (user.role !== "vendor") {
    throw new ApiError(403, "Only vendor accounts can use onboarding");
  }

  const schema = Joi.object({
    businessName: Joi.string().trim().min(1).required(),
    ownerName: Joi.string().trim().min(1).required(),
    address: Joi.string().trim().min(1).required(),
  });

  const { error, value } = schema.validate(req.body || {}, {
    stripUnknown: true,
    abortEarly: false,
  });
  if (error) {
    throw new ApiError(400, error.details.map((d) => d.message).join("; "));
  }

  const { businessName, ownerName, address } = value;
  const updated = await User.findByIdAndUpdate(
    req.user.userId,
    {
      $set: {
        businessName,
        ownerName,
        address,
        name: ownerName,
      },
    },
    { new: true }
  ).lean();

  const response = new ApiResponse(200, "Onboarding saved", {
    profileComplete: true,
    user: {
      id: updated._id.toString(),
      phone: updated.phone,
      name: updated.name || ownerName,
      businessName: updated.businessName,
      ownerName: updated.ownerName,
      address: updated.address || "",
      role: "vendor",
    },
  });

  res.status(response.statusCode).json(response);
});
