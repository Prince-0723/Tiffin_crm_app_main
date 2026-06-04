# Backend Flow Comparison: Current vs Correct System Flow

> **Status as of Mar 17, 2026 — Backend is aligned with CORRECT_SYSTEM_FLOW.**
> All gaps identified in the Mar 11 review have been closed across Days 1–7.

---

## Summary Table

| Area                    | Target Flow                                                              | Status (Mar 17, 2026)                                                                            |
| ----------------------- | ------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------ |
| Roles                   | Admin, Vendor, Customer, Delivery Boy — all login via phone + OTP        | ✅ Aligned                                                                                        |
| Auth                    | Phone + OTP → JWT with role, ownerId, customerId, staffId                | ✅ Aligned — `customerId` + `staffId` added to JWT (Day 6)                                        |
| Admin                   | Full access; does not create vendors; vendors self-register              | ✅ `GET /admin/vendors` added (Day 6); vendors self-register via OTP                              |
| Vendor self-register    | Vendor creates and logs in with own phone                                | ✅ Aligned                                                                                        |
| Customer management     | Manual + bulk import from contacts; CRUD by vendor                       | ✅ Aligned — CRUD, bulk, wallet credit, soft-delete, `lowBalance=true` filter, `whatsappUrl`     |
| Item catalog            | Vendor defines daily items with prices (Roti ₹5, Sabji ₹20, etc.)       | ✅ Item model + CRUD (`GET/POST/PUT/DELETE /items`)                                               |
| Meal plan structure     | Plan has meal slots with items + quantities                              | ✅ `MealPlan.mealSlots[{slot, items[{itemId, quantity}]}]` — validated against Item catalog       |
| Plan assignment         | Vendor assigns plan → daily orders auto-generated                        | ✅ Subscription create → `generateDailyOrdersForDate` + nightly cron                             |
| Customer meal edit      | Customer edits quantities only (no add/remove)                          | ✅ `PATCH /daily-orders/:id/quantities` (customer role, Day 6)                                   |
| DailyOrder generation   | Auto daily, cron + on assignment create                                  | ✅ Cron midnight + on subscription create + `generate-week` endpoint                             |
| DailyOrder resolvedItems| Items + prices snapshotted at generation time                            | ✅ `buildResolvedItems` in `dailyOrder.service.js` fetches live prices on generation              |
| Order lifecycle         | `pending → processing → out_for_delivery → delivered`                   | ✅ `PATCH /:id/status` (Day 3); all timestamps set                                               |
| Out for delivery        | Delivery boy marks it; customer + vendor notified                        | ✅ `PATCH /:id/status { status: "out_for_delivery" }` + FCM + Notification docs                  |
| Process orders          | Lock orders, notify customers                                            | ✅ `POST /process` → FCM + Notification docs per customer (Day 5)                                |
| Delivery boy accept/reject | Staff accepts or rejects; rejection notifies vendor                   | ✅ `POST /:id/accept` + `POST /:id/reject` + FCM/Notification to vendor (Day 3)                  |
| Delivery assignment     | Vendor assigns delivery boy; staff gets FCM notification                 | ✅ `PATCH /:id/assign` + `POST /assign-bulk` + FCM + Notification doc via `staff.userId` (Day 7)|
| Delivery boy "my deliveries" | Staff sees only his assigned orders for today                      | ✅ `GET /delivery/my-deliveries` scoped to `deliveryStaffId` (Day 3)                             |
| Wallet / balance        | Vendor adds balance; auto-deduct after delivery                          | ✅ `POST /customers/:id/wallet/credit` + atomic deduction in `updateOrderStatus` + `markDelivered`|
| Low balance             | Notify customer + vendor; vendor sees low-balance list; WhatsApp button  | ✅ Threshold in `User.settings.lowBalanceThreshold`; FCM + Notification after every delivery; `GET /customers?lowBalance=true` + `whatsappUrl` (Day 5)|
| WhatsApp integration    | Click customer phone → opens WhatsApp                                    | ✅ `whatsappUrl` returned on every customer object in list and delivery responses                  |
| Delivery tracking       | Delivery boy GPS → vendor sees on Google Maps                            | ✅ Socket.IO `/delivery` namespace; `location_update` event                                       |
| Customer app            | Login, plan, orders, balance, edit quantities, pause                     | ✅ `GET/PUT /customer/me`, `GET /customer/me/plan`, `GET /customer/me/orders`, `PATCH /:id/quantities`, `PUT /subscriptions/:id/pause|unpause` (Days 5–6)|
| Notifications           | All events covered; type constants                                       | ✅ `utils/notificationTypes.js` constants; all 8 event types produce FCM + Notification docs (Day 5)|
| Payments                | Offline + Razorpay; captured status; revenue report fixed                | ✅ `Payment.status` enum; manual captured on create; Razorpay webhook sets captured; revenue report scoped by ownerId (Days 2–4)|
| Reports                 | Today deliveries, active plans, revenue, pending payments, expiring plans | ✅ 4 report endpoints (`/summary`, `/today-deliveries`, `/expiring-subscriptions`, `/pending-payments`) (Day 4)|
| Pause subscription      | Customer/vendor pauses; orders skipped                                   | ✅ `PUT /subscriptions/:id/pause|unpause`; `generateDailyOrdersForDate` skips paused date range (Day 4)|
| Indexes                 | Queries covered by indexes                                               | ✅ Added `{ownerId, balance}` on Customer; verified Payment + DailyOrder indexes (Day 6)         |

---

## Full Flow — Smoke Test (Mar 17, 2026)

| Step | Action | Endpoint | Status |
|------|--------|----------|--------|
| 1  | Vendor self-registers via OTP | `POST /auth/send-otp` → `POST /auth/verify-otp` | ✅ |
| 2  | Vendor creates Item catalog (Roti ₹5, Sabji ₹20, Dal ₹25) | `POST /items` × 3 | ✅ |
| 3  | Vendor creates Meal Plan (Lunch: 4 Roti + 1 Sabji + 1 Dal) | `POST /plans` | ✅ |
| 4  | Vendor adds Customer | `POST /customers` | ✅ |
| 5  | Vendor assigns Plan to Customer (start/end date) | `POST /subscriptions` | ✅ |
| 6  | Daily Order generated with resolvedItems + amount (₹65) | auto via service | ✅ |
| 7  | Vendor adds ₹1000 balance | `POST /customers/:id/wallet/credit` | ✅ |
| 8  | Customer logs in, sees plan, edits quantities (5 Roti → ₹70) | `POST /auth/verify-otp` → `GET /customer/me/plan` → `PATCH /daily-orders/:id/quantities` | ✅ |
| 9  | Vendor processes orders → status: processing; customer gets FCM + Notification | `POST /daily-orders/process` | ✅ |
| 10 | Vendor assigns Delivery Boy → staff gets FCM + Notification | `PATCH /daily-orders/:id/assign` | ✅ |
| 11 | Delivery Boy accepts task → vendor notified | `POST /daily-orders/:id/accept` | ✅ |
| 12 | Delivery Boy marks out_for_delivery → vendor + customer notified | `PATCH /daily-orders/:id/status { status: "out_for_delivery" }` | ✅ |
| 13 | Delivery Boy marks delivered | `PATCH /daily-orders/:id/status { status: "delivered" }` | ✅ |
| 14 | Customer balance auto-deducted (₹1000 − ₹70 = ₹930) | auto in delivered handler | ✅ |
| 15 | If balance < threshold (100) → customer + vendor get low balance FCM | auto in delivered handler | ✅ |
| 16 | Check reports | `GET /reports/today-deliveries`, `/expiring-subscriptions`, `/pending-payments` | ✅ |
| 17 | Vendor pauses customer plan for vacation dates | `PUT /subscriptions/:id/pause { pausedFrom, pausedUntil }` | ✅ |
| 18 | No DailyOrder generated for paused dates | `POST /daily-orders/generate { date }` → generatedCount: 0 | ✅ |

---

## Notification Coverage (All Events)

| Event                | FCM  | Notification Doc | Type Constant           |
|----------------------|------|------------------|-------------------------|
| Order processing     | ✅   | ✅               | `ORDER_PROCESSING`      |
| Out for delivery     | ✅   | ✅               | `OUT_FOR_DELIVERY`      |
| Order delivered      | ✅   | ✅               | `DELIVERED`             |
| Task assigned (staff)| ✅   | ✅               | `TASK_ASSIGNED`         |
| Task accepted        | ✅   | ✅               | `TASK_ACCEPTED`         |
| Task rejected        | ✅   | ✅               | `TASK_REJECTED`         |
| Low balance          | ✅   | ✅               | `LOW_BALANCE`           |
| Plan expiring        | ✅   | ✅               | `PLAN_EXPIRING`         |

---

## API Surface (Complete)

### Auth (`/api/v1/auth`)
- `POST /send-otp`, `POST /verify-otp`, `POST /truecaller`
- `POST /refresh-token`, `POST /logout`
- `GET /me`, `PUT /me`
- `PUT /change-password`, `POST /forgot-password`, `POST /reset-password`

### Vendor APIs (require `vendor` or `admin` role)
- **Items**: `GET/POST /items`, `GET/PUT/DELETE /items/:id`
- **Plans**: `GET/POST /plans`, `GET/PUT/DELETE /plans/:id`
- **Customers**: `GET/POST /customers`, `GET/PUT/DELETE /customers/:id`, `POST /customers/bulk`, `POST /customers/:id/wallet/credit`
- **Subscriptions**: `GET/POST /subscriptions`, `GET /subscriptions/:id`, `PUT /subscriptions/:id/renew|cancel|pause|unpause`
- **Daily Orders**: `GET /daily-orders/today`, `POST /process|mark-delivered|generate|generate-week|assign-bulk`, `PATCH /:id/assign|status`
- **Delivery Staff**: `GET/POST /delivery-staff`, `GET/PUT/DELETE /delivery-staff/:id`
- **Delivery**: `GET /delivery` (all today's orders)
- **Payments**: `GET/POST /payments`, `POST /payments/create-order`
- **Invoices**: full CRUD + share + void
- **Reports**: `GET /reports/summary|today-deliveries|expiring-subscriptions|pending-payments`
- **Notifications**: `POST /notifications/test`

### Customer Portal (require `customer` role)
- `GET/PUT /customer/me`
- `GET /customer/me/plan`, `GET /customer/me/orders`
- `PATCH /daily-orders/:id/quantities`
- `PUT /subscriptions/:id/pause|unpause`

### Delivery Staff (require `delivery_staff` role)
- `GET /delivery/my-deliveries`
- `PATCH /daily-orders/:id/status` (out_for_delivery, delivered)
- `POST /daily-orders/:id/accept|reject`

### Admin (require `admin` role)
- `GET /admin/vendors`

### Public / Webhooks
- `POST /webhooks/razorpay`
- `GET /public/*` (share token links)

---

_Updated: Mar 17, 2026. Backend aligned with CORRECT_SYSTEM_FLOW._
