import crypto from "crypto";

const requestId = (req, res, next) => {
  let id = req.headers["x-request-id"];
  if (!id) {
    if (crypto.randomUUID) {
      id = crypto.randomUUID();
    } else {
      id = `${Date.now()}-${Math.floor(Math.random() * 1e9)}`;
    }
  }
  req.id = id;
  next();
};

export default requestId;