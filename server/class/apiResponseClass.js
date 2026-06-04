import { validateStatusCode, isSuccessfulStatusCode } from "./statusCode.js";

class ApiResponse {
  constructor(statusCode, message = "Success", data = null) {
    this.statusCode = validateStatusCode(statusCode);
    this.message = message;
    this.data = data;
    this.success = isSuccessfulStatusCode(statusCode);
  }
}

export { ApiResponse };
