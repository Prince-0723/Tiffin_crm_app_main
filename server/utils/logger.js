import winston from "winston";
import fs from "fs";
import path from "path";

const logDir = path.resolve("logs");
if (!fs.existsSync(logDir)) {
  fs.mkdirSync(logDir, { recursive: true });
}

const secretKeys = [
  "token",
  "access_token",
  "refresh_token",
  "password",
  "secret",
  "jwt",
];

function redactSecrets(info) {
  if (typeof info !== "object" || info === null) return info;
  const output = { ...info };
  for (const key of Object.keys(output)) {
    if (
      secretKeys.some(
        (secretKey) =>
          key.toLowerCase().includes(secretKey) && typeof output[key] === "string"
      )
    ) {
      output[key] = "[REDACTED]";
    }
    // If value is object, recurse
    if (typeof output[key] === "object" && output[key] !== null) {
      output[key] = redactSecrets(output[key]);
    }
  }
  return output;
}

// Custom formatter to redact secrets from log message and meta
const redactFormat = winston.format((info) => {
  // Redact secrets in the message string or object
  if (typeof info.message === "object") {
    info.message = redactSecrets(info.message);
  }
  if (typeof info === "object") {
    for (const key in info) {
      if (key !== "level" && key !== "timestamp" && key !== "message") {
        info[key] = redactSecrets(info[key]);
      }
    }
  }
  if (typeof info.message === "string") {
    // Redact message strings containing secrets
    secretKeys.forEach((secretKey) => {
      const regex = new RegExp(`${secretKey}\\s*[:=]\\s*[^\\s,;]+`, "gi");
      info.message = info.message.replace(regex, `${secretKey}: [REDACTED]`);
    });
  }
  return info;
});

const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || "info",
  format: winston.format.combine(
    redactFormat(),
    winston.format.timestamp(),
    winston.format.printf(
      (info) =>
        `${info.timestamp} [${info.level}] : ${
          typeof info.message === "string"
            ? info.message
            : JSON.stringify(info.message)
        }`
    )
  ),
  transports: [
    new winston.transports.Console(),
    new winston.transports.File({ filename: path.join(logDir, "combined.log") }),
  ],
});

export default logger;