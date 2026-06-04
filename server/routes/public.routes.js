import { Router } from "express";
import mongoose from "mongoose";
import Invoice from "../models/Invoice.model.js";
import Customer from "../models/Customer.model.js";
import User from "../models/User.model.js";
import { ApiError } from "../class/apiErrorClass.js";
import { asyncHandler } from "../utils/asyncHandler.js";

const router = Router();

router.get("/health", (req, res) => {
  res.json({ status: "ok", version: "4.0" });
});

router.get(
  "/invoice/:shareToken",
  asyncHandler(async (req, res) => {
    const { shareToken } = req.params;
    const invoice = await Invoice.findOne({ shareToken })
      .select("-shareToken -shareTokenExpiresAt -ownerId")
      .lean();
    if (!invoice) throw new ApiError(404, "Invoice not found");
    if (
      invoice.shareTokenExpiresAt &&
      invoice.shareTokenExpiresAt.getTime() < Date.now()
    ) {
      throw new ApiError(410, "TOKEN_EXPIRED");
    }
    res.json(invoice);
  })
);

/**
 * Public: vendor portal announcement for imeals.in / marketing pages (no auth).
 * GET /api/v1/public/vendor/:ownerId/portal-announcement
 */
router.get(
  "/vendor/:ownerId/portal-announcement",
  asyncHandler(async (req, res) => {
    const { ownerId } = req.params;
    if (!mongoose.Types.ObjectId.isValid(ownerId)) {
      throw new ApiError(400, "Invalid vendor id");
    }
    const user = await User.findById(ownerId)
      .select(
        "role businessName ownerName settings.portalAnnouncementText settings.portalAnnouncementUpdatedAt"
      )
      .lean();
    if (!user || user.role !== "vendor") {
      throw new ApiError(404, "Vendor not found");
    }
    res.json({
      businessName: (user.businessName || "").trim(),
      ownerName: (user.ownerName || "").trim(),
      text: (user.settings?.portalAnnouncementText ?? "").trim(),
      updatedAt: user.settings?.portalAnnouncementUpdatedAt ?? null,
    });
  })
);

router.get(
  "/customer-report/:token",
  asyncHandler(async (req, res) => {
    const { token } = req.params;
    const customer = await Customer.findOne({ reportToken: token })
      .select("name phone address area balance totalDue tags notes")
      .lean();
    if (!customer) throw new ApiError(404, "Customer not found");
    if (
      customer.reportTokenExpiresAt &&
      customer.reportTokenExpiresAt.getTime() < Date.now()
    ) {
      throw new ApiError(410, "TOKEN_EXPIRED");
    }
    res.json(customer);
  })
);

export default router;

