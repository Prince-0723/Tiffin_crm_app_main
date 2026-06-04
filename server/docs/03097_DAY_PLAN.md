# Backend Implementation Plan — Mar 11 → Mar 17, 2026

**Goal:** Complete backend aligned with [0309CORRECT_SYSTEM_FLOW.md](./0309CORRECT_SYSTEM_FLOW.md), based on gaps from [0309BACKEND_FLOW_COMPARISON.md](./0309BACKEND_FLOW_COMPARISON.md), using [0309MODULE_WISE_IMPLEMENTATION_PLAN.md](./0309MODULE_WISE_IMPLEMENTATION_PLAN.md).

**Key rules:**
1. Admin does **not** create vendor — vendor self-registers with own phone.
2. **Subscription plans removed** (no free/basic/premium tiers).
3. Vendor assigns pre-created or custom meal plan to customer.
4. Customer edits vendor-provided meal plan **quantities only** (no add/remove items).
5. Delivery boy can **accept or reject** assigned task.

**Status today (Mar 11):** Phase 1 (RBAC + Auth + Config) is ✅ complete. Phase 2 onward is ❌ not started.

---

## Timeline Overview

| Day | Date        | Focus                                  | Deliverable                                        | Status |
|-----|-------------|----------------------------------------|----------------------------------------------------|--------|
| —   | Sun Mar 9   | ~~RBAC + Config~~                      | ~~Roles in JWT, requireRole, config~~ **Done ✅**  | ✅ Done |
| —   | Mon Mar 10  | ~~Wallet + Deduct~~                    | ~~Wallet credit, deduct on delivery~~ **Not done** | ❌ Carried forward |
| 1   | Tue Mar 11  | Item Catalog + MealPlan Redesign       | Item model, plan with items+quantities             | 🔥 Today |
| 2   | Wed Mar 12  | Wallet + Balance + Delivery Lifecycle  | Add balance, deduct on delivery, out-for-delivery API | 🔲 |
| 3   | Thu Mar 13  | Delivery Boy APIs                      | Assign, accept/reject, my-deliveries               | 🔲 |
| 4   | Fri Mar 14  | Pause + Reports + Payment fix          | Pause/unpause, fix revenue, new reports            | 🔲 |
| 5   | Sat Mar 15  | Low Balance + Notifications complete   | Low balance FCM, notification constants, webhook   | 🔲 |
| 6   | Sun Mar 16  | Customer APIs + Polish                 | Customer-facing endpoints, indexes, validation     | 🔲 |
| —   | Mon Mar 17  | **Buffer / Final Testing**             | Smoke test all flows, fix bugs                     | 🔲 |

---

## What Was Completed Before Mar 11

### ✅ Phase 1 — RBAC & Foundation (Done)

- [x] `User.role` enum: `admin`, `vendor`, `customer`, `delivery_staff`
- [x] JWT includes `role`, `userId`, `phone`, `ownerId`
- [x] `requireRole` RBAC middleware (`middleware/rbac.middleware.js`)
- [x] RBAC applied to all vendor routes
- [x] New users default to `role: 'vendor'`
- [x] Twilio Verify OTP for all roles
- [x] Config exports: Razorpay, Firebase, JWT expiry
- [x] Customer CRUD + bulk import
- [x] MealPlan CRUD (basic, without items+quantities)
- [x] Subscription (plan assignment) + daily order generation (cron + on create)
- [x] Process orders (pending → processing + FCM to customers)
- [x] Mark delivered (basic — no wallet deduct yet)
- [x] Payment recording (manual + Razorpay)
- [x] Invoice generation + share links
- [x] Socket.IO `/delivery` namespace (location_update → vendor room)
- [x] Summary report (daily/weekly/monthly)
- [x] Razorpay webhook
- [x] Subscription expiry cron

### ❌ Still needed from original Day 1 cleanup
- [ ] Remove `User.subscriptionPlan` and `User.planExpiresAt` from `User.model.js`

---

## Day 1 — Tue Mar 11: Item Catalog + Meal Plan Redesign

**Target:** Foundation for all meal-based features. Items must exist before plans can reference them.

### Morning — Item Catalog

- [ ] **1.1** Create `Item.model.js`:
  ```
  ownerId (ref User), name, unitPrice, unit (piece/bowl/plate/glass/other),
  category (optional), isActive (default true)
  Index: {ownerId, isActive}
  ```
- [ ] **1.2** Create `item.controller.js`: list (paginated, `?isActive`), getById, create, update, delete (block if used in active plan).
- [ ] **1.3** Create `item.routes.js`: `GET/POST/PUT/DELETE /api/v1/items` under `requireRole(['vendor','admin'])`.
- [ ] **1.4** Register item routes in `routes/index.js`.

### Afternoon — Meal Plan Redesign

- [ ] **1.5** Update `Plan.model.js` (MealPlan):
  - Add `mealSlots[]`: each has `slot` (breakfast/lunch/dinner/snack/early_morning), `items[]` (itemId ref Item, quantity: number).
  - Keep: `planName`, `price`, `isActive`, `ownerId`, `color`.
  - Remove `menuDescription` (text); it's replaced by `mealSlots`.
  - Keep `includesLunch`/`includesDinner` as optional derived info or remove.
- [ ] **1.6** Update `DailyOrder.model.js`:
  - Update `resolvedItems[]` to: `{ itemId, itemName, quantity, unitPrice, subtotal }`.
  - Ensure `amount` (total cost) is stored on DailyOrder.
- [ ] **1.7** Update `plan.controller.js`: `createPlan` and `updatePlan` accept `mealSlots` with item refs; validate each `itemId` belongs to `ownerId`.
- [ ] **1.8** Update `dailyOrder.service.js` → `generateDailyOrdersForDate`: when creating DailyOrder, copy items from `planAssignment → plan.mealSlots` into `resolvedItems[]` and compute `amount = sum(unitPrice × quantity)`.
- [ ] **1.9** Remove `User.subscriptionPlan` and `User.planExpiresAt` from `User.model.js`.

**Exit:** Vendor has item catalog; plans reference items with quantities; daily orders store item snapshot + amount.

---

## Day 2 — Wed Mar 12: Wallet + Balance + Delivery Lifecycle

**Target:** Vendor adds cash balance; balance auto-deducted on delivery; full lifecycle API.

### Morning — Wallet Credit

- [ ] **2.1** Add `POST /api/v1/customers/:id/wallet/credit` in `customer.controller.js`:
  - Body: `{ amount, paymentMethod?, notes? }`.
  - Validate: `amount > 0`, customer belongs to `ownerId`.
  - Increment `Customer.balance`.
  - Create `Payment` record (`status: 'captured'`, no `invoiceId`).
- [ ] **2.2** Update `POST /payments` (existing): if no `invoiceId` and no `subscriptionId` → also increment `Customer.balance` (wallet top-up semantic).
- [ ] **2.3** Add `Payment.status` field to `Payment.model.js` (enum: pending/captured/failed/refunded).
- [ ] **2.4** Manual payments set `status: 'captured'` on create.

### Afternoon — Deduct on Delivery + Out-for-Delivery

- [ ] **2.5** Add `PATCH /api/v1/daily-orders/:id/status` route + handler:
  - Body: `{ status: 'out_for_delivery' | 'delivered' }`.
  - Validate forward-only status transitions.
  - For `out_for_delivery`: set `outForDeliveryAt`; send FCM to customer ("Your tiffin is out for delivery") + vendor; create Notification records.
  - For `delivered`: run wallet deduction (see below); set `deliveredAt`; send FCM to customer + vendor.
- [ ] **2.6** Wallet deduction on `delivered`: within MongoDB session — deduct `DailyOrder.amount` from `Customer.balance`; idempotent (skip if already delivered).
- [ ] **2.7** `User.settings.allowNegativeBalance` option (default false) — return 400 if insufficient.
- [ ] **2.8** Confirm existing `POST /daily-orders/mark-delivered` also runs deduction logic (or deprecate in favour of PATCH status).

**Exit:** Vendor adds balance; PATCH /status drives lifecycle; delivered deducts balance; FCM at each step.

---

## Day 3 — Thu Mar 13: Delivery Boy APIs

**Target:** Vendor assigns delivery boy; delivery boy accepts/rejects; staff sees his deliveries.

### Morning — Assign API + DeliveryStaff Link

- [ ] **3.1** Add `userId` field to `DeliveryStaff.model.js` (ref User). Update `authRole.service.js`: when phone matches a `DeliveryStaff`, set `role: 'delivery_staff'` and link `staffId` in JWT.
- [ ] **3.2** `PATCH /api/v1/daily-orders/:id/assign` (vendor/admin):
  - Body: `{ deliveryStaffId }`.
  - Validate staff belongs to `ownerId`.
  - Set `DailyOrder.deliveryStaffId`.
  - Send FCM to delivery staff ("New delivery assigned to you").
- [ ] **3.3** `POST /api/v1/daily-orders/assign-bulk` (vendor/admin):
  - Body: `{ orderIds: [], deliveryStaffId }` — bulk assign.

### Afternoon — Accept/Reject + My Deliveries

- [ ] **3.4** `POST /api/v1/daily-orders/:id/accept` (delivery_staff only):
  - Validates `DailyOrder.deliveryStaffId === req.user.userId`.
  - Logs acceptance (optional status sub-field or audit log).
  - Send FCM to vendor ("Delivery boy accepted task for [Customer Name]").
- [ ] **3.5** `POST /api/v1/daily-orders/:id/reject` (delivery_staff only):
  - Body: `{ reason? }`.
  - Clears `DailyOrder.deliveryStaffId`; sets status back to `processing`.
  - Send FCM to vendor ("⚠️ [Staff Name] rejected delivery task for [Customer Name] — please reassign").
- [ ] **3.6** `GET /api/v1/delivery/my-deliveries` (delivery_staff only):
  - Filter: `deliveryStaffId = req.user.userId`, `orderDate = today`.
  - Populate: `customerId.name`, `customerId.address`, `customerId.location`, `customerId.phone`.
  - Return list sorted by area or distance.
- [ ] **3.7** Ensure `PATCH /daily-orders/:id/status` (from Day 2) — delivery_staff can call it for orders assigned to them (`deliveryStaffId === req.user.userId`).

**Exit:** Full delivery boy flow: assignment → accept/reject → my list → mark out_for_delivery → mark delivered.

---

## Day 4 — Fri Mar 14: Pause Subscription + Reports + Payment Fix

**Target:** Pause works and skips order generation; revenue fixed; new report endpoints.

### Morning — Pause Subscription

- [ ] **4.1** `PUT /api/v1/subscriptions/:id/pause` (vendor + customer):
  - Body: `{ pausedFrom (ISO date), pausedUntil (ISO date) }`.
  - Validate: subscription is `active`, belongs to owner, dates are valid future range.
  - Set `status: 'paused'`, `pausedFrom`, `pausedUntil`.
- [ ] **4.2** `PUT /api/v1/subscriptions/:id/unpause` (vendor + customer):
  - Set `status: 'active'`, clear `pausedFrom`/`pausedUntil`.
- [ ] **4.3** Update `generateDailyOrdersForDate` in `dailyOrder.service.js`:
  - For each subscription: if `status === 'paused'` AND `orderDate >= pausedFrom` AND `orderDate <= pausedUntil` → skip; do not create DailyOrder.

### Afternoon — Reports Fix

- [ ] **4.4** Fix `report.service.js` summary: use `Payment.status === 'captured'` (works after Day 2 model change). Scope by `ownerId`.
- [ ] **4.5** Update webhook: `webhook.controller.js` sets `Payment.status = 'captured'` on `payment.captured` event.
- [ ] **4.6** `GET /api/v1/reports/today-deliveries`:
  - Count + list DailyOrders for `ownerId`, `orderDate = today`, group by status.
- [ ] **4.7** `GET /api/v1/reports/expiring-subscriptions?days=7`:
  - Active subscriptions where `endDate` is within next N days, scoped by `ownerId`.
- [ ] **4.8** `GET /api/v1/reports/pending-payments`:
  - Invoices with `paymentStatus: unpaid/partial` OR customers with `balance < 0`, scoped by `ownerId`.

**Exit:** Pause/unpause works and daily orders skip paused range; revenue correct; new reports available.

---

## Day 5 — Sat Mar 15: Low Balance + Notifications Complete

**Target:** Low balance triggers notifications; all notification events covered; constants centralized.

### Morning — Low Balance

- [ ] **5.1** Add `User.settings.lowBalanceThreshold` (number, default 100) to `User.model.js`.
- [ ] **5.2** After wallet deduction (Day 2): `if (newBalance < vendor.settings.lowBalanceThreshold)`:
  - Send FCM to customer: "Low balance alert — ₹X remaining. Please recharge."
  - Send in-app notification to vendor: "Customer [Name] has low balance (₹X)."
  - Create `Notification` records for both.
- [ ] **5.3** `GET /api/v1/customers?lowBalance=true`:
  - Filter customers where `balance < owner.settings.lowBalanceThreshold`, scoped by `ownerId`.
  - Response includes formatted phone for WhatsApp deep link: `whatsappUrl: https://wa.me/91XXXXXXXXXX`.

### Afternoon — Notifications Completeness

- [ ] **5.4** Create `utils/notificationTypes.js` constants:
  ```js
  ORDER_PROCESSING, OUT_FOR_DELIVERY, DELIVERED,
  TASK_ASSIGNED, TASK_ACCEPTED, TASK_REJECTED,
  LOW_BALANCE, PLAN_EXPIRING
  ```
  Replace string literals in all services.
- [ ] **5.5** Verify subscription expiry cron also creates `Notification` doc (not just FCM).
- [ ] **5.6** Verify `processToday` creates in-app `Notification` for customers (not just FCM).
- [ ] **5.7** `POST /api/v1/notifications/test` — update to use notification type constants.

**Exit:** Low balance alerts work; all notification events covered; consistent event naming.

---

## Day 6 — Sun Mar 16: Customer-Facing APIs + Polish

**Target:** Customer can log in and see their own data; indexes added; validation complete.

### Morning — Customer APIs

- [ ] **6.1** Update `authRole.service.js`: when customer logs in (phone lookup), find `Customer` record, return `role: 'customer'`, include `customerId` in JWT payload.
- [ ] **6.2** Create customer-scoped routes (`routes/customer.routes.js`):
  - `GET /api/v1/customer/me` — returns `Customer` profile + balance.
  - `PUT /api/v1/customer/me` — update name, address, location (GeoJSON point).
  - `GET /api/v1/customer/me/plan` — active subscription + plan details.
  - `GET /api/v1/customer/me/orders` — DailyOrders for this customer.
- [ ] **6.3** Enable `PATCH /daily-orders/:id/quantities` for customer role (already in Day 1 plan):
  - Validate: only existing item IDs, quantity ≥ 1, no add/remove.
  - Recalculate `DailyOrder.amount`.
- [ ] **6.4** Enable `PUT /subscriptions/:id/pause` and unpause for customer role (validate `customerId` ownership).

### Afternoon — Polish + Indexes + Validation

- [ ] **6.5** Add missing indexes:
  - `Customer`: `{ownerId, balance}` (for low balance queries).
  - `Payment`: `{ownerId, status}` (for revenue report).
  - Verify existing DailyOrder indexes cover new query patterns.
- [ ] **6.6** Run Joi validation review on all new Day 1–5 endpoints — ensure 400 with clear messages.
- [ ] **6.7** Update `.env.example` with any new keys: `LOW_BALANCE_THRESHOLD`.
- [ ] **6.8** Optional: `GET /api/v1/admin/vendors` (admin role) — list Users with `role: vendor`. No create vendor.

**Exit:** Customer app can log in and use their data; all validations in place; indexes added.

---

## Day 7 — Mon Mar 17: Buffer / Final Smoke Test

**Full smoke test flow:**

```
1. Vendor self-registers via OTP
2. Vendor creates Item catalog (Roti ₹5, Sabji ₹20, Dal ₹25)
3. Vendor creates Meal Plan (Lunch: 4 Roti + 1 Sabji + 1 Dal)
4. Vendor adds Customer (name, phone, address, location)
5. Vendor assigns Meal Plan to Customer (start/end date)
6. Daily Order generated automatically with resolvedItems + amount
7. Vendor adds ₹1000 balance for customer
8. Customer logs in, sees plan, edits quantities (5 Roti, not 4)
9. Vendor processes orders → status: processing; customer gets FCM
10. Vendor assigns Delivery Boy → staff gets FCM
11. Delivery Boy accepts task
12. Delivery Boy marks out_for_delivery → vendor + customer get FCM
13. Delivery Boy delivers → marks delivered
14. Customer balance auto-deducted (₹1000 - order amount)
15. If balance < 100 → customer + vendor get low balance FCM
16. Check reports: today-deliveries, expiring plans, pending payments
17. Vendor pauses customer plan for vacation dates
18. Verify no DailyOrder generated for paused dates
```

- [ ] Fix any bugs from smoke test.
- [ ] Note: "Backend aligned with CORRECT_SYSTEM_FLOW as of Mar 17, 2026" in BACKEND_FLOW_COMPARISON.md.

---

## Quick Checklist (All Tasks)

| # | Task | Day | Status |
|---|------|-----|--------|
| 0 | Remove `User.subscriptionPlan` | 1 | ❌ |
| 1 | Item model + CRUD | 1 | ❌ |
| 2 | MealPlan redesign (mealSlots + items) | 1 | ❌ |
| 3 | DailyOrder resolvedItems + amount | 1 | ❌ |
| 4 | Update order generation to compute amount | 1 | ❌ |
| 5 | Payment.status field | 2 | ❌ |
| 6 | Wallet credit endpoint | 2 | ❌ |
| 7 | Manual payment updates Customer.balance | 2 | ❌ |
| 8 | `PATCH /daily-orders/:id/status` (out_for_delivery + delivered) | 2 | ❌ |
| 9 | Deduct balance on delivered (with session) | 2 | ❌ |
| 10 | FCM on out_for_delivery | 2 | ❌ |
| 11 | Add `userId` to DeliveryStaff | 3 | ❌ |
| 12 | Assign delivery boy API + FCM | 3 | ❌ |
| 13 | Bulk assign API | 3 | ❌ |
| 14 | Accept task API + FCM to vendor | 3 | ❌ |
| 15 | **Reject task API** + FCM to vendor + reassign flow | 3 | ❌ |
| 16 | `GET /delivery/my-deliveries` (staff-scoped) | 3 | ❌ |
| 17 | Pause / unpause subscription API | 4 | ❌ |
| 18 | Skip paused dates in order generation | 4 | ❌ |
| 19 | Fix revenue report (Payment.status) | 4 | ❌ |
| 20 | Webhook sets Payment.status | 4 | ❌ |
| 21 | `GET /reports/today-deliveries` | 4 | ❌ |
| 22 | `GET /reports/expiring-subscriptions` | 4 | ❌ |
| 23 | `GET /reports/pending-payments` | 4 | ❌ |
| 24 | Low balance threshold in User.settings | 5 | ❌ |
| 25 | Low balance FCM (customer + vendor) after deduct | 5 | ❌ |
| 26 | `GET /customers?lowBalance=true` with whatsappUrl | 5 | ❌ |
| 27 | Notification type constants | 5 | ❌ |
| 28 | Customer login links customerId in JWT | 6 | ❌ |
| 29 | Customer profile + plan + orders endpoints | 6 | ❌ |
| 30 | `PATCH /daily-orders/:id/quantities` (customer, qty only) | 6 | ❌ |
| 31 | Indexes: Customer{ownerId,balance}, Payment{ownerId,status} | 6 | ❌ |
| 32 | Smoke test full flow | 7 | ❌ |

---

*Updated: Mar 11, 2026. Phase 1 complete; Phase 2 onward starts today. Delivery boy reject task added. Item catalog as Day 1 priority (foundation for meal plans).*
