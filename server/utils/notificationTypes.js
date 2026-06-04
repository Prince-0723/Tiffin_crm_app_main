export const NOTIFICATION_TYPES = {
  SUBSCRIPTION_ACTIVATED: "subscription_activated",
  // Fired a few days before expiry (future pre-expiry warning)
  PLAN_EXPIRING: "plan_expiring",
  // Fired by the cron when a subscription has already expired
  SUBSCRIPTION_EXPIRED: "subscription_expired",
  ORDER_PROCESSING: "order_processing",
  OUT_FOR_DELIVERY: "out_for_delivery",
  DELIVERED: "delivered",
  TASK_ASSIGNED: "task_assigned",
  TASK_ACCEPTED: "task_accepted",
  TASK_REJECTED: "task_rejected",
  LOW_BALANCE: "low_balance",
  /** Vendor broadcast to all portal customers */
  VENDOR_ANNOUNCEMENT: "vendor_announcement",
};
