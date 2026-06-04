import { validateStatusCode } from "./statusCode.js";

class ApiError extends Error {
  constructor(statusCode, message = "Something went wrong", errors = []) {
    super(message);
    this.statusCode = validateStatusCode(statusCode);
    this.errors = errors;
    this.data = null;
    this.success = false;
    Error.captureStackTrace(this, this.constructor);
  }
}
export { ApiError };
