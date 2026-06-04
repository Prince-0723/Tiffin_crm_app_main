const asyncHandler = (requestHandler) => {
  if (typeof requestHandler !== "function") {
    throw new TypeError("requestHandler must be a function");
  }
  return async (req, res, next) => {
    try {
      await requestHandler(req, res, next);
    } catch (err) {
      next(err);
    }
  };
};

export { asyncHandler };
