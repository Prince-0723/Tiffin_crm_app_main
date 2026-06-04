import jwt from "jsonwebtoken";
import config from "../config/index.js";

const ACCESS_TOKEN_EXPIRY = config.JWT_ACCESS_EXPIRY || "15m";
const REFRESH_TOKEN_EXPIRY = config.JWT_REFRESH_EXPIRY || "7d";

/**
 * Generate access token (short-lived)
 * @param {Object} payload - { userId, phone }
 * @returns {string} JWT access token
 */
export const generateAccessToken = (payload) => {
  return jwt.sign(payload, config.JWT_ACCESS_SECRET, {
    expiresIn: ACCESS_TOKEN_EXPIRY,
  });
};

/**
 * Generate refresh token (long-lived)
 * @param {Object} payload - { userId, phone }
 * @returns {string} JWT refresh token
 */
export const generateRefreshToken = (payload) => {
  return jwt.sign(payload, config.JWT_REFRESH_SECRET, {
    expiresIn: REFRESH_TOKEN_EXPIRY,
  });
};

/**
 * Verify access token
 * @param {string} token - JWT access token
 * @returns {Object} decoded payload { userId, phone, iat, exp }
 */
export const verifyAccessToken = (token) => {
  return jwt.verify(token, config.JWT_ACCESS_SECRET);
};

/**
 * Verify refresh token
 * @param {string} token - JWT refresh token
 * @returns {Object} decoded payload { userId, phone, iat, exp }
 */
export const verifyRefreshToken = (token) => {
  return jwt.verify(token, config.JWT_REFRESH_SECRET);
};
