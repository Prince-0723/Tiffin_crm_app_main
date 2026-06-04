import bcrypt from "bcryptjs";

const SALT_ROUNDS = 10;

/**
 * Hash a plain password string.
 * @param {string} password
 * @returns {Promise<string>} bcrypt hash
 */
export const hashPassword = async (password) => {
  return bcrypt.hash(password, SALT_ROUNDS);
};

/**
 * Compare a plain password against a stored hash.
 * @param {string} password
 * @param {string} hash
 * @returns {Promise<boolean>}
 */
export const validatePassword = async (password, hash) => {
  return bcrypt.compare(password, hash);
};
