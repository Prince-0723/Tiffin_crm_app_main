import express from "express";
import cors from "cors";
import helmet from "helmet";
import morgan from "morgan";
import rateLimit from "express-rate-limit";
import mongoose from "mongoose";

import config from "./config/index.js";
import requestId from "./middleware/requestId.js";
import { errorHandler } from "./middleware/errorHandler.js";
import routes from "./routes/index.js";
import customerDetailsRoutes from "./routes/customerDetails.js";
import webhookRoutes from "./routes/webhook.routes.js";
import publicRoutes from "./routes/public.routes.js";

const app = express();

// CORS first so preflight (OPTIONS) and all responses get correct headers
const isLocalOrigin = (o) =>
  !o || /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/i.test(o);
app.use(
  cors({
    origin: (origin, callback) => {
      if (isLocalOrigin(origin)) return callback(null, true);
      if (config.CORS_ORIGIN && config.CORS_ORIGIN !== "*") {
        const allowed =
          Array.isArray(config.CORS_ORIGIN)
            ? config.CORS_ORIGIN.includes(origin)
            : config.CORS_ORIGIN === origin;
        return callback(null, allowed ? origin : false);
      }
      callback(null, true);
    },
    methods: ["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"],
    allowedHeaders: ["Content-Type", "Authorization", "Accept"],
    credentials: false,
    optionsSuccessStatus: 204,
  })
);

app.use(helmet());

app.get("/health", (req, res) => {
  const dbConnected = mongoose.connection.readyState === 1;
  res.status(dbConnected ? 200 : 503).json({
    status: dbConnected ? "ok" : "degraded",
    uptime: process.uptime(),
    db: dbConnected ? "connected" : "disconnected",
  });
});

app.use(rateLimit(config.RATE_LIMIT));

app.use("/api/v1/webhooks", webhookRoutes);

app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(requestId);
app.use(morgan("combined"));
app.use("/public", express.static("public"));

app.use("/api/v1/public", publicRoutes);
app.use("/api/v1/customer-details", customerDetailsRoutes);
app.use("/api/v1", routes);

app.use(errorHandler);

export { app };
