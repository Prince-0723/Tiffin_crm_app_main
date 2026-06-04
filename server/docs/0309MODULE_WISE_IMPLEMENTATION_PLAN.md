# Module-Wise Implementation Plan — Backend Correction to Target Flow

This document is the **module-wise plan** to correct the current backend to match the [Correct System Flow](./0309CORRECT_SYSTEM_FLOW.md).

**Reference:** [BACKEND_FLOW_COMPARISON.md](./0309BACKEND_FLOW_COMPARISON.md) for gap details.

**Key rules:**
1. Admin does **not** create vendor — vendor self-registers with own phone.
2. **Subscription plans** (free/basic/premium tiers) are **removed**.
3. Vendor adds customers and assigns **pre-created or custom meal plan**.
4. Customer **does not create** meal plan; customer may **edit quantities only** (increase/decrease), cannot add or remove items.
5. Delivery boy can **accept or reject** assigned task.

**Status Legend:** ✅ Done | ⚠️ Partial | ❌ Not done

---

## Overview

| Phase       | Focus                        | Modules                                             | Priority      | Status |
| ----------- | ---------------------------- | --------------------------------------------------- | ------------- | ------ |
| **Phase 1** | Foundation & RBAC            | Auth/Roles, Middleware, Config                      | P0 — Do first | ✅ Done |
| **Phase 2** | Item Catalog & Plan Redesign | Item model, MealPlan with items, plan slot structure | P0 — Critical | ❌ Not done |
| **Phase 3** | Core business flow           | Wallet, DailyOrder lifecycle, Delivery, Pause       | P0 — Critical | ❌ Not done |
| **Phase 4** | Data & reports               | Reports fix, Notifications complete, Payment fix    | P1            | ⚠️ Partial |
| **Phase 5** | Customer & Admin APIs        | Customer-facing routes, Admin monitor APIs          | P2            | ❌ Not done |

---

## Phase 1 — Foundation & RBAC ✅ Done

### Module 1.1 — Role-Based Access Control (RBAC) ✅

| # | Task | Status | Notes |
|---|------|--------|-------|
| 1.1.1 | `User.role` enum: `admin`, `vendor`, `customer`, `delivery_staff` | ✅ Done | Model already has correct enum |
| 1.1.2 | `role` in JWT payload (verify-otp, truecaller, refresh, reset) | ✅ Done | Role included in token payload |
| 1.1.3 | `requireRole` RBAC middleware | ✅ Done | `middleware/rbac.middleware.js` exists |
| 1.1.4 | Apply `requireRole(['vendor','admin'])` to all vendor routes | ✅ Done | Applied in routes index |
| 1.1.5 | Scope by identity: `req.user.ownerId` for vendor | ✅ Done | RBAC middleware sets ownerId |
| 1.1.6 | Remove `User.subscriptionPlan` and `User.planExpiresAt` | ❌ Not done | Still in User model — clean up |

**Remaining:** Remove `subscriptionPlan` and `planExpiresAt` from `User.model.js`.

---

### Module 1.2 — Auth & Config ✅

| # | Task | Status | Notes |
|---|------|--------|-------|
| 1.2.1 | Export Razorpay, Firebase, JWT expiry from config | ✅ Done | All keys in `config/index.js` |
| 1.2.2 | Default new users to `role: 'vendor'` on signup | ✅ Done | verify-otp creates vendor by default |
| 1.2.3 | Phone + OTP login for all roles | ✅ Done | Twilio Verify; `authRole.service` resolves role by phone |
| 1.2.4 | JWT refresh token flow | ✅ Done | refresh-token endpoint exists |

---

## Phase 2 — Item Catalog & Meal Plan Redesign ❌ Not done

### Module 2.1 — Item Catalog (Foundation for Meal Plans)

**Goal:** Vendor defines daily available food items with prices. These are referenced by meal plans.

| # | Task | Type | Details |
|---|------|------|---------|
| 2.1.1 | Create `Item` model | Model | Fields: `ownerId` (ref User), `name` (string), `unitPrice` (number), `unit` (enum: piece/bowl/plate/glass/other), `category` (optional), `isActive` (bool, default true). Index: `{ownerId, isActive}`. |
| 2.1.2 | Item CRUD routes | API | `GET/POST/PUT/DELETE /api/v1/items` — vendor/admin only. List with pagination and `?isActive=true` filter. |
| 2.1.3 | Item controller | Controller | Standard CRUD. On `DELETE`, check if item is used in any active MealPlan before deleting (block or soft-delete). |

**Deliverables:**
- Vendor has a priced item catalog.
- Items can be marked active/inactive.
- Files: new `Item.model.js`, `item.controller.js`, `item.routes.js`.

---

### Module 2.2 — Meal Plan Redesign (Items + Quantities)

**Goal:** Meal plans contain actual items with quantities per meal slot. Customer can edit quantities only.

| # | Task | Type | Details |
|---|------|------|---------|
| 2.2.1 | Update `MealPlan` model | Model | Add `mealSlots[]`: each slot has `slot` (enum: breakfast/lunch/dinner/snack/early_morning), `items[]` (itemId ref Item, quantity: number, isRequired: bool). Keep existing `planName`, `price`, `isActive`. Remove or keep `includesLunch/includesDinner` as derived fields. |
| 2.2.2 | Update `DailyOrder.resolvedItems` | Model | `resolvedItems[]` should store the **actual items for this order** with quantities (either from plan or customer-edited quantities). Fields: `itemId`, `itemName`, `quantity`, `unitPrice`, `subtotal`. |
| 2.2.3 | Update plan CRUD | API | `POST/PUT /plans` — accept `mealSlots` array in body. Validate each item reference belongs to the same `ownerId`. |
| 2.2.4 | Update daily order generation | Service | When generating DailyOrder from a plan assignment, copy `mealSlots[].items` into `DailyOrder.resolvedItems` and compute `DailyOrder.amount` (sum of unitPrice × quantity). |
| 2.2.5 | Customer quantity-edit endpoint | API | `PATCH /api/v1/daily-orders/:id/quantities` (customer role only): body `items[{ itemId, quantity }]`. Validate: only existing items allowed (no add/remove); quantity ≥ 1. Reject if items added or removed. Recalculate `DailyOrder.amount`. |

**Deliverables:**
- Meal plans reference item catalog with quantities.
- Daily orders store resolved items and computed amount.
- Customer can edit quantities only.
- Files: `Plan.model.js`, `DailyOrder.model.js`, `plan.controller.js`, `dailyOrder.service.js`.

---

## Phase 3 — Core Business Flow ❌ Not done

### Module 3.1 — Wallet & Balance

**Goal:** Vendor adds cash balance to customer; balance auto-deducted on delivery.

| # | Task | Type | Details |
|---|------|------|---------|
| 3.1.1 | Wallet credit endpoint | API | `POST /api/v1/customers/:id/wallet/credit` body `{ amount, paymentMethod?, notes? }`. Validate: `amount > 0`, customer belongs to `ownerId`. Increment `Customer.balance`. Create `Payment` record with `type: 'wallet_credit'`, `status: 'captured'`. |
| 3.1.2 | Payment records balance update | Service | In `POST /payments` (existing), if no `invoiceId` and no `subscriptionId` → treat as wallet top-up → increment `Customer.balance`. |
| 3.1.3 | Deduct balance on delivery | Service | In `markDelivered` handler: (a) get `DailyOrder.amount`; (b) within MongoDB session/transaction: deduct from `Customer.balance`, set `deliveredAt`, set status `delivered`. (c) if `DailyOrder.amount` is 0 or null, compute from `resolvedItems`. |
| 3.1.4 | Idempotency | Safety | If order already `delivered`, skip deduction and return 200. |
| 3.1.5 | Allow negative balance option | Config | `User.settings.allowNegativeBalance` (bool, default false). If false, return 400 "Insufficient balance" when deduction would go negative. |

**Files:** `customer.controller.js`, `payment.controller.js`, `dailyOrder.controller.js`, `dailyOrder.service.js`, `Customer.model.js`.

---

### Module 3.2 — Low Balance

**Goal:** Notify customer and vendor when balance is below threshold after delivery.

| # | Task | Type | Details |
|---|------|------|---------|
| 3.2.1 | Low balance threshold | Model | Add `User.settings.lowBalanceThreshold` (number, default 100). |
| 3.2.2 | Low balance check on deduct | Service | After deducting: `if (newBalance < threshold)` → send FCM to customer ("Low balance alert") + create Notification. Also send in-app notification to vendor. |
| 3.2.3 | Low balance customer list | API | `GET /api/v1/customers?lowBalance=true` — filter `Customer.balance < owner.settings.lowBalanceThreshold`, scoped by `ownerId`. |
| 3.2.4 | Optional daily cron | Job | Once-per-day cron that finds all customers with balance < threshold and sends notification if not sent in last 24h (prevent spam). |

**Files:** `User.model.js`, `customer.controller.js`, `notification.service.js`, optional cron.

---

### Module 3.3 — DailyOrder Lifecycle (Out-for-Delivery Step)

**Goal:** Full lifecycle: `pending → processing → out_for_delivery → delivered` with FCM at each step.

| # | Task | Type | Details |
|---|------|------|---------|
| 3.3.1 | `PATCH /daily-orders/:id/status` | API | Body: `{ status: 'out_for_delivery' \| 'delivered' }`. Validates current status (must progress forward). Sets `outForDeliveryAt` or `deliveredAt`. For `delivered`: runs wallet deduction (Module 3.1). |
| 3.3.2 | Role restriction | Middleware | Vendor can set any status. Delivery staff can only update status for orders where `deliveryStaffId === req.user.userId`. |
| 3.3.3 | FCM on out_for_delivery | Service | When `→ out_for_delivery`: send FCM to customer ("Your tiffin is out for delivery 🛵") + FCM to vendor ("Order out for delivery for [Customer Name]") + create Notification records. |
| 3.3.4 | FCM on delivered | Service | Existing `markDelivered` sends FCM — verify it also sends FCM to vendor + creates in-app Notification for both. |

**Files:** `dailyOrder.controller.js`, `dailyOrder.routes.js`, `inAppNotification.service.js`.

---

### Module 3.4 — Delivery Assignment & Delivery Boy APIs

**Goal:** Vendor assigns delivery boy; delivery boy accepts/rejects; staff sees only his orders.

| # | Task | Type | Details |
|---|------|------|---------|
| 3.4.1 | Link DeliveryStaff to User | Model | Add `userId` (ref User) to `DeliveryStaff.model.js`. When delivery boy logs in (phone+OTP), `authRole.service` finds their `DeliveryStaff` record and assigns `role: 'delivery_staff'`. |
| 3.4.2 | Assign delivery boy API | API | `PATCH /api/v1/daily-orders/:id/assign` body `{ deliveryStaffId }`. Validate staff belongs to `ownerId`. Set `DailyOrder.deliveryStaffId`. Send FCM to delivery staff ("New delivery assigned"). |
| 3.4.3 | Bulk assign API | API | `POST /api/v1/daily-orders/assign-bulk` body `{ orderIds: [], deliveryStaffId }`. |
| 3.4.4 | Accept task | API | `POST /api/v1/daily-orders/:id/accept` — delivery staff only. Confirms assignment. Optional: set an `accepted` sub-status or log event. Send FCM to vendor ("Delivery boy accepted task"). |
| 3.4.5 | Reject task | API | `POST /api/v1/daily-orders/:id/reject` body `{ reason? }` — delivery staff only. Clears `deliveryStaffId`, sets order back to `processing`. Send FCM to vendor ("⚠️ Delivery boy rejected task for [Customer Name]"). Vendor must reassign. |
| 3.4.6 | "My deliveries today" | API | `GET /api/v1/delivery/my-deliveries` — delivery_staff role. Filters `DailyOrder` by `deliveryStaffId = req.user.userId` AND `orderDate = today`. Populates `customerId.name`, `customerId.address`, `customerId.location`, `customerId.phone`. |
| 3.4.7 | FCM token for delivery staff | Model | `DeliveryStaff.fcmToken` field exists ✅. Ensure it is updated when staff logs in (same as User.fcmToken flow). |

**Files:** `DeliveryStaff.model.js`, `dailyOrder.controller.js`, `dailyOrder.routes.js`, `delivery.controller.js` (replace stub), `delivery.routes.js`, `authRole.service.js`.

---

### Module 3.5 — Pause Subscription

**Goal:** Vendor or customer pauses plan assignment; daily order generation skips paused dates.

| # | Task | Type | Details |
|---|------|------|---------|
| 3.5.1 | Pause API | API | `PUT /api/v1/subscriptions/:id/pause` body `{ pausedFrom (date), pausedUntil (date) }`. Validate: subscription is active, belongs to `ownerId`, dates are valid. Set `status: 'paused'`, `pausedFrom`, `pausedUntil`. |
| 3.5.2 | Unpause API | API | `PUT /api/v1/subscriptions/:id/unpause` — set status back to `active`, clear `pausedFrom`/`pausedUntil`. |
| 3.5.3 | Skip paused in order generation | Service | In `generateDailyOrdersForDate`: for each subscription, if `status === 'paused'` AND `orderDate` is within `[pausedFrom, pausedUntil]` (inclusive), skip creating `DailyOrder`. |
| 3.5.4 | Customer-facing pause | API | Expose pause/unpause to `customer` role for subscriptions where `customerId` matches the logged-in customer. |

**Files:** `subscription.controller.js`, `subscription.routes.js`, `dailyOrder.service.js`.

---

## Phase 4 — Reports, Notifications & Payments ⚠️ Partial

### Module 4.1 — Payment Model Fix

| # | Task | Type | Details |
|---|------|------|---------|
| 4.1.1 | Add `Payment.status` field | Model | Enum: `pending`, `captured`, `failed`, `refunded`. Default: `captured` for manual payments. |
| 4.1.2 | Webhook sets status | Service | In `webhook.controller.js`: on `payment.captured` event, set `Payment.status = 'captured'` and update amount. |
| 4.1.3 | Manual payment sets status | Controller | On `POST /payments`: set `status: 'captured'` automatically (vendor confirmed cash/UPI received). |
| 4.1.4 | Payment also updates balance | Controller | `POST /payments` → increment `Customer.balance` (delegates to wallet credit logic in Module 3.1). |

**Files:** `Payment.model.js`, `payment.controller.js`, `webhook.controller.js`.

---

### Module 4.2 — Reports Fix & Extension

**Goal:** Fix broken revenue report; add today's deliveries, pending payments, expiring subscriptions.

| # | Task | Type | Details |
|---|------|------|---------|
| 4.2.1 | Fix revenue aggregation | Service | `report.service.js` uses `Payment.status === 'captured'` — will work once Payment.status field added. Also scope by `ownerId`. |
| 4.2.2 | Today's deliveries report | API | `GET /api/v1/reports/today-deliveries` (vendor): count + list DailyOrders for today by status. |
| 4.2.3 | Expiring plan assignments | API | `GET /api/v1/reports/expiring-subscriptions?days=7`: active subscriptions where `endDate` is within next N days. |
| 4.2.4 | Pending payments report | API | `GET /api/v1/reports/pending-payments`: invoices with `paymentStatus: unpaid/partial` OR customers with `balance < 0`. |
| 4.2.5 | Low balance report | API | Already covered in `GET /customers?lowBalance=true` (Module 3.2.3). |

**Files:** `report.service.js`, `report.controller.js`, `report.routes.js`.

---

### Module 4.3 — Notifications Completeness

**Goal:** All target notification events trigger FCM + in-app Notification record.

| # | Task | Type | Details |
|---|------|------|---------|
| 4.3.1 | Out-for-delivery notification | Service | Covered in Module 3.3.3 — verify FCM + Notification created. |
| 4.3.2 | Task assigned notification | Service | Covered in Module 3.4.2 — FCM to delivery staff. |
| 4.3.3 | Task rejected notification | Service | Covered in Module 3.4.5 — FCM to vendor. |
| 4.3.4 | Low balance notification | Service | Covered in Module 3.2.2. |
| 4.3.5 | Plan expiry in-app record | Service | Expiry cron sends FCM ✅ — verify `Notification` doc is also created. |
| 4.3.6 | Centralize notification types | Code | Create `utils/notificationTypes.js` constants: `ORDER_PROCESSING`, `OUT_FOR_DELIVERY`, `DELIVERED`, `TASK_ASSIGNED`, `TASK_REJECTED`, `LOW_BALANCE`, `PLAN_EXPIRING`. Use in all service calls. |

---

## Phase 5 — Customer App & Admin APIs ❌ Not done

### Module 5.1 — Customer-Facing Endpoints

**Goal:** Customer logs in as customer role and can see their own data.

| # | Task | Type | Details |
|---|------|------|---------|
| 5.1.1 | Customer user linking | Auth | When customer logs in with phone: `authRole.service` finds their `Customer` record (by phone + ownerId), returns `role: 'customer'`, links `customerId` into JWT payload. |
| 5.1.2 | Customer profile | API | `GET /api/v1/customer/me` — returns Customer record (name, phone, address, location, balance). `PUT /api/v1/customer/me` — update profile, address, location (GeoJSON). |
| 5.1.3 | My plan | API | `GET /api/v1/customer/me/plan` — returns active Subscription + MealPlan for this customer. |
| 5.1.4 | My daily orders | API | `GET /api/v1/customer/me/orders` — returns DailyOrders for this customer (today + history). Supports `?date=` filter. |
| 5.1.5 | Edit meal quantities | API | `PATCH /api/v1/daily-orders/:id/quantities` (customer role). Covered in Module 2.2.5. |
| 5.1.6 | Pause plan | API | `PUT /api/v1/subscriptions/:id/pause` — available to customer role. Covered in Module 3.5.4. |

**Files:** new `customer.routes.js` (customer-scoped), update `auth` to link customerId in JWT.

---

### Module 5.2 — Admin APIs (Monitor Only)

**Goal:** Admin can monitor all vendors, customers, orders. Admin does **not** create vendors.

| # | Task | Type | Details |
|---|------|------|---------|
| 5.2.1 | Admin middleware | Middleware | `requireRole(['admin'])` — already available. |
| 5.2.2 | List vendors | API | `GET /api/v1/admin/vendors` — list Users with `role: 'vendor'` (paginated, with customer count, plan count). |
| 5.2.3 | Vendor analytics | API | `GET /api/v1/admin/vendors/:id/analytics` — aggregates: customer count, active subscriptions, revenue, deliveries for that vendor. |
| 5.2.4 | ~~Create vendor~~ | — | **Not required.** Vendors self-register via phone + OTP. |
| 5.2.5 | System settings | API | `GET/PUT /api/v1/admin/settings` — global low balance threshold default, feature flags. |

**Files:** new `admin.controller.js`, `admin.routes.js`.

---

## Implementation Order (Checklist)

### Phase 1 — Foundation ✅ Mostly Done
- [x] RBAC: role in JWT, `requireRole` middleware, applied to vendor routes
- [x] Config: Razorpay, Firebase, JWT expiry exported
- [x] Default role `vendor` for new users
- [ ] **Remove `User.subscriptionPlan` and `User.planExpiresAt`**

### Phase 2 — Item Catalog & Plan Redesign ❌
- [ ] 2.1 Item model + CRUD (ownerId, name, unitPrice, unit, isActive)
- [ ] 2.2 Update MealPlan: add `mealSlots[]` with itemId refs + quantities
- [ ] 2.3 Update `DailyOrder.resolvedItems` to store item snapshot
- [ ] 2.4 Update daily order generation to compute `amount` from items
- [ ] 2.5 Customer quantity-edit endpoint (`PATCH /daily-orders/:id/quantities`)

### Phase 3 — Core Business Flow ❌
- [ ] 3.1 Wallet credit endpoint + payment updates `Customer.balance`
- [ ] 3.2 Deduct balance on delivery (with MongoDB session); idempotent
- [ ] 3.3 Low balance threshold + notification + customer list
- [ ] 3.4 `PATCH /daily-orders/:id/status` — `out_for_delivery` + `delivered`
- [ ] 3.5 FCM + Notification on `out_for_delivery`
- [ ] 3.6 Add `userId` to `DeliveryStaff` model
- [ ] 3.7 Assign delivery boy API + FCM to staff
- [ ] 3.8 Accept task API + FCM to vendor
- [ ] 3.9 **Reject task API** + FCM to vendor (vendor must reassign)
- [ ] 3.10 `GET /delivery/my-deliveries` for delivery_staff role
- [ ] 3.11 `PUT /subscriptions/:id/pause` and unpause
- [ ] 3.12 Skip paused dates in `generateDailyOrdersForDate`

### Phase 4 — Reports & Notifications ⚠️
- [ ] 4.1 `Payment.status` field + webhook sets it + manual sets it
- [ ] 4.2 Fix revenue report (uses `Payment.status`)
- [ ] 4.3 `GET /reports/today-deliveries`
- [ ] 4.4 `GET /reports/expiring-subscriptions`
- [ ] 4.5 `GET /reports/pending-payments`
- [ ] 4.6 Notification type constants (centralized)
- [ ] 4.7 Verify plan expiry cron creates in-app Notification

### Phase 5 — Customer & Admin ❌
- [ ] 5.1 Customer login links to Customer record (customerId in JWT)
- [ ] 5.2 Customer profile endpoints (`GET/PUT /customer/me`)
- [ ] 5.3 `GET /customer/me/plan` and `GET /customer/me/orders`
- [ ] 5.4 Admin: `GET /admin/vendors` and per-vendor analytics

---

## Professional & Efficiency Checklist

- **Validation:** All inputs validated with Joi; return 400 with clear messages.
- **Errors:** Use `ApiResponse` with consistent status codes; `errorHandler` logs and redacts secrets.
- **Idempotency:** `markDelivered` and wallet deductions are idempotent.
- **Transactions:** Use MongoDB session for: (a) balance deduction + order status update, (b) bulk assignment.
- **Indexes:** `DailyOrder`: `{ownerId, orderDate, status}` ✅, `{ownerId, orderDate, deliveryStaffId}` ✅, `{customerId, orderDate}` ✅. Add: `Customer {ownerId, balance}`. Payment: `{ownerId, status}`.
- **Logging:** Log business events (order processed, assigned, rejected, delivered, balance low).
- **Docs:** Keep this file and `0309BACKEND_FLOW_COMPARISON.md` updated as modules are completed.

---

## Quick Reference — New/Changed APIs

| Method | Path | Module | Purpose |
|--------|------|--------|---------|
| GET/POST/PUT/DELETE | `/items` | 2.1 | Item catalog |
| PUT | `/plans/:id` | 2.2 | Update plan with mealSlots |
| PATCH | `/daily-orders/:id/quantities` | 2.2, 5.1 | Customer edits quantities only |
| POST | `/customers/:id/wallet/credit` | 3.1 | Vendor adds balance |
| PATCH | `/daily-orders/:id/status` | 3.3 | Set out_for_delivery or delivered |
| PATCH | `/daily-orders/:id/assign` | 3.4 | Vendor assigns delivery boy |
| POST | `/daily-orders/assign-bulk` | 3.4 | Vendor assigns multiple orders |
| POST | `/daily-orders/:id/accept` | 3.4 | Delivery boy accepts task |
| POST | `/daily-orders/:id/reject` | 3.4 | Delivery boy rejects task → vendor notified |
| GET | `/delivery/my-deliveries` | 3.4 | Delivery boy's today list |
| PUT | `/subscriptions/:id/pause` | 3.5 | Pause plan assignment |
| PUT | `/subscriptions/:id/unpause` | 3.5 | Unpause plan assignment |
| GET | `/customers?lowBalance=true` | 3.2 | Low balance customer list |
| GET | `/reports/today-deliveries` | 4.2 | Today's deliveries |
| GET | `/reports/expiring-subscriptions` | 4.2 | Plan assignments expiring |
| GET | `/reports/pending-payments` | 4.2 | Pending payments |
| GET/PUT | `/customer/me` | 5.1 | Customer profile |
| GET | `/customer/me/plan` | 5.1 | Customer's active plan |
| GET | `/customer/me/orders` | 5.1 | Customer's daily orders |
| GET | `/admin/vendors` | 5.2 | Admin: list all vendors |
| GET | `/admin/vendors/:id/analytics` | 5.2 | Admin: per-vendor analytics |

---

_Updated: Mar 11, 2026. Reflects actual server state, new requirements (item catalog, delivery boy reject, WhatsApp), and correct priority order._
