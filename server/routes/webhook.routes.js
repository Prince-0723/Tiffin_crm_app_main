import { Router } from "express";
import express from "express";
import { razorpayWebhook } from "../controllers/webhook.controller.js";

const router = Router();

router.post(
  "/razorpay",
  express.raw({ type: "application/json" }),
  razorpayWebhook
);

export default router;
