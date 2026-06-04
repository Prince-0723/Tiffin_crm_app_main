import fs from "fs/promises";
import { createWriteStream } from "fs";
import path from "path";
import { fileURLToPath } from "url";
import PDFDocument from "pdfkit";
import Payment from "../models/Payment.model.js";
import config from "../config/index.js";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const INVOICES_DIR = path.join(__dirname, "../public/invoices");

const ensureDir = async () => {
  await fs.mkdir(INVOICES_DIR, { recursive: true });
};

/**
 * Generate invoice PDF for a payment.
 * Saves to public/invoices/{paymentId}.pdf (or uploads to Cloudinary if configured).
 * @param {string} paymentId - MongoDB Payment _id
 * @returns {Promise<string>} Public URL to the invoice
 */

export const generateInvoice = async (paymentId) => {
  const payment = await Payment.findById(paymentId)
    .populate("customerId", "name phone address")
    .populate("subscriptionId", "planId startDate endDate")
    .populate("subscriptionId.planId", "name price frequency")
    .lean();

  if (!payment) {
    throw new Error("Payment not found");
  }

  await ensureDir();

  const fileName = `${paymentId}.pdf`;
  const filePath = path.join(INVOICES_DIR, fileName);

  const fileExists = await fs
    .access(filePath)
    .then(() => true)
    .catch(() => false);

  if (fileExists && payment.invoiceUrl) {
    return payment.invoiceUrl;
  }

  const customer = payment.customerId;
  const subscription = payment.subscriptionId;
  const plan = subscription?.planId;

  return new Promise((resolve, reject) => {
    const doc = new PDFDocument({ margin: 50, size: "A4" });
    const writeStream = createWriteStream(filePath);
    doc.pipe(writeStream);

    doc.fontSize(24).text("Invoice", { align: "center" });
    doc.moveDown();
    doc.fontSize(10).text(`Invoice #${paymentId}`, { align: "right" });
    doc.text(`Date: ${new Date(payment.createdAt).toLocaleDateString()}`, {
      align: "right",
    });
    doc.moveDown(2);

    doc.fontSize(12).text("Bill To:", { underline: true });
    doc.fontSize(10);
    doc.text(customer?.name || "—");
    doc.text(customer?.address || "—");
    doc.text(customer?.phone ? `Phone: ${customer.phone}` : "");
    doc.moveDown(2);

    doc.fontSize(12).text("Payment Details", { underline: true });
    doc.fontSize(10);
    doc.text(`Amount: ₹${payment.amount}`);
    doc.text(`Method: ${payment.method}`);
    doc.text(`Status: ${payment.status}`);
    if (plan) {
      doc.text(`Plan: ${plan.name || "—"}`);
    }
    doc.moveDown(2);

    doc.fontSize(10).text("Thank you for your payment!", { align: "center" });

    doc.end();

    writeStream.on("finish", async () => {
      const baseUrl = process.env.BASE_URL || `http://localhost:${config.PORT}`;
      const invoiceUrl = `${baseUrl}/public/invoices/${fileName}`;

      await Payment.findByIdAndUpdate(paymentId, {
        $set: { invoiceUrl },
      });

      resolve(invoiceUrl);
    });
    writeStream.on("error", reject);
  });
};
