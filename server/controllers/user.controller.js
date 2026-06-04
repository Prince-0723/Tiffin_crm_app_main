// import Joi from "joi";
// import { asyncHandler } from "../utils/asyncHandler.js";
// import { ApiError } from "../class/apiErrorClass.js";
// import User from "../models/User.model.js";
// import Customer from "../models/Customer.model.js";

// /**
//  * PUT /api/v1/users/fcm-token
//  * Body: { fcmToken: string | null }
//  */
// export const updateFcmToken = asyncHandler(async (req, res) => {
//   const schema = Joi.object({
//     fcmToken: Joi.string().allow(null, "").optional(),
//   });

//   const { error, value } = schema.validate(req.body || {}, {
//     stripUnknown: true,
//     abortEarly: false,
//   });
//   if (error) {
//     throw new ApiError(400, error.details.map((d) => d.message).join("; "));
//   }

//   const fcmToken = value.fcmToken ?? null;

//   if (req.user.role === "customer" && req.user.customerId) {
//     await Customer.findByIdAndUpdate(req.user.customerId, {
//       $set: { fcmToken },
//     });
//   } else {
//     await User.findByIdAndUpdate(req.user.userId, { $set: { fcmToken } });
//   }

//   res.status(200).json({ success: true });
// });
import Joi from "joi";
import mongoose from "mongoose";
import { asyncHandler } from "../utils/asyncHandler.js";
import { ApiError } from "../class/apiErrorClass.js";
import { ApiResponse } from "../class/apiResponseClass.js";
import User from "../models/User.model.js";
import Customer from "../models/Customer.model.js";
import Notification from "../models/Notification.model.js";
import { sendNotification } from "../services/inAppNotification.service.js";
import { NOTIFICATION_TYPES } from "../utils/notificationTypes.js";

/**
 * PUT /api/v1/users/fcm-token
 * Body: { fcmToken: string | null }
 */
export const updateFcmToken = asyncHandler(async (req, res) => {
  const schema = Joi.object({
    fcmToken: Joi.string().allow(null, "").optional(),
  });

  const { error, value } = schema.validate(req.body || {}, {
    stripUnknown: true,
    abortEarly: false,
  });
  if (error) {
    throw new ApiError(400, error.details.map((d) => d.message).join("; "));
  }

  const fcmToken = value.fcmToken ?? null;

  if (req.user.role === "customer") {
    if (req.user.customerId) {
      await Customer.findByIdAndUpdate(req.user.customerId, {
        $set: { fcmToken },
      });
    } else {
      // Fallback: phone se Customer dhundho
      const user = await User.findById(req.user.userId).select("phone").lean();
      if (user?.phone) {
        await Customer.findOneAndUpdate(
          { phone: user.phone, isDeleted: { $ne: true } },
          { $set: { fcmToken } }
        );
      }
    }
    // User model bhi update karo
    await User.findByIdAndUpdate(req.user.userId, { $set: { fcmToken } });
  } else {
    await User.findByIdAndUpdate(req.user.userId, { $set: { fcmToken } });
  }

  res.status(200).json({ success: true });
});

const portalAnnouncementPutSchema = Joi.object({
  text: Joi.string().trim().max(5000).allow("").required(),
  notifyAllCustomers: Joi.boolean().default(false),
});

/**
 * GET /api/v1/users/portal-announcement
 * Vendor: current announcement text for the customer portal / imeals.in.
 */
export const getPortalAnnouncement = asyncHandler(async (req, res) => {
  const userId = req.user.userId;
  const user = await User.findById(userId)
    .select("settings.portalAnnouncementText settings.portalAnnouncementUpdatedAt businessName")
    .lean();
  if (!user) throw new ApiError(404, "User not found");

  const text = user.settings?.portalAnnouncementText ?? "";
  const updatedAt = user.settings?.portalAnnouncementUpdatedAt ?? null;

  res.status(200).json(
    new ApiResponse(200, "Portal announcement fetched", {
      text,
      updatedAt,
    })
  );
});

/**
 * PUT /api/v1/users/portal-announcement
 * Body: { text, notifyAllCustomers?: boolean }
 * Saves announcement; optionally notifies all customers (push + in-app notification per customer).
 */
export const updatePortalAnnouncement = asyncHandler(async (req, res) => {
  const { error, value } = portalAnnouncementPutSchema.validate(req.body, {
    stripUnknown: true,
    abortEarly: false,
  });
  if (error) {
    throw new ApiError(400, error.details.map((d) => d.message).join("; "));
  }

  const ownerId = req.user.userId;
  const now = new Date();

  const updated = await User.findByIdAndUpdate(
    ownerId,
    {
      $set: {
        "settings.portalAnnouncementText": value.text,
        "settings.portalAnnouncementUpdatedAt": now,
      },
    },
    { new: true }
  )
    .select("settings.portalAnnouncementText settings.portalAnnouncementUpdatedAt businessName ownerName")
    .lean();

  if (!updated) throw new ApiError(404, "User not found");

  let notifiedCount = 0;
  if (value.notifyAllCustomers && value.text.trim().length > 0) {
    const customers = await Customer.find({
      ownerId: new mongoose.Types.ObjectId(ownerId),
      isDeleted: { $ne: true },
    })
      .select("_id")
      .lean();

    const title =
      (updated.businessName || "").trim() ||
      (updated.ownerName || "").trim() ||
      "Announcement";
    const pushPreview =
      value.text.length > 180 ? `${value.text.slice(0, 177)}...` : value.text;

    // One in-app row per customer per save: same revision for this broadcast.
    // Removes any partial duplicate for this customer+revision before insert.
    const portalRevision = new Date(
      updated.settings?.portalAnnouncementUpdatedAt || now
    ).toISOString();

    for (const c of customers) {
      await Notification.deleteMany({
        customerId: c._id,
        type: NOTIFICATION_TYPES.VENDOR_ANNOUNCEMENT,
        "data.portalRevision": portalRevision,
      });
      await sendNotification({
        customerId: c._id,
        ownerId,
        type: NOTIFICATION_TYPES.VENDOR_ANNOUNCEMENT,
        title,
        message: value.text,
        pushBody: pushPreview,
        data: {
          screen: "announcement",
          portalRevision,
        },
      }).catch(() => null);
    }
    notifiedCount = customers.length;
  }

  res.status(200).json(
    new ApiResponse(200, "Portal announcement saved", {
      text: updated.settings?.portalAnnouncementText ?? "",
      updatedAt: updated.settings?.portalAnnouncementUpdatedAt ?? null,
      notifiedCount: value.notifyAllCustomers ? notifiedCount : 0,
    })
  );
});