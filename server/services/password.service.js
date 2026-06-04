import crypto from "crypto";
import User from "../models/User.model.js";
import PasswordReset from "../models/PasswordReset.model.js";
import { ApiError } from "../class/apiErrorClass.js";
import * as securePassword from "./securePassword.service.js";

const TOKEN_SIZE_BYTES = 32; // 256 bits
const RESET_TOKEN_EXPIRY_MS = 10 * 60 * 1000; // 10 minutes

/**
 * Hash a plain text token using SHA256 so we never store the raw token.
 *
 * @param {string} token
 * @returns {string} hex digest
 */
const hashToken = (token) => {
  return crypto.createHash("sha256").update(token).digest("hex");
};

// export password helpers for backward compatibility
export const hashPassword = securePassword.hashPassword;
export const validatePassword = securePassword.validatePassword;

/**
 * Generate a password reset token for the given user and store
 * a hashed copy in the database.
 *
 * @param {mongoose.Types.ObjectId} userId
 * @returns {Promise<string>} the plain token to send to the user
 */
export const generateResetToken = async (userId) => {
  const plainToken = crypto.randomBytes(TOKEN_SIZE_BYTES).toString("hex");
  const hashed = hashToken(plainToken);

  const expiresAt = new Date(Date.now() + RESET_TOKEN_EXPIRY_MS);

  await PasswordReset.create({
    userId,
    resetToken: hashed,
    expiresAt,
  });

  return plainToken;
};

/**
 * Validate a reset token and return the corresponding PasswordReset doc
 * if it is still valid (not expired, not used).
 *
 * @param {string} token
 * @returns {Promise<PasswordReset|null>}
 */
export const validateResetToken = async (token) => {
  const hashed = hashToken(token);
  const record = await PasswordReset.findOne({
    resetToken: hashed,
    usedAt: null,
    expiresAt: { $gt: new Date() },
  });
  return record;
};

/**
 * Consume a reset token, update the user's password and mark token as used.
 * Returns the updated user document (lean).
 *
 * @param {string} token
 * @param {string} newPassword
 * @returns {Promise<User>} updated user
 */
export const resetPassword = async (token, newPassword) => {
  const record = await validateResetToken(token);
  if (!record) {
    throw new ApiError(400, "Invalid or expired password reset token");
  }

  const user = await User.findById(record.userId);
  if (!user) {
    throw new ApiError(404, "User not found");
  }

  // set hashed password field on user
  user.passwordHash = await hashPassword(newPassword);
  await user.save();

  record.usedAt = new Date();
  await record.save();

  return user;
};
