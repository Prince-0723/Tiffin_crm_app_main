import sgMail from "@sendgrid/mail";
import logger from "../utils/logger.js";
import { renderTemplate } from "./template.service.js";
import config from "../config/index.js";

// configure sendgrid once
if (process.env.SENDGRID_API_KEY) {
  sgMail.setApiKey(process.env.SENDGRID_API_KEY);
} else {
  logger.warn("SENDGRID_API_KEY is not set; emails will fail if attempted");
}

/**
 * Send an email using SendGrid and a handlebars template.
 *
 * @param {Object} opts
 * @param {string} opts.to     recipient address
 * @param {string} opts.subject
 * @param {string} opts.template  template name (without .hbs)
 * @param {Object} opts.data      data passed to the template
 */
export const sendEmail = async ({ to, subject, template, data }) => {
  // if you ever want to disable outbound mail (e.g. in dev) you can short-circuit here
  if (!process.env.SENDGRID_API_KEY) {
    logger.info("sendEmail called but API key missing; skipping", {
      to,
      subject,
    });
    return { success: false, error: "missing api key" };
  }

  // render HTML body
  let html;
  try {
    html = await renderTemplate(template, data);
  } catch (err) {
    logger.error("failed to render email template", { template, err });
    return { success: false, error: err.message };
  }

  const msg = {
    to,
    from: process.env.FROM_EMAIL || "noreply@tiffincrm.com",
    subject,
    html,
  };

  // simple retry: try twice before giving up
  for (let attempt = 1; attempt <= 2; attempt++) {
    try {
      await sgMail.send(msg);
      logger.info("email sent", { to, subject, template, attempt });
      return { success: true };
    } catch (error) {
      logger.error("Email send failed", {
        to,
        subject,
        template,
        attempt,
        error: error.message,
      });
      if (attempt === 2) {
        return { success: false, error: error.message };
      }
      // otherwise loop and retry immediately
    }
  }
};
