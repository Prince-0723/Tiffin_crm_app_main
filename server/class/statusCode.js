const validateStatusCode = (statusCode) => {
  const validStatusCodes = [
    200, 201, 204, 400, 401, 403, 404, 409, 410, 429, 500, 502, 503,
  ];
  if (!Number.isInteger(statusCode) || !validStatusCodes.includes(statusCode)) {
    throw new TypeError(
      "statusCode must be a valid HTTP status code (100-599)"
    );
  }
  return statusCode;
};

const isSuccessfulStatusCode = (statusCode) => {
  const validStatusCodes = [200, 201, 204];
  return validStatusCodes.includes(statusCode);
};

export { validateStatusCode, isSuccessfulStatusCode };
