# Correct System Flow for TiffinCRM

**Industry-level architecture** — Core of the system is the **DailyOrder lifecycle**, which controls delivery, balance deduction, and notifications.

---

## Roles

| Role               | Description                                                                                      |
| ------------------ | ------------------------------------------------------------------------------------------------ |
| **Admin**          | Full system access; monitors system (vendors, customers, delivery staff, plans, orders, payments, reports). Does **not** create vendors. |
| **Vendor (Owner)** | Main actor; **self-registers** with own phone + OTP; runs the tiffin business (customers, items, plans, orders, deliveries, payments) |
| **Customer**       | Created by vendor; uses vendor-assigned meal plans; can edit quantities only (no add/remove items); views balance and delivery tracking |
| **Delivery Boy**   | Created by vendor; receives delivery assignments; can **accept or reject** task; marks out-for-delivery and delivered |

---

## Authentication

- **Login:** Phone + OTP (all four roles)
- **Backend:** Returns JWT token with `userId`, `phone`, `role`, `ownerId`
- **Access:** Role-based access control (RBAC) — each role only hits allowed routes

---

## 1. Admin Flow

Admin has **full access** to the system. Admin **does not create vendors** — vendors self-register.

### Admin Can View / Manage

- View all vendors (monitor only)
- All customers across vendors
- All delivery boys
- All meal plans
- All items
- All orders
- All payments
- Full reports and analytics

### Admin Actions

```
Admin
  ├─ View all vendors (no vendor creation)
  ├─ View per-vendor analytics
  ├─ Manage delivery staff
  ├─ View all customers
  ├─ View revenue reports
  └─ System settings
```

Admin **monitors** the system. **Vendors are created and log in through their own phone number** (self-registration via OTP).

---

## 2. Vendor Flow (Main Actor)

Vendor manages the entire tiffin business.

### Step 1 — Vendor Login (Self-Registration)

```
Vendor enters phone number
        ↓
OTP sent (Twilio Verify)
        ↓
OTP verified → JWT Token generated
        ↓
Dashboard
```

Vendor is **not created by admin** — they register themselves via phone + OTP.

---

## 3. Customer Management Flow

Vendor adds customers directly from their **contact list** into the app.

### 3.1 Manual Add

```
Vendor
   ↓
Add Customer
   ↓
Name, Phone, Address, Google Map Location, Notes
```

### 3.2 Bulk Import (from Contact List)

```
Vendor
   ↓
Import from Contacts / Bulk Upload
   ↓
Multiple customers created at once
```

Vendor owns the customer — customer is scoped to that vendor (`ownerId`).

---

## 4. Food Items Setup (Item Catalog)

Vendor defines the **daily available food items** with per-unit prices.

**Example:**

```
Items (daily available)
 ├ Roti      → ₹5  / piece
 ├ Sabji     → ₹20 / bowl
 ├ Dal       → ₹25 / bowl
 ├ Rice      → ₹15 / bowl
 ├ Khichdi   → ₹40 / bowl
 ├ Alo ki Sabji → ₹20 / bowl
```

- Vendor can add / update / remove items anytime
- Only items marked **isActive = true** appear in meal plans
- Each item has: `name`, `unitPrice`, `unit` (piece/bowl/etc.), `isActive`

---

## 5. Meal Plan System

Vendor creates **meal plans** using items from the item catalog.

### 5.1 Plan Structure

A meal plan has **meal slots** (breakfast, lunch, dinner, and 1–2 additional slots like evening snack or early morning). Each slot contains **items with quantities**.

**Example:**

```
Monthly Lunch Plan — ₹2500/month
  Lunch slot:
    - 4 Roti
    - 1 Sabji
    - 1 Dal

Premium Full Day Plan — ₹4500/month
  Breakfast slot:
    - 2 Roti
    - 1 Alo ki Sabji
  Lunch slot:
    - 4 Roti
    - 1 Sabji
    - 1 Dal
    - 1 Rice
  Dinner slot:
    - 3 Roti
    - 1 Sabji
```

### 5.2 Plan Types

- **Pre-created plan** — vendor creates once, assigns to multiple customers
- **Custom plan** — vendor creates a plan specifically for one customer

**Subscription plans (platform tiers like free/basic/premium) are removed.**

---

## 6. Plan Assignment Flow (Vendor → Customer)

Vendor assigns a meal plan to a customer.

```
Vendor
   ↓
Select Customer
   ↓
Assign pre-created Meal Plan  OR  Create custom meal plan for this customer
   ↓
Set Start Date / End Date
   ↓
Plan assignment created → Daily Orders generated automatically
```

Daily orders are generated from this assignment. The cron job generates orders for the next 7 days every night at midnight.

---

## 7. Customer Edits Meal Plan (Quantity Only)

Customer **does not create** meal plans. Customer can **edit** the vendor-provided meal plan only by:

- **Increasing or decreasing the quantity** of existing meal items
- **Cannot add** new items to the meal
- **Cannot remove** items from the meal

**Example:**

```
Vendor-assigned Lunch plan: 4 Roti, 1 Sabji, 1 Dal

Customer edit ALLOWED:
  → 6 Roti, 1 Sabji, 1 Dal  (increased roti quantity)
  → 4 Roti, 2 Sabji, 1 Dal  (increased sabji quantity)

Customer edit NOT ALLOWED:
  → Add Rice to meal
  → Remove Dal from meal
```

---

## 8. Daily Order Generation

Every day the system auto-creates **DailyOrder** records for each active plan assignment.

**DailyOrder structure:**

```
DailyOrder
  ownerId          (vendor)
  customerId
  planId
  subscriptionId   (plan assignment)
  orderDate
  mealType         (lunch / dinner / breakfast / both)
  deliverySlot
  resolvedItems[]  (items + quantities for this order)
  amount           (total cost of this order)
  deliveryStaffId  (assigned delivery boy)
  status           (see lifecycle below)
```

---

## 9. Order Lifecycle (CRITICAL)

Correct order state flow:

```
pending
   ↓
processing   ← Vendor clicks "Process Orders" (meal is being cooked)
   ↓
out_for_delivery   ← Delivery boy picks up parcel and marks it
   ↓
delivered   ← Delivery boy marks as delivered
```

Exception states:

```
cancelled
failed
skipped
```

**State visibility:**
- `processing` → both vendor and customer see "Cooking"
- `out_for_delivery` → both vendor and customer see "In the Way"
- `delivered` → both vendor and customer see "Delivered"

---

## 10. Cooking Workflow (Vendor Side)

Vendor prepares food and processes orders.

```
Vendor clicks "Process Orders"
        ↓
Orders: pending → processing
        ↓
System:
  1. Sends FCM notification to each customer ("Your tiffin is being prepared")
  2. Notifies assigned delivery boy ("New delivery task ready")
```

---

## 11. Delivery Assignment

Vendor assigns a delivery boy to one or more orders.

```
Vendor
   ↓
Select orders for delivery
   ↓
Assign Delivery Boy
   ↓
Delivery boy receives FCM notification ("You have new deliveries")
```

Assignment sets `DailyOrder.deliveryStaffId`. Delivery boy can then **accept or reject** the task.

---

## 12. Delivery Boy Flow

Delivery boy app shows **Today's Deliveries**.

**Each delivery card shows:**
- Customer name
- Address
- Google Map location (navigate button)
- Call button (customer phone)
- Delivery status

**Delivery workflow:**

```
Delivery boy receives notification
   ↓
Accept task  OR  Reject task
   ↓ (if accepted)
Go to vendor, pick up parcel
   ↓
Mark "Out for delivery"
   → Status changes: processing → out_for_delivery
   → Vendor sees: "In the Way"
   → Customer sees: "In the Way" + FCM notification
   ↓
Navigate via Google Maps to customer address
   ↓
Deliver food
   ↓
Mark "Delivered"
   → Status changes: out_for_delivery → delivered
   → Vendor sees: "Delivered" + FCM notification
   → Customer sees: "Delivered" + FCM notification
   → Customer balance deducted automatically
```

**If task is rejected:**

```
Delivery boy rejects task
   ↓
Vendor gets notification: "Delivery boy rejected task"
   ↓
Vendor can reassign to another delivery boy
```

---

## 13. Wallet / Balance System

Customer pays cash offline to vendor. Vendor updates the balance in the app.

```
Customer pays vendor offline (cash/UPI)
   ↓
Vendor adds balance in app
   ↓
Customer.balance increases
   ↓
Daily Order delivered
   ↓
Customer.balance -= order amount (auto deducted)
```

**Example:**

```
Wallet = ₹1000
Lunch cost = ₹80

After delivery:
Wallet = ₹920
```

Balance is required to receive food. If balance is insufficient, vendor is notified.

---

## 14. Low Balance Notification

System checks balance after every delivery:

```
if Customer.balance < lowBalanceThreshold
   ↓
Send FCM to customer: "Low balance alert — please recharge"
Send FCM to vendor: "Customer [Name] has low balance"
```

**Vendor action on low balance:**

- Vendor dashboard shows list of **low balance customers**
- Vendor can click **customer phone number → opens WhatsApp directly**
- WhatsApp message example:

```
Hello Raj,
Your tiffin wallet balance is low (₹80 remaining).
Please recharge your account.
```

---

## 15. WhatsApp Integration

Clicking a customer's phone number opens WhatsApp:

- URL format: `https://wa.me/91XXXXXXXXXX`
- This is **client-side only** — backend returns phone number formatted as `+91XXXXXXXXXX`
- Available on: low balance customer list, customer detail screen

---

## 16. Delivery Tracking

Delivery boy broadcasts GPS location via Socket.IO.

```
Delivery boy app → sends location_update (lat, lng)
        ↓
Socket.IO → broadcasts to vendor room (admin:{ownerId})
        ↓
Vendor sees delivery boy live location on Google Maps
```

Socket namespace: `/delivery`
Event: `location_update { lat, lng, orderId }`

---

## 17. Customer App Flow

Customer logs in with phone + OTP (same auth system, role = customer).

**Customer features:**

```
Login with OTP
   ↓
Dashboard
```

Customer can:

- View their vendor-assigned meal plan
- View today's daily order and status
- Track delivery (see order state: cooking / in the way / delivered)
- Check wallet balance
- Edit profile (name, address, delivery location on Google Maps)
- Pause plan (date range — vacation, medical, etc.)
- **Edit meal plan quantities only** — increase/decrease item quantities; cannot add or remove items

---

## 18. Notifications

All notifications via **Firebase Cloud Messaging (FCM)** + in-app Notification record.

| Event                  | Who is notified         | Trigger                                    |
| ---------------------- | ----------------------- | ------------------------------------------ |
| Order processing       | Customer                | Vendor clicks Process Orders               |
| New task assigned      | Delivery boy            | Vendor assigns delivery boy to order       |
| Task rejected          | Vendor                  | Delivery boy rejects task                  |
| Out for delivery       | Customer + Vendor       | Delivery boy marks out_for_delivery        |
| Delivered              | Customer + Vendor       | Delivery boy marks delivered               |
| Low balance            | Customer + Vendor       | balance < lowBalanceThreshold after deduct |
| Plan assignment ending | Customer                | endDate reached (cron job)                 |

---

## 19. Payment Flow

### Offline (Vendor records in app)

- Cash
- UPI
- Bank transfer
- Cheque

Vendor records payment → `Customer.balance` increases.

### Online

- **Razorpay** — online payment link; webhook confirms capture

Both offline and online payments update `Customer.balance`.

---

## 20. Reports

Vendor dashboard reports:

- Today's deliveries (count + status breakdown)
- Active plan assignments
- Revenue (daily / weekly / monthly)
- Pending payments (customers with balance due)
- Plan assignments expiring in next N days
- Low balance customers list

---

## Complete Final Flow

```
Vendor (self-registers with own phone + OTP)
   ↓
Create Item Catalog (roti, sabji, dal, etc. with prices)
   ↓
Create Meal Plans (using items + quantities per meal slot)
   ↓
Add Customers (manual or bulk from contacts)
   ↓
Assign Meal Plan to Customer (pre-created or custom) — start/end date
   ↓
Daily Orders Generated (automatically by cron + on assignment)
   ↓
Customer may edit item quantities only (no add/remove)
   ↓
Vendor Process Orders → status: processing ("Cooking")
   ↓
Vendor Assigns Delivery Boy → Delivery boy notified
   ↓
Delivery Boy Accepts Task → picks up parcel
   ↓
Delivery Boy marks "Out for Delivery" → status: out_for_delivery ("In the Way")
   ↓
Delivery Boy Delivers → marks "Delivered" → status: delivered
   ↓
Customer Balance Auto-Deducted
   ↓
Notifications Sent (vendor + customer)
   ↓
Low balance check → notify if below threshold
```

Admin **does not create vendors** — monitors system only. **Subscription plans (platform tiers) removed.**

---

## Backend Entity Structure

```
User              — vendor / admin / customer / delivery_staff (all roles)
Customer          — created by vendor, has balance wallet
Item              — vendor's daily food item catalog (name, unitPrice, isActive)
MealPlan          — plan with meal slots + items + quantities
PlanAssignment    — (Subscription) links customer to plan with start/end date
DailyOrder        — one record per customer per day (core model)
DeliveryStaff     — delivery boy linked to vendor (ownerId)
Payment           — wallet credit (offline/Razorpay) and order deductions
Invoice           — billing document for a date range
Notification      — in-app notification records
Zone              — delivery zone grouping
AuditLog          — action audit trail
```

---

## Suggested Enhancements

### 1. Route Optimization

Automatically generate the best delivery route for a delivery boy's list using customer GPS coordinates.

### 2. Pause Meal

Customer can pause plan assignment for a date range (vacation, weekend, medical leave). Daily orders are skipped for paused dates.

---

_Document: Correct System Flow for TiffinCRM — Updated Mar 11, 2026. Reflects delivery boy accept/reject, item catalog, meal plan with items+quantities, and WhatsApp integration._
