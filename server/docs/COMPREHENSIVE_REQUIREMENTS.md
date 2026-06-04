# TiffinCRM Backend — COMPREHENSIVE REQUIREMENTS LIST

**Extracted from:** TiffinCRM_Backend_Final.pdf, TiffinCRM_Clone_Blueprint.pdf, TiffinCRM_Documentation.pdf  
**Last Updated:** February 27, 2026  
**Status:** 95% Feature-Complete | Ready for Testing & Production Hardening

---

## TABLE OF CONTENTS

1. [Authentication & Authorization](#authentication--authorization)
2. [User Roles & Permissions](#user-roles--permissions)
3. [Core API Endpoints](#core-api-endpoints)
4. [Database Models & Relationships](#database-models--relationships)
5. [External Integrations](#external-integrations)
6. [Real-time Features (WebSocket/Socket.io)](#real-time-features-websocketsocketio)
7. [Reporting & Analytics](#reporting--analytics)
8. [Security & Authorization Requirements](#security--authorization-requirements)
9. [Notification System](#notification-system)
10. [Business Logic & Features](#business-logic--features)
11. [Infrastructure & Deployment](#infrastructure--deployment)
12. [Technology Stack](#technology-stack)

---

## AUTHENTICATION & AUTHORIZATION

### OTP-Based Authentication Flow

#### Send OTP

- **Endpoint:** `POST /api/v1/auth/send-otp`
- **Authentication:** Public (no auth required)
- **Input:**
  - `phone` (required, string): 10-digit Indian mobile number
- **Processing:**
  - Validate phone format (10-digit Indian number)
  - Generate 6-digit numeric OTP
  - OTP Expiry: 10 minutes (configurable)
  - Delete existing OTP for phone (one active per phone)
  - Send via MSG91 API (or Twilio/Fast2SMS fallback)
  - Store hashed/plain OTP in database with TTL index
  - Returns success/failure with message
- **Rate Limiting:** 3 attempts per 10 minutes per phone number
- **Response:** `{ success: boolean, message?: string }`

#### Verify OTP

- **Endpoint:** `POST /api/v1/auth/verify-otp`
- **Authentication:** Public
- **Input:**
  - `phone` (required): 10-digit mobile
  - `otp` (required): 6-digit OTP code
- **Processing:**
  - Find OTP in database by phone
  - Check expiration (must not be expired)
  - Compare OTP code
  - Delete OTP document after verification
  - Find or create User in database
  - Generate JWT tokens (access + refresh)
  - Return tokens to client
- **Error Handling:**
  - Invalid OTP format
  - Expired OTP
  - Phone not found
  - OTP mismatch
- **Response:** `{ success: boolean, accessToken: string, refreshToken: string, user: UserObject }`

#### Refresh Token

- **Endpoint:** `POST /api/v1/auth/refresh-token`
- **Authentication:** Required (Bearer token)
- **Input:**
  - `refreshToken` (required, in body or Authorization header)
- **Processing:**
  - Verify refresh token signature
  - Extract user ID from token
  - Generate new access token (short-lived: 15 minutes)
  - Optional: rotate refresh token (issue new long-lived token)
  - Log token rotation event
- **Response:** `{ success: boolean, accessToken: string, refreshToken?: string }`

#### Logout

- **Endpoint:** `POST /api/v1/auth/logout`
- **Authentication:** Required (Bearer token)
- **Processing:**
  - Invalidate refresh token (optional blocklist in Redis)
  - Clear session data if any
  - Log logout event
- **Response:** `{ success: boolean, message: "Logged out successfully" }`

#### Update User Profile

- **Endpoint:** `PUT /api/v1/auth/me`
- **Authentication:** Required
- **Input:**
  - `ownerName` (optional): Business owner's name
  - `businessName` (optional): Business/Tiffin shop name
  - `email` (optional): Business email
  - `address` (optional): Business address
  - `city`, `state` (optional): Location
  - `logoUrl` (optional): Business logo
  - `fcmToken` (optional): Firebase Cloud Messaging token for notifications
- **Response:** `{ success: boolean, user: UpdatedUserObject }`

### JWT Token Management

#### Access Token

- **Expiry:** 15 minutes (short-lived)
- **Secret:** `JWT_ACCESS_SECRET` (environment variable)
- **Payload:** `{ userId, phone, iat, exp }`

#### Refresh Token

- **Expiry:** 7 days (long-lived)
- **Secret:** `JWT_REFRESH_SECRET` (environment variable)
- **Payload:** `{ userId, phone, iat, exp }`
- **Optional:** Implement refresh token rotation (issue new token on each refresh)

#### Token Verification Middleware

- **Location:** `/middleware/auth.middleware.js`
- **Behavior:**
  - Extract Bearer token from `Authorization` header
  - Verify token signature and expiration
  - Attach user data to `req.user = { userId, phone }`
  - Return 401 on invalid/expired token
  - Pass to next middleware on valid token

---

## USER ROLES & PERMISSIONS

### User Types

#### 1. Business Owner/Admin

- **Default Role:** `admin`
- **Capabilities:**
  - Full CRUD on all resources (customers, plans, subscriptions, payments, deliveries)
  - View all reports and analytics
  - Manage delivery staff and zones
  - Configure business settings
  - Manage invoices and payments
  - View audit logs
  - Manage daily menus and inventory
  - Control notification preferences

#### 2. Delivery Staff/Delivery Boy

- **Role:** `delivery` (potential)
- **Capabilities:**
  - View today's delivery list
  - Update delivery status (in_transit, delivered, cancelled)
  - Broadcast real-time location via Socket.io
  - Mark deliveries complete
  - View assigned deliveries only
  - Receive push notifications

#### 3. Customer (via Flutter App)

- **Indirect access through:**
  - Subscription management (create, view, renew, cancel)
  - Payment tracking
  - Invoice access (share token system)
  - Delivery tracking (real-time location)
  - Notification preferences

### Permission Matrix

| Resource       | Owner | Delivery Staff    |
| -------------- | ----- | ----------------- |
| Customers      | CRUD  | Read (assigned)   |
| Plans          | CRUD  | Read              |
| Subscriptions  | CRUD  | Read              |
| Payments       | CRUD  | Read              |
| Deliveries     | CRUD  | Update (assigned) |
| Reports        | Read  | Read (limited)    |
| Invoices       | CRUD  | Read              |
| Daily Menu     | CRUD  | Read              |
| Inventory      | CRUD  | Read              |
| Zones          | CRUD  | Read              |
| Delivery Staff | CRUD  | Read              |

---

## CORE API ENDPOINTS

### Authentication Endpoints

```
POST   /api/v1/auth/send-otp          → Send OTP to phone
POST   /api/v1/auth/verify-otp        → Verify OTP, get JWT
POST   /api/v1/auth/refresh-token     → Refresh access token
POST   /api/v1/auth/logout            → Logout, invalidate tokens
PUT    /api/v1/auth/me                → Update profile
```

### Customer Management Endpoints

```
GET    /api/v1/customers              → List customers (paginated, filterable)
GET    /api/v1/customers/:id          → Get customer by ID
POST   /api/v1/customers              → Create customer
PUT    /api/v1/customers/:id          → Update customer
DELETE /api/v1/customers/:id          → Delete customer (soft or hard)
POST   /api/v1/customers/bulk         → Bulk import customers (rate-limited: 5 per 15 min)
```

**Customer Fields:**

- `name` (required): Full name
- `phone` (required, unique): 10-digit mobile number
- `email` (optional): Email address (lowercase, unique)
- `address` (required): Delivery address
- `area` (optional): Delivery area name
- `landmark` (optional): Landmark/reference point
- `location` (GeoJSON): GPS coordinates `{ type: "Point", coordinates: [lng, lat] }`
- `photoUrl` (optional): Customer photo
- `notes` (optional): Internal notes
- `tags` (array): Custom tags
- `customerCode` (auto-generated): e.g., C001, C002...
- `status` (enum): `active`, `inactive`, `blocked`
- `balance` (number, default 0): Account balance
- `creditLimit` (number): Maximum credit allowed
- `totalDue` (number): Total amount outstanding
- `fcmToken` (optional): Firebase token for notifications
- `whatsapp` (optional): WhatsApp number
- `isDeleted` (boolean): Soft delete flag
- `timestamps`: `createdAt`, `updatedAt`

**Query Parameters:**

- `page` (default: 1): Page number for pagination
- `limit` (default: 10, max: 100): Items per page
- `status` (optional): Filter by status (active, inactive, blocked)
- `search` (optional): Search by name or phone
- `sort` (optional): Sort field and direction (e.g., `-createdAt`)

### Plan Management Endpoints

```
GET    /api/v1/plans                  → List plans
GET    /api/v1/plans/:id              → Get plan by ID
POST   /api/v1/plans                  → Create plan
PUT    /api/v1/plans/:id              → Update plan
```

**Plan Fields:**

- `name` (required): Plan name (e.g., "Breakfast Tiffin")
- `type` (enum): `breakfast`, `lunch`, `dinner`, `custom`
- `price` (required): Price per unit
- `frequency` (enum): `daily`, `weekly`, `monthly`
- `description` (optional): Plan description
- `isActive` (boolean, default: true): Enable/disable plan
- `timestamps`: `createdAt`, `updatedAt`

### Subscription Management Endpoints

```
GET    /api/v1/subscriptions          → List subscriptions (paginated, filterable)
GET    /api/v1/subscriptions/:id      → Get subscription by ID
POST   /api/v1/subscriptions          → Create new subscription
PUT    /api/v1/subscriptions/:id/renew → Renew (extend) subscription
PUT    /api/v1/subscriptions/:id/cancel → Cancel subscription
```

**Subscription Fields:**

- `customerId` (required, FK): Reference to Customer
- `planId` (required, FK): Reference to Plan
- `startDate` (required): Subscription start date
- `endDate` (required): Subscription end date (calculated from billingPeriod)
- `deliverySlot` (enum): `morning`, `afternoon`, `evening`
- `deliveryDays` (array of numbers): Days of week [0-6] (0=Sunday, 6=Saturday)
- `status` (enum): `active`, `paused`, `expired`, `cancelled`
- `billingPeriod` (enum): `daily`, `weekly`, `monthly` (used to calculate endDate)
- `autoRenew` (boolean): Auto-renew on expiry
- `totalAmount` (required): Total subscription cost
- `paidAmount` (number, default: 0): Amount already paid
- `pausedFrom`, `pausedUntil` (dates): Pause period dates
- `notes` (optional): Subscription notes
- `paymentId` (FK, optional): Last payment reference
- `timestamps`: `createdAt`, `updatedAt`

**Business Logic:**

- On creation: Calculate `endDate` from `startDate + billingPeriod`
- On renewal: Extend `endDate` by `billingPeriod`
- On cancellation: Set status to `cancelled`
- Automatic expiry: Cron job daily sets status to `expired` for past endDate subscriptions
- Delivery generation: Active subscriptions generate daily delivery orders

**Filters:**

- `customerId`: Filter by customer
- `status`: active, paused, expired, cancelled
- `planId`: Filter by plan
- `startDate`, `endDate`: Date range filtering

### Payment Management Endpoints

```
GET    /api/v1/payments               → List payments (paginated, filterable)
POST   /api/v1/payments               → Record manual payment (cash, cheque, bank transfer)
POST   /api/v1/payments/create-order  → Create Razorpay order for online payment
GET    /api/v1/payments/:id/invoice   → Get/download invoice PDF
```

**Payment Fields:**

- `customerId` (required, FK): Reference to Customer
- `invoiceId` (optional, FK): Reference to Invoice
- `subscriptionId` (optional, FK): Reference to Subscription
- `amount` (required, min: 0.01): Payment amount
- `paymentMethod` (required, enum): `cash`, `upi`, `bank_transfer`, `cheque`, `razorpay`, `other`
- `paymentDate` (date): When payment was made
- `transactionRef` (optional, string): Reference number (bank, cheque, UPI)
- `notes` (optional): Internal notes
- `receiptUrl` (optional): Receipt document URL
- `razorpayOrderId` (optional): Razorpay order ID
- `razorpayPaymentId` (optional, unique): Razorpay payment ID
- `razorpaySignature` (optional): Signature for verification
- `timestamps`: `createdAt`, `updatedAt`

**Unique Indexes:**

- `razorpayPaymentId` (sparse, unique): Prevent duplicate payments

**Features:**

- Manual payment recording: Cash, cheque, bank transfer, UPI
- Razorpay integration: Create orders, process payments, verify webhook
- Payment verification: Signature validation for Razorpay webhooks
- Idempotency: Webhook handler prevents duplicate payment recording

### Invoice Management Endpoints

```
GET    /api/v1/invoices               → List invoices (paginated, filterable)
GET    /api/v1/invoices/:id           → Get invoice by ID
POST   /api/v1/invoices/generate      → Generate invoices for date range
PUT    /api/v1/invoices/:id           → Update invoice
GET    /api/v1/invoices/:id/void      → Void/cancel invoice
POST   /api/v1/invoices/:id/share     → Generate share token (customer access)
GET    /api/v1/invoices/overdue       → Get overdue invoices
```

**Invoice Fields:**

- `invoiceNumber` (required, unique): Auto-generated (INV-001, INV-002...)
- `customerId` (required, FK): Reference to Customer
- `subscriptionId` (optional, FK): Reference to Subscription
- `billingStart`, `billingEnd` (required): Billing period start and end dates
- `lineItems` (array): Line items with description, quantity, unitPrice, amount
- `subtotal` (required): Pre-discount, pre-tax amount
- `discountType` (enum, optional): `flat`, `percent`, or null
- `discountValue` (number, default: 0): Discount amount or percentage
- `discountAmount` (number, default: 0): Calculated flat discount
- `taxPercent` (number, default: 0): Tax percentage (e.g., 18 for 18% GST)
- `taxAmount` (number, default: 0): Calculated tax
- `netAmount` (required): Final amount = subtotal - discount + tax
- `paidAmount` (number, default: 0): Amount paid so far
- `balanceDue` (number, default: 0): Remaining due
- `paymentStatus` (enum): `unpaid`, `partial`, `paid`
- `shareToken` (optional): Public access token (for customer invoice sharing)
- `shareTokenExpiresAt` (optional): Expiry time for share token
- `timestamps`: `createdAt`, `updatedAt`

**Features:**

- Batch generation: Generate invoices for customers with subscriptions in a date range
- Discounts: Flat or percentage-based
- Taxes: GST/VAT calculations
- Payment tracking: Track paid vs. balance due
- Share tokens: Generate public tokens for customers to view invoices
- Void functionality: Cancel invoices while maintaining audit trail
- Overdue tracking: Query invoices past due date

### Daily Order (Delivery) Endpoints

```
GET    /api/v1/daily-orders/today     → Get today's delivery list
POST   /api/v1/daily-orders/process   → Process today's orders
POST   /api/v1/daily-orders/mark-delivered → Mark delivery complete
POST   /api/v1/daily-orders/generate  → Manually generate daily orders
GET    /api/v1/daily-orders/debug/subscriptions → Debug: list subscriptions
GET    /api/v1/daily-orders/debug/subscription/:id → Debug: match subscriptions
GET    /api/v1/daily-orders/debug/match → Debug: match for specific date
```

**Daily Order Fields:**

- `customerId` (required, FK): Reference to Customer
- `subscriptionId` (optional, FK): Reference to Subscription
- `planId` (optional, FK): Reference to Plan
- `orderId` (optional, FK): Reference to Order
- `orderDate` (required): Delivery date
- `mealType` (enum, required): `lunch`, `dinner`, `both`
- `deliverySlot` (enum): `morning`, `afternoon`, `evening`
- `deliveryStaffId` (optional, FK): Assigned delivery staff
- `resolvedItems` (array): Actual items to deliver (name, quantity)
- `amount` (optional): Delivery charge
- `isCharged` (boolean, default: false): Whether amount is charged
- `status` (enum): `pending`, `processing`, `out_for_delivery`, `delivered`, `cancelled`, `failed`, `skipped`
- `cancelledBy` (enum): `customer`, `owner`, or null
- `cancellationReason` (optional): Reason for cancellation
- `cancelledAt` (date): Cancellation timestamp
- `timestamps`: `createdAt`, `updatedAt`

**Delivery Auto-Generation (Cron Job)**

- **Trigger:** Daily at 00:00 (configurable)
- **Process:**
  1. Find all active subscriptions
  2. Filter by delivery schedule (deliveryDays matching today)
  3. Create DailyOrder for each matching subscription if not exists
  4. Assign to delivery staff (optional logic)
  5. Set status to `pending`
- **File:** `/jobs/deliveryCron.js`

**Linked Delivery Endpoint:**

```
GET    /api/v1/delivery/              → Alias for /daily-orders/today
```

### Delivery Management Endpoints

```
GET    /api/v1/delivery/              → Today's delivery list (alias)
```

**Note:** Delivery operations primarily handled through `/daily-orders/` endpoints. `/delivery/` namespace reserved for real-time Socket.io events.

### Report & Analytics Endpoints

```
GET    /api/v1/reports/summary        → Summary report (period: daily/weekly/monthly)
```

**Query Parameters:**

- `period` (optional, enum): `daily`, `weekly`, `monthly` (default: monthly)

**Report Data:**

- `activeSubscriptions` (number): Count of active subscriptions
- `revenue` (number): Total revenue in period
- `deliveries` (number): Count of successful deliveries
- `period` (string): Reporting period
- `expiredSubscriptions` (number, optional): Subscriptions expired in period
- `totalCustomers` (number, optional): Total customer count
- `averageOrderValue` (number, optional): Average transaction value

**Aggregation Pipeline:**

- Subscription status counts by period
- Payment aggregation (sum by period)
- Delivery status counts
- Revenue calculation from payments

### Notification Management Endpoints

```
POST   /api/v1/notifications/test     → Send test notification (admin only)
```

**Test Notification:**

- Sends test push via Firebase to owner's FCM token
- Verify notification delivery setup

### Webhook Endpoints

```
POST   /api/v1/webhooks/razorpay      → Razorpay webhook handler (raw body)
```

**Razorpay Webhook:**

- **Event:** `payment.captured`
- **Signature Verification:** Verify `X-Razorpay-Signature` header
- **Idempotency:** Check if `razorpayPaymentId` already exists
- **Processing:**
  1. Verify webhook signature
  2. Extract payment ID from event
  3. Create/update Payment record
  4. Update subscription payment status if applicable
  5. Generate invoice if applicable
  6. Send notification to customer
  7. Return 200 OK

### Public Endpoints (No Auth Required)

```
GET    /api/v1/public/health          → Health check (API version)
GET    /api/v1/public/invoice/:shareToken → Get invoice by share token (public)
GET    /api/v1/public/customer-report/:token → Get customer report by token (public)
GET    /health                        → System health check (DB connection status)
```

---

## DATABASE MODELS & RELATIONSHIPS

### Model: User (Business Owner)

**Collection:** `users`

**Schema:**

```javascript
{
  // Business Info
  businessName: String,
  ownerName: String,
  phone: String (unique, required),
  email: String (unique, sparse, lowercase),
  address: String,
  city: String,
  state: String (default: "Maharashtra"),
  logoUrl: String,

  // App Info
  fcmToken: String,
  appVersion: String,
  subscriptionPlan: Enum ["free", "basic", "premium"],
  planExpiresAt: Date,
  isActive: Boolean (default: true),

  // Billing
  invoiceCounter: Number (default: 0),

  // Settings
  settings: {
    timezone: String (default: "Asia/Kolkata"),
    currency: String (default: "INR"),
    orderProcessCutoff: String (default: "10:00"),
    autoGenerateInvoice: Boolean (default: false),
    whatsappEnabled: Boolean (default: true),
    emailEnabled: Boolean (default: false),
    notifyCustomerOnProcess: Boolean (default: true),
    notifyCustomerOnDelivery: Boolean (default: true)
  },

  // Timestamps
  createdAt: Date,
  updatedAt: Date
}
```

**Indexes:**

- `phone` (unique): Quick lookup by phone
- `email` (sparse, unique): Email lookups

**Relationships:**

- 1 User → Many Deliveries (assigned_to)
- 1 User → Many Customers (owns)
- 1 User → Many Subscriptions (owns)
- 1 User → Many Payments (owns)
- 1 User → Many Invoices (owns)
- 1 User → Many Zones (owns)
- 1 User → Many DeliveryStaff (owns)
- 1 User → Many DailyMenus (owns)
- 1 User → Many RawMaterials (owns)
- 1 User → Many DailyOrders (owns)
- 1 User → Many AuditLogs (tracks)

### Model: Customer

**Collection:** `customers`

**Schema:**

```javascript
{
  ownerId: ObjectId (FK, required, indexed),
  name: String (required),
  phone: String (required),
  email: String (lowercase, unique, sparse),
  address: String (required),
  area: String,
  landmark: String,
  location: {
    type: "Point",
    coordinates: [Number, Number] // [lng, lat]
  },
  photoUrl: String,
  notes: String,
  tags: [String],
  customerCode: String, // Auto: C001, C002...
  status: Enum ["active", "inactive", "blocked"] (default: "active"),
  balance: Number (default: 0),
  creditLimit: Number (default: 0),
  totalDue: Number,
  fcmToken: String,
  whatsapp: String,
  isDeleted: Boolean (default: false),
  reportToken: String (optional),
  reportTokenExpiresAt: Date (optional),
  createdAt: Date,
  updatedAt: Date
}
```

**Indexes:**

- `ownerId, phone` (compound): Find customers by owner
- `status`: Filter active/inactive
- `createdAt`: Sort by creation
- `location` (2dsphere, optional): Geo-spatial queries

**Relationships:**

- 1 Customer → Many Subscriptions (has)
- 1 Customer → Many Deliveries (receives)
- 1 Customer → Many Payments (makes)
- 1 Customer → Many DailyOrders (receives)
- 1 Customer → Many Invoices (billed)

### Model: Plan

**Collection:** `plans`

**Schema:**

```javascript
{
  ownerId: ObjectId (FK, required),
  name: String (required),
  type: Enum ["breakfast", "lunch", "dinner", "custom"],
  price: Number (required),
  frequency: Enum ["daily", "weekly", "monthly"],
  description: String,
  isActive: Boolean (default: true),
  createdAt: Date,
  updatedAt: Date
}
```

**Indexes:**

- `ownerId`: Owner's plans

**Relationships:**

- 1 Plan → Many Subscriptions (subscribed_as)

### Model: Subscription

**Collection:** `subscriptions`

**Schema:**

```javascript
{
  ownerId: ObjectId (FK, required),
  customerId: ObjectId (FK, required),
  planId: ObjectId (FK, required),
  startDate: Date (required),
  endDate: Date (required),
  deliverySlot: Enum ["morning", "afternoon", "evening"] (default: "morning"),
  deliveryDays: [Number] (default: [0,1,2,3,4,5,6]),
  status: Enum ["active", "paused", "expired", "cancelled"] (default: "active"),
  billingPeriod: Enum ["daily", "weekly", "monthly"],
  autoRenew: Boolean (default: false),
  totalAmount: Number (required),
  paidAmount: Number (default: 0),
  pausedFrom: Date,
  pausedUntil: Date,
  notes: String,
  paymentId: ObjectId (FK, optional),
  createdAt: Date,
  updatedAt: Date
}
```

**Indexes:**

- `ownerId, customerId, status` (compound): Filter by user and customer
- `ownerId, endDate` (compound): Expiry check
- `status`: Status-based queries

**Relationships:**

- 1 Subscription → Many DailyOrders (generates)
- 1 Subscription → Many Deliveries (generates)
- 1 Subscription ← 0..1 Payment (last_payment)

### Model: Payment

**Collection:** `payments`

**Schema:**

```javascript
{
  ownerId: ObjectId (FK, required),
  customerId: ObjectId (FK, required),
  invoiceId: ObjectId (FK, optional),
  subscriptionId: ObjectId (FK, optional),
  amount: Number (required, min: 0.01),
  paymentMethod: Enum ["cash", "upi", "bank_transfer", "cheque", "razorpay", "other"],
  paymentDate: Date (default: now),
  transactionRef: String,
  notes: String,
  receiptUrl: String,
  razorpayOrderId: String,
  razorpayPaymentId: String (unique, sparse),
  razorpaySignature: String,
  createdAt: Date,
  updatedAt: Date
}
```

**Indexes:**

- `ownerId, customerId` (compound): Filter by owner and customer
- `razorpayPaymentId` (sparse, unique): Prevent duplicates

**Relationships:**

- 1 Payment ← 1 Invoice (optional)
- 1 Payment ← 1 Subscription (optional)

### Model: Invoice

**Collection:** `invoices`

**Schema:**

```javascript
{
  ownerId: ObjectId (FK, required),
  customerId: ObjectId (FK, required),
  subscriptionId: ObjectId (FK, optional),
  invoiceNumber: String (unique, required), // INV-001, INV-002...
  billingStart: Date (required),
  billingEnd: Date (required),
  lineItems: [{
    description: String,
    quantity: Number,
    unitPrice: Number,
    amount: Number
  }],
  subtotal: Number (required),
  discountType: Enum ["flat", "percent", null],
  discountValue: Number (default: 0),
  discountAmount: Number (default: 0),
  taxPercent: Number (default: 0),
  taxAmount: Number (default: 0),
  netAmount: Number (required),
  paidAmount: Number (default: 0),
  balanceDue: Number (default: 0),
  paymentStatus: Enum ["unpaid", "partial", "paid"] (default: "unpaid"),
  shareToken: String (optional),
  shareTokenExpiresAt: Date (optional),
  createdAt: Date,
  updatedAt: Date
}
```

**Indexes:**

- `invoiceNumber` (unique): Quick lookup
- `customerId`: Customer invoices
- `billingStart, billingEnd` (compound): Date range queries

**Relationships:**

- 1 Invoice → 1 Customer (billed_to)
- 1 Invoice ← 1 Subscription (optional)
- 1 Invoice → Many Payments (paid_by)

### Model: DailyOrder

**Collection:** `dailyorders`

**Schema:**

```javascript
{
  ownerId: ObjectId (FK, required),
  customerId: ObjectId (FK, required),
  subscriptionId: ObjectId (FK, optional),
  planId: ObjectId (FK, optional),
  orderId: ObjectId (FK, optional),
  orderDate: Date (required),
  mealType: Enum ["lunch", "dinner", "both"] (required),
  deliverySlot: Enum ["morning", "afternoon", "evening"],
  deliveryStaffId: ObjectId (FK, optional),
  resolvedItems: [{
    name: String,
    quantity: Number
  }],
  amount: Number,
  isCharged: Boolean (default: false),
  status: Enum ["pending", "processing", "out_for_delivery", "delivered", "cancelled", "failed", "skipped"],
  cancelledBy: Enum ["customer", "owner", null],
  cancellationReason: String,
  cancelledAt: Date,
  createdAt: Date,
  updatedAt: Date
}
```

**Indexes:**

- `ownerId, orderDate` (compound): Daily orders for owner
- `status`: Status filtering

**Relationships:**

- 1 DailyOrder → 1 Customer (delivers_to)
- 1 DailyOrder → 1 Subscription (from)
- 1 DailyOrder → 1 DeliveryStaff (assigned_to, optional)

### Model: Delivery (Legacy)

**Collection:** `deliveries`

**Schema:**

```javascript
{
  customerId: ObjectId (FK, required),
  subscriptionId: ObjectId (FK, required),
  date: Date (required),
  status: Enum ["pending", "in_progress", "delivered", "cancelled"],
  deliveryBoyId: ObjectId (FK, optional),
  location: {
    type: "Point",
    coordinates: [Number, Number] // [lng, lat]
  },
  completedAt: Date,
  createdAt: Date,
  updatedAt: Date
}
```

**Note:** Largely replaced by DailyOrder model for more functionality.

### Model: DeliveryStaff

**Collection:** `deliverystaffs`

**Schema:**

```javascript
{
  ownerId: ObjectId (FK, required),
  name: String (required),
  phone: String (required),
  areas: [String],
  zones: [ObjectId (FK to Zone)],
  fcmToken: String,
  isActive: Boolean (default: true),
  joiningDate: Date,
  createdAt: Date,
  updatedAt: Date
}
```

**Indexes:**

- `ownerId`: Owner's staff

**Relationships:**

- 1 DeliveryStaff ← Many DailyOrders (assigned_to)
- 1 DeliveryStaff → Many Zones (covers)

### Model: Zone

**Collection:** `zones`

**Schema:**

```javascript
{
  ownerId: ObjectId (FK, required),
  name: String (required),
  description: String,
  color: String,
  isActive: Boolean (default: true),
  createdAt: Date,
  updatedAt: Date
}
```

**Relationships:**

- 1 Zone ← Many DeliveryStaffs (assigned_to)
- 1 Zone ← Many Customers (belongs_to, optional)

### Model: DailyMenu

**Collection:** `dailymenus`

**Schema:**

```javascript
{
  ownerId: ObjectId (FK, required),
  date: Date (required),
  mealTime: Enum ["breakfast", "lunch", "dinner"],
  items: [{
    placeholder: String,
    actualName: String,
    quantity: Number
  }],
  notes: String,
  createdAt: Date,
  updatedAt: Date
}
```

**Unique Index:**

- `ownerId, date, mealTime` (compound, unique): One menu per meal per day

**Features:**

- Plan daily meal menus
- Template-based items
- Quantity tracking
- Notes for special instructions

### Model: RawMaterial (Inventory)

**Collection:** `rawmaterials`

**Schema:**

```javascript
{
  ownerId: ObjectId (FK, required),
  name: String (required),
  unit: Enum ["kg", "g", "litre", "ml", "piece", "packet", "bunch"],
  currentStock: Number (default: 0),
  minimumStock: Number (default: 0),
  costPerUnit: Number (default: 0),
  category: String,
  isActive: Boolean (default: true),
  createdAt: Date,
  updatedAt: Date
}
```

**Features:**

- Track ingredients/supplies
- Low-stock alerts (when currentStock < minimumStock)
- Cost tracking
- Categories for organization

### Model: Order

**Collection:** `orders`

**Schema:**

```javascript
{
  ownerId: ObjectId (FK, required),
  customerId: ObjectId (FK, required),
  mealTime: Enum ["breakfast", "lunch", "dinner"] (required),
  itemsRaw: String,
  items: [{
    name: String,
    quantity: { type: Number, default: 1 }
  }],
  price: Number (required),
  orderType: Enum ["repeat", "one_time"] (default: "repeat"),
  frequency: Enum ["daily", "custom"] (default: "daily"),
  activeDays: [Enum ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]],
  startDate: Date (required),
  endDate: Date,
  status: Enum ["active", "paused", "cancelled", "completed"] (default: "active"),
  isDeleted: Boolean (default: false),
  createdAt: Date,
  updatedAt: Date
}
```

**Indexes:**

- `ownerId, customerId` (compound): Customer orders
- `status, startDate` (compound): Active orders

**Purpose:** Generic order model for flexible ordering (one-time, custom, special requests)

### Model: Notification

**Collection:** `notifications`

**Schema:**

```javascript
{
  ownerId: ObjectId (FK, optional),
  customerId: ObjectId (FK, optional),
  type: String (required),
  title: String (required),
  message: String (required),
  data: Mixed (optional),
  isRead: Boolean (default: false),
  channel: Enum ["push", "email", "whatsapp", "in_app"],
  sentAt: Date (default: now),
  createdAt: Date,
  updatedAt: Date
}
```

**Use Cases:**

- Subscription expired
- Delivery completed
- Payment received
- Invoice generated
- System alerts
- Promotional messages

### Model: AuditLog

**Collection:** `auditlogs`

**Schema:**

```javascript
{
  ownerId: ObjectId (FK, required),
  action: String (required),
  resource: String,
  resourceId: ObjectId,
  details: Mixed,
  ip: String,
  userAgent: String,
  createdAt: Date,
  updatedAt: Date
}
```

**Tracked Actions:**

- Customer created/updated/deleted
- Subscription created/renewed/cancelled
- Payment recorded
- Invoice generated
- Delivery status changed
- Order processed

### Model: OTP

**Collection:** `otps`

**Schema:**

```javascript
{
  phone: String (required, indexed),
  otp: String,
  expiresAt: Date (TTL index), // 10-minute expiry
  createdAt: Date
}
```

**TTL Index:** Automatically removes expired OTPs after 10 minutes

**Relationships:**

- Standalone model (no FKs)

### ER Diagram Summary

```
User (1) ----→ (Many) Customer
            ----→ (Many) Subscription
            ----→ (Many) Payment
            ----→ (Many) Invoice
            ----→ (Many) DailyOrder
            ----→ (Many) Delivery
            ----→ (Many) DeliveryStaff
            ----→ (Many) Zone
            ----→ (Many) DailyMenu
            ----→ (Many) RawMaterial
            ----→ (Many) AuditLog

Customer (1) ---→ (Many) Subscription
            ---→ (Many) Delivery
            ---→ (Many) Payment
            ---→ (Many) DailyOrder
            ---→ (Many) Invoice

Plan (1) ---→ (Many) Subscription

Subscription (1) ---→ (Many) Delivery
              ---→ (Many) DailyOrder
              ---→ (0..1) Payment (last payment)

Invoice (1) ←--- (Many) Payment

Zone (1) ←--- (Many) DeliveryStaff

OTP (Standalone - no relationships)
```

---

## EXTERNAL INTEGRATIONS

### 1. SMS/OTP Provider

#### MSG91 (Primary)

**Configuration:**

- **API Key:** `MSG91_AUTH_KEY` (environment variable)
- **Template ID:** `MSG91_TEMPLATE_ID` (environment variable)
- **Endpoint:** `https://control.msg91.com/api/v5/otp`

**OTP Sending:**

- **Method:** POST
- **Headers:**
  - `authkey`: API key
  - `Content-Type`: application/json
- **Body:**
  ```json
  {
    "template_id": "TEMPLATE_ID",
    "mobile": "91XXXXXXXXXX",
    "otp": "XXXXXX",
    "otp_expiry": 10,
    "otp_length": 6
  }
  ```
- **Rate Limiting:** 3 per 10 min per phone
- **Fallback:** If API key not set, OTP saved locally (dev mode)

#### Twilio (Alternative)

- Available as alternative SMS provider
- Configuration via environment variables
- Same OTP flow, different API endpoint

#### Fast2SMS (Alternative)

- Another fallback SMS provider
- Rate limiting and expiry handling same as MSG91

### 2. Payment Gateway: Razorpay

**Configuration:**

- **Key ID:** `RAZORPAY_KEY_ID` (environment variable)
- **Secret:** `RAZORPAY_SECRET` (environment variable)
- **Webhook Secret:** `RAZORPAY_WEBHOOK_SECRET` (environment variable)

**Integration Points:**

#### Order Creation

- **Endpoint:** `/api/v1/payments/create-order` (POST)
- **Parameters:**
  - `amount` (required): Amount in paise (multiply INR by 100)
  - `receipt` (optional): Reference ID (paymentId or subscriptionId)
- **Razorpay Call:**
  ```javascript
  const order = await razorpay.orders.create({
    amount: amountInPaise,
    currency: "INR",
    receipt: receiptId,
    payment_capture: 1, // Auto-capture
  });
  ```
- **Response:** `{ orderId, key_id }` sent to Flutter for checkout

#### Webhook Handler

- **Endpoint:** `POST /api/v1/webhooks/razorpay`
- **Event:** `payment.captured`
- **Signature Verification:**
  ```
  X-Razorpay-Signature = hmac_sha256(
    "{order_id}|{payment_id}",
    RAZORPAY_WEBHOOK_SECRET
  )
  ```
- **Processing:**
  1. Verify signature
  2. Extract payment ID from event
  3. Create Payment record with razorpay details
  4. Update subscription status
  5. Generate invoice PDF
  6. Send FCM notification
  7. Return 200 OK

#### Payment Verification (Manual)

- Store `razorpayOrderId`, `razorpayPaymentId`, `razorpaySignature`
- Prevent duplicate payments via unique index on `razorpayPaymentId`
- Idempotent webhook handling

### 3. Firebase Cloud Messaging (FCM)

**Configuration:**

- **Service Account:** `config/tiffincrm-a0ff5-firebase-adminsdk-fbsvc-346a83d866.json`
- **Admin SDK:** `firebase-admin` v13.6.1

**Initialization:**

```javascript
import admin from "firebase-admin";
import serviceAccount from "./firebase-adminsdk.json";

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});
```

**FCM Token Management:**

- Store FCM tokens on User and Customer models
- Update tokens on app startup (via `/auth/verify-otp` or separate endpoint)
- Remove invalid tokens on send failure

**Push Notifications:**

- **Endpoint:** Internal service call (not exposed as API)
- **Triggers:**
  - Subscription expiry
  - Delivery status changes
  - Payment received
  - Invoice generated
  - Manual admin sends
- **Structure:**
  ```
  {
    token: "FCM_TOKEN",
    notification: {
      title: "Subscription Expiring",
      body: "Your tiffin subscription expires in 3 days"
    },
    data: {
      subscriptionId: "...",
      expiresAt: "2026-03-01"
    }
  }
  ```
- **Error Handling:**
  - Invalid token → Remove from database
  - Sends up to 500 tokens in multicast if scaling
  - Firebase Admin SDK handles retries

**Service Function:**

```javascript
export const sendToToken = async(token, title, body, (data = {}));
```

### 4. File Storage: Cloudinary

**Configuration:**

- **API Key/Secret:** Environment variables
- **Folder:** tiffin_crm (organized uploads)

**Use Cases:**

#### Invoice PDFs

- Generate PDF via pdfkit
- Upload to Cloudinary
- Store URL on Invoice.receiptUrl or Payment.receiptUrl
- Return public URL to client

#### Customer Photos

- Upload via API endpoint (future)
- Store URL on Customer.photoUrl
- Return URL for profile display

#### Business Logo

- Upload on business setup
- Store URL on User.logoUrl
- Return URL for branding

**Implementation:**

```javascript
import cloudinary from "cloudinary";
const result = await cloudinary.v2.uploader.upload(filePath, {
  folder: "tiffin_crm/invoices",
  public_id: `invoice_${invoiceId}`,
});
const publicUrl = result.secure_url;
```

### 5. GPS / Location Service

**Status:** Documented, not fully integrated

**Features:**

- Customer location: GeoJSON Point coordinates stored in Customer.location
- Delivery tracking: DailyOrder resolution includes customer location
- Real-time location: Delivery staff broadcast location via Socket.io

**Potential Integrations:**

- Google Maps API (distance, directions)
- Mapbox (alternative)
- Native GPS from Flutter app

**Data Model:**

```
location: {
  type: "Point",
  coordinates: [longitude, latitude]
}
```

### 6. Automated Jobs

#### Daily Delivery Generation Cron

**File:** `/jobs/deliveryCron.js`

**Schedule:** Daily at 00:00 (configurable)

**Process:**

1. Find all active subscriptions for today
2. Filter by deliveryDays (match current weekday)
3. Create DailyOrder for each matching subscription
4. Set status = "pending"
5. Assign delivery staff (optional)

**Implementation:**

```javascript
import cron from "node-cron";

cron.schedule("0 0 * * *", async () => {
  const subscriptions = await Subscription.find({
    status: "active",
    deliveryDays: currentDayOfWeek,
  });
  // Create orders for each
});
```

#### Subscription Expiry Cron

**File:** `/jobs/subscriptionExpiryCron.js`

**Schedule:** Daily at 23:00 (before midnight)

**Process:**

1. Find subscriptions where endDate < today
2. Update status = "expired"
3. Send FCM notification to customer
4. Log audit entry

**Implementation:**

```javascript
const expiredSubs = await Subscription.updateMany(
  { endDate: { $lt: new Date() }, status: { $ne: "expired" } },
  { status: "expired" }
);
// Send notifications for each
```

---

## REAL-TIME FEATURES (WEBSOCKET/SOCKET.IO)

### Socket.io Configuration

**Library:** socket.io 4.8.3

**Initialization (in server.js):**

```javascript
import { createServer } from "http";
import { Server } from "socket.io";

const httpServer = createServer(app);
const io = new Server(httpServer, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"],
  },
});
```

### Delivery Namespace

**URL:** `ws://localhost:5800/delivery` (or `http://localhost:5800/delivery` with upgrade)

**Full Path:** Same host/port as REST API

#### Authentication

**Handshake Auth:**

- Send JWT access token during connection
- Methods:
  1. `auth.token`
  2. `auth.accessToken`
  3. `Authorization: Bearer <token>` (header style)

**Middleware:**

```javascript
io.of("/delivery").use((socket, next) => {
  const token = socket.handshake.auth.token;
  // Verify JWT
  // Attach user to socket.user
  next();
});
```

#### Client Connection Example (JavaScript)

```javascript
import { io } from "socket.io-client";

const socket = io("http://localhost:5800/delivery", {
  auth: {
    token: accessToken,
  },
});

socket.connect();
```

#### Rooms

**Auto-join on connect:**

- Room: `delivery-today`
- All location updates broadcast to this room

**Custom rooms (optional):**

- Per-delivery-staff: `staff_${staffId}`
- Per-customer: `customer_${customerId}`

#### Events: Client → Server

**Event 1: location_update**

```javascript
socket.emit("location_update", {
  lat: 19.076,
  lng: 72.8777,
});
```

**Payload:**

- `lat` (number, -90 to 90): Latitude
- `lng` (number, -180 to 180): Longitude

**Server Response:** Broadcast to room

**Event 2: delivery_complete**

```javascript
socket.emit("delivery_complete", {
  dailyOrderId: "...",
});
```

**Server Response:** Notify room, update DB status

#### Events: Server → Client

**Event 1: location_updated**

```javascript
socket.on("location_updated", (data) => {
  // data = { userId, phone, lat, lng, timestamp }
  // Another delivery staff location
});
```

**Event 2: delivery_updated**

```javascript
socket.on("delivery_updated", (delivery) => {
  // New delivery status from API update
  // delivery = full Delivery object (populated)
});
```

**Event 3: error**

```javascript
socket.on("error", (data) => {
  // { message: "Invalid token" }
});
```

**Event 4: connect_error**

```javascript
socket.on("connect_error", (error) => {
  // Handle connection failures
});
```

#### Broadcast Examples

**To room:**

```javascript
io.of("/delivery").to("delivery-today").emit("location_updated", data);
```

**To specific socket:**

```javascript
socket.emit("error", { message: "..." });
```

### Future Real-time Enhancements

- **Multi-instance:** Implement Redis adapter for Socket.io (when scaling)
- **Rooms per delivery:** `delivery_${id}`, `staff_${id}`, `customer_${id}`
- **Order status updates:** Push updates without polling
- **Chat:** Delivery staff ↔ Customer communication
- **Order confirmation:** Customer confirms delivery

---

## REPORTING & ANALYTICS

### Reports Endpoint

**Endpoint:** `GET /api/v1/reports/summary`

**Query Parameters:**

- `period` (optional, enum): `daily`, `weekly`, `monthly` (default: `monthly`)

### Report Data Structure

```json
{
  "activeSubscriptions": 45,
  "revenue": 12500,
  "deliveries": 150,
  "period": "monthly",
  "expiredSubscriptions": 3,
  "totalCustomers": 85,
  "pendingPayments": 5,
  "averageOrderValue": 250
}
```

### Aggregation Details

#### Active Subscriptions Count

```
Subscription.countDocuments({ status: "active" })
```

#### Revenue (Period)

```
Payment.aggregate([
  {
    $match: {
      status: "captured",
      createdAt: { $gte: start, $lte: end }
    }
  },
  {
    $group: {
      _id: null,
      totalRevenue: { $sum: "$amount" }
    }
  }
])
```

#### Successful Deliveries (Period)

```
DailyOrder.countDocuments({
  orderDate: { $gte: start, $lte: end },
  status: "delivered"
})
```

#### Expired Subscriptions (Period)

```
Subscription.countDocuments({
  endDate: { $gte: start, $lte: end },
  status: "expired"
})
```

### Report Service

**File:** `/services/report.service.js`

**Function:** `getSummaryReport(period = "monthly")`

**Period Calculation:**

- `daily`: Today 00:00 to now
- `weekly`: 7 days ago to now
- `monthly`: 30 days ago to now

### Dashboard Integration

**Planned:** Customer dashboard showing:

- Active subscriptions count
- Monthly revenue trend
- Delivery performance (success rate)
- Top customers
- Payment pending count
- Expiry alerts (30 days)

---

## SECURITY & AUTHORIZATION REQUIREMENTS

### Core Security Features

#### 1. HTTPS/TLS

- **Enforcement:** At reverse proxy/load balancer level
- **Implementation:**
  - Nginx/HAProxy reverse proxy terminating SSL
  - Let's Encrypt free certificates
  - Auto-renewal via certbot

#### 2. CORS (Cross-Origin Resource Sharing)

- **Current:** Wildcard `*` in dev
- **Production:** Whitelist Flutter app origins only
  ```javascript
  cors({
    origin: ["https://tiffin-app.com"],
    credentials: true,
  });
  ```
- **Methods:** GET, POST, PUT, DELETE, PATCH
- **Implementation:** `cors` middleware in Express

#### 3. Rate Limiting

**Global Limit:**

- **Limit:** 100 requests per 15 minutes per IP
- **Implementation:** `express-rate-limit` middleware
- **Response on exceed:** 429 with message

**Auth Endpoint Limit:**

- **Limit:** 5 requests per 15 minutes per IP
- **Route:** `/api/v1/auth/send-otp`
- **Purpose:** Prevent OTP enumeration

**Bulk Import Limit:**

- **Limit:** 5 per 15 minutes per user
- **Route:** `/api/v1/customers/bulk`
- **Purpose:** Prevent abuse

**Per-Phone OTP Limit (Planned):**

- **Limit:** 3 per 10 minutes per phone number
- **Implementation:** Redis-based (per-phone key)
- **Purpose:** Prevent account enumeration

**Webhook Limit:**

- **Limit:** Bypass (verify signature instead)
- **Route:** `/api/v1/webhooks/razorpay`
- **Implementation:** Signature verification required

#### 4. Helmet Security Headers

**Library:** `helmet` 8.1.0

**Headers Applied:**

- `Content-Security-Policy`: Restrict inline scripts, external sources
- `X-Frame-Options`: DENY (prevent clickjacking)
- `X-Content-Type-Options`: nosniff (prevent MIME sniffing)
- `X-XSS-Protection`: 1; mode=block
- `Referrer-Policy`: strict-origin-when-cross-origin
- `Strict-Transport-Security`: (HSTS) 1 year
- `Permissions-Policy`: Disable unnecessary browser features

**Usage:**

```javascript
app.use(helmet());
```

#### 5. JWT Security

**Access Token (Short-lived):**

- **Expiry:** 15 minutes
- **Secret:** `JWT_ACCESS_SECRET` (strong, random 32+ chars)
- **Payload:** `{ userId, phone, iat, exp }`
- **Signing:** HS256 (HMAC SHA-256)

**Refresh Token (Long-lived):**

- **Expiry:** 7 days
- **Secret:** `JWT_REFRESH_SECRET` (different from access)
- **Payload:** `{ userId, phone, iat, exp }`
- **Optional:** Rotation on each refresh (issue new token)

**Token Validation:**

- Verify signature with secret
- Check expiration time
- Reject if tampered or invalid
- Return 401 Unauthorized on failure

#### 6. Input Validation & Sanitization

**Library:** `joi` 18.0.2

**Validation Strategy:**

- Every route has request schema validation
- Rejects unknown fields (`stripUnknown: true`)
- Type checking (string, number, date, enum)
- Format validation (email, phone, URL)
- Length limits (min/max)
- Custom validators (e.g., phone format)

**Example:**

```javascript
const schema = joi.object({
  phone: joi
    .string()
    .pattern(/^\d{10}$/)
    .required(),
  otp: joi.string().length(6).required(),
  name: joi.string().min(1).max(100),
});

const { error, value } = schema.validate(req.body);
if (error) throw new ApiError(400, error.message);
```

**Response on validation error:** 400 with error message

#### 7. SQL/NoSQL Injection Prevention

**NonApplicable - No SQL:** Using MongoDB (NoSQL), not SQL
**Object ID Validation:** All `_id` parameters validated as valid ObjectId
**Query Building:** Mongoose prevents injection through type coercion

```javascript
// Safe: Mongoose prevents injection
const customer = await Customer.findById(req.params.id);
```

#### 8. Sensitive Data Logging

**Winston Logger Configuration:**

- **Patterns:** Redact phone, OTP, tokens, passwords
- **Transport:** File + console
- **Level:** debug (dev), warn (prod)
- **No logs for:** JWT tokens, OTP codes, API keys, customer PII

**Implementation:**

```javascript
const tokens = ["otp", "token", "secret", "password"];
tokens.forEach((token) => {
  // Redact in logs
});
```

#### 9. API Error Handling

**Custom ApiError Class:**

```javascript
class ApiError extends Error {
  constructor(statusCode, message, errors = []) {
    this.statusCode = statusCode;
    this.message = message;
    this.errors = errors;
  }
}
```

**Error Response Format:**

```json
{
  "success": false,
  "message": "User not found",
  "statusCode": 404,
  "code": "USER_NOT_FOUND"
}
```

**Error Codes (Planned):**

- `AUTH_001`: Invalid OTP
- `AUTH_002`: Token expired
- `CUST_001`: Customer not found
- `SUB_001`: Subscription not found
- `PAY_001`: Payment failed
- `PAYMENT_DUPLICATE`: Duplicate payment

**Centralized Error Handler Middleware:**

```javascript
app.use((err, req, res, next) => {
  // Log error (redact secrets)
  // Return consistent error response
  // Don't expose internal details
});
```

#### 10. Request Signing (Razorpay Webhook)

**Signature Verification:**

```
X-Razorpay-Signature = HMAC-SHA256(
  "{order_id}|{payment_id}",
  webhook_secret
)
```

**Validation:**

```javascript
const expectedSignature = crypto
  .createHmac("sha256", WEBHOOK_SECRET)
  .update(body)
  .digest("hex");

if (expectedSignature !== actualSignature) {
  throw new ApiError(400, "Invalid signature");
}
```

**Response:** Accept only on valid signature; ignore otherwise

### Authorization (Role-Based Access Control)

#### Admin/Owner Role

- Full access to all CRUD operations
- View all reports and analytics
- Manage delivery staff
- Configure system settings
- Access audit logs

#### Delivery Staff Role

- Limited to assigned deliveries
- View today's list
- Update delivery status
- View own location-based data

#### Customer Role (Implicit via Token)

- View own subscriptions
- View own invoices (via share token for public)
- Receive notifications
- Cancel own subscriptions

### Network Security

#### TLS Certificate Management

- Use Let's Encrypt (free)
- Auto-renewal via certbot
- Store in `/etc/letsencrypt/live/domain/`
- Certificate: `fullchain.pem`
- Private key: `privkey.pem`

#### Reverse Proxy (Nginx)

```nginx
server {
  listen 443 ssl http2;
  server_name api.tiffin-crm.com;

  ssl_certificate /etc/letsencrypt/live/api.tiffin-crm.com/fullchain.pem;
  ssl_certificate_key /etc/letsencrypt/live/api.tiffin-crm.com/privkey.pem;

  ssl_protocols TLSv1.2 TLSv1.3;
  ssl_ciphers HIGH:!aNULL:!MD5;
  ssl_prefer_server_ciphers on;

  location / {
    proxy_pass http://nodejs:5800;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
  }
}
```

### Secrets Management

**Environment Variables:**

- `JWT_ACCESS_SECRET`: Random 32+ character string
- `JWT_REFRESH_SECRET`: Random 32+ character string
- `MONGODB_URL`: Database connection string
- `MSG91_AUTH_KEY`: OTP SMS provider key
- `RAZORPAY_KEY_ID`: Payment gateway key
- `RAZORPAY_SECRET`: Payment gateway secret
- `RAZORPAY_WEBHOOK_SECRET`: Webhook verification secret
- `FIREBASE_ADMIN_SDK`: Service account JSON (via file)
- `CLOUDINARY_API_KEY`: File storage API key
- `NODE_ENV`: development, testing, production

**Storage:**

- `.env` file (development): Git-ignored, not in repo
- `.env.example`: Template for deployment teams
- `.env.production`: Separate production secrets (not in code)
- Environment variables: Loaded via `dotenv`

**No hardcoded secrets:** All loaded from environment

### Database Security

#### MongoDB Atlas (Cloud)

- Whitelist IP addresses
- VPC Peering (if using)
- Enable authentication (username/password)
- Encryption at rest (built-in)
- Encryption in transit (SSL)
- Regular backups (point-in-time restore)
- Audit logging enabled

#### Local Development

- Use test database (separate from prod)
- Restrict access to local network only
- No sensitive data in test DB

---

## NOTIFICATION SYSTEM

### FCM Push Notifications

**Categories:**

#### 1. Subscription Notifications

**Expiry Reminders:**

- **Trigger:** Subscription endDate detected (within 7/3/1 days)
- **Title:** "Subscription Expiring Soon"
- **Body:** "Your tiffin subscription expires in X days. Please renew."
- **Data:**
  ```json
  {
    "type": "subscription_expiry",
    "subscriptionId": "...",
    "expiresAt": "2026-03-01"
  }
  ```

**Expiry Notification:**

- **Trigger:** Cron job daily, status = "expired"
- **Title:** "Subscription Expired"
- **Body:** "Your subscription has expired. Renew now."

**Auto-Renewal Notifications:**

- **Trigger:** Subscription auto-renewed
- **Title:** "Subscription Renewed"
- **Body:** "Your subscription has been auto-renewed."

#### 2. Delivery Notifications

**Delivery Ready:**

- **Trigger:** DailyOrder status = "processing"
- **Title:** "Your Tiffin is Being Prepared"
- **Body:** "We're preparing your order for today."

**Out for Delivery:**

- **Trigger:** DailyOrder status = "out_for_delivery"
- **Title:** "Order Out for Delivery"
- **Body:** "Your tiffin is on the way. Track live."
- **Data:**
  ```json
  {
    "type": "delivery_in_transit",
    "dailyOrderId": "...",
    "lat": 19.076,
    "lng": 72.8777
  }
  ```

**Delivered:**

- **Trigger:** DailyOrder status = "delivered"
- **Title:** "Order Delivered"
- **Body:** "Your tiffin has been delivered."

**Failed/Cancelled:**

- **Trigger:** Status = "failed" or "cancelled"
- **Title:** "Delivery Issue"
- **Body:** "We couldn't deliver your order. Contact support."

#### 3. Payment Notifications

**Payment Received:**

- **Trigger:** Webhook razorpay payment.captured
- **Title:** "Payment Received"
- **Body:** "We've received your payment of ₹X."
- **Data:**
  ```json
  {
    "type": "payment_success",
    "amount": 500,
    "paymentId": "..."
  }
  ```

**Payment Failed:**

- **Trigger:** Webhook payment.failed
- **Title:** "Payment Failed"
- **Body:** "Your payment couldn't be processed. Retry."

#### 4. Invoice Notifications

**Invoice Generated:**

- **Title:** "Invoice Generated"
- **Body:** "Your invoice for March is ready. View details."
- **Data:**
  ```json
  {
    "type": "invoice_generated",
    "invoiceId": "...",
    "amount": 5000
  }
  ```

#### 5. Custom Notifications

**Admin Sends:**

- **Endpoint:** POST `/api/v1/notifications/test` (test only)
- **Admin Panel:** Future feature for sending custom messages
- **Channels:** Push, Email, WhatsApp, In-app

### Notification Channels

#### Push Notification (Primary)

- **Method:** FCM (Firebase Cloud Messaging)
- **Token:** Stored on User.fcmToken, Customer.fcmToken
- **Transport:** Mobile app background service

#### Email (Future)

- **Method:** SendGrid or similar SMTP service
- **Config:** `settings.emailEnabled`
- **Use:** Invoice delivery, subscription alerts

#### WhatsApp (Future)

- **Method:** Twilio WhatsApp API or similar
- **Config:** `settings.whatsappEnabled`
- **Use:** Delivery updates, payment reminders

#### In-App (Future)

- **Method:** Socket.io or REST polling
- **Storage:** Notification model records
- **UI:** In-app notification center

### Notification Service

**File:** `/services/notification.service.js`

**Functions:**

```javascript
export const sendToToken = async (token, title, body, data = {}) => {
  // Send via FCM
  // Handle errors: invalid token removed
};

export const notifySubscriptionExpiry = async (subscription) => {
  // Send notification to customer
};

export const notifyDeliveryUpdate = async (dailyOrder) => {
  // Send to customer and delivery staff
};

export const notifyPaymentReceived = async (payment) => {
  // Send to customer
};
```

### Notification Model

**Collection:** `notifications`

**Use:** Keep history of sent notifications (audit, resend, etc.)

**Fields:**

- `customerId`, `ownerId`: Recipients
- `type`: Notification type (enum)
- `title`, `message`: Content
- `data`: Metadata
- `isRead`: Mark as read by user
- `channel`: Push, email, etc.
- `sentAt`: Timestamp
- `createdAt`, `updatedAt`: Timestamps

---

## BUSINESS LOGIC & FEATURES

### Subscription Lifecycle

#### Create Subscription

1. Validate customer exists
2. Validate plan exists
3. Validate startDate (not in past)
4. Calculate endDate based on billingPeriod
5. Create Subscription record
6. Log audit entry
7. Return subscription details

#### Renew Subscription

1. Find subscription by ID
2. Validate status (active or expired, not cancelled)
3. Extend endDate by billingPeriod
4. Set status = active (if expired)
5. Reset pausedFrom/pausedUntil
6. Update DB
7. Log audit entry
8. Send FCM notification
9. Return updated subscription

#### Pause Subscription

1. Set pausedFrom = now
2. Set pausedUntil = customer-specified date
3. Status remains "paused"
4. Skip delivery generation for this period
5. Don't charge customer

#### Cancel Subscription

1. Set status = "cancelled"
2. Set cancelledAt = now
3. Log reason (optional)
4. Send notification to customer
5. Log audit entry
6. Return updated subscription

#### Auto-Expiry (Cron)

1. Daily: Find subscriptions with endDate < today
2. Update status = "expired"
3. Send FCM notification: "Subscription expired, please renew"
4. Log audit entry

### Delivery Workflow

#### Daily Order Generation (Cron)

1. **Time:** 00:00 daily
2. **Find:** All subscriptions with status = "active"
3. **Filter:** Where deliveryDays includes today's weekday
4. **Create:** DailyOrder for each match
5. **Set:** status = "pending", deliverySlot from subscription
6. **Assign:** Delivery staff based on area/zone (optional)
7. **Log:** Audit entry for batch creation

**Example:**

- Subscription A: Mon-Fri breakfast → Creates DailyOrder today (if today is M-F)
- Subscription B: Daily lunch → Creates DailyOrder (every day)
- Subscription C: Weekend dinner → Creates DailyOrder (if today is Sat/Sun)

#### Real-time Delivery Tracking

1. Delivery staff connects via Socket.io
2. Broadcasts `location_update` every 10-30 seconds
3. Server broadcasts to `delivery-today` room
4. Customers see live location on map
5. On completion, staff calls mark-delivered API
6. Status changes to "delivered"
7. Notification sent to customer

#### Delivery Completion

1. Delivery staff marks order as delivered (via app or API)
2. API call: PUT `/api/v1/daily-orders/:id/mark-delivered`
3. Update DailyOrder status = "delivered"
4. Set completedAt = now
5. Send Socket.io broadcast: `delivery_updated`
6. Send FCM to customer: "Order delivered"
7. Log audit entry

### Payment Processing

#### Manual Payment

1. Admin records payment in app
2. Enter: amount, method (cash/cheque/upi), customer, optional notes
3. POST `/api/v1/payments` → Create Payment record
4. Update Invoice.paidAmount, balanceDue
5. Update Subscription.paidAmount (if linked)
6. Log audit entry
7. Send notification to customer (optional)

#### Razorpay Payment

1. Customer initiates payment on mobile
2. Mobile calls: POST `/api/v1/payments/create-order`
3. Backend creates Razorpay order via API
4. Returns orderId + key_id to mobile
5. Mobile opens Razorpay checkout
6. Customer completes payment
7. Razorpay calls webhook: POST `/api/v1/webhooks/razorpay`
8. Backend verifies signature
9. Creates Payment record with razorpay details
10. Updates corresponding Invoice/Subscription
11. Generates invoice PDF
12. Sends FCM notification
13. Returns 200 OK to Razorpay

#### Payment Reconciliation

- Webhook is idempotent (checks for existing `razorpayPaymentId`)
- Prevents duplicate payment recording if webhook retried
- Manual verification available for offline matching

### Invoice Generation & Management

#### Auto-Generation (Planned)

1. Trigger: End of billing period OR manual request
2. Query subscriptions/payments for date range
3. Aggregate order amounts
4. Apply discounts (if configured)
5. Calculate taxes (GST, VAT)
6. Generate invoice PDF
7. Store Invoice record
8. Send to customer via email/WhatsApp
9. Log audit entry

#### Manual Generation

1. **Endpoint:** POST `/api/v1/invoices/generate`
2. **Parameters:**
   - `customerId`: Target customer
   - `billingStart`, `billingEnd`: Date range
3. **Process:**
   - Query DailyOrders/Subscriptions for period
   - Calculate charges
   - Apply settings.autoGenerateInvoice
   - Generate invoice
4. **Response:** Invoice details + PDF URL

#### PDF Generation

1. Use pdfkit to build invoice document
2. Include: invoice number, dates, customer info, line items, totals
3. Upload to Cloudinary
4. Store receiptUrl on Invoice/Payment
5. Return public URL

#### Share Token System

1. Generate 32-character random token
2. Store on Invoice.shareToken
3. Set expiry: 30 days by default
4. Public endpoint: `GET /api/v1/public/invoice/:shareToken`
5. Customers can share link without login
6. Check expiry before returning invoice

#### Void Invoice

1. Mark invoice as void
2. Maintain audit trail (don't delete)
3. Create credit note entry
4. Update customer balance

### Inventory Management

#### Stock Tracking

- **Model:** RawMaterial
- **Fields:** currentStock, minimumStock, costPerUnit
- **Operations:** Issue (decrease), Receive (increase)

#### Low Stock Alerts

1. When currentStock < minimumStock
2. Alert owner via notification or dashboard
3. Suggest reordering

#### Usage Tracking (Planned)

- Link RawMaterial to DailyMenu items
- Deduct stock when menu confirmed
- Alert on insufficient stock
- Prevent order if out of stock

#### Replenishment (Planned)

- Generate purchase orders
- Track vendor deliveries
- Update currentStock
- Log audit trail

### Customer Communication

#### Bulk Import

1. **Endpoint:** POST `/api/v1/customers/bulk`
2. **Input:** Array of customer objects
3. **Validation:** Each record validated
4. **Processing:**
   - Check duplicates (by phone)
   - Check if exists → skip or update
   - Create new records
5. **Rate Limit:** 5 per 15 minutes
6. **Response:**
   ```json
   {
     "success": true,
     "inserted": 5,
     "updated": 2,
     "skipped": 1,
     "errors": []
   }
   ```

#### Customer Soft Delete

1. Set isDeleted = true
2. Don't remove from DB (audit trail)
3. List queries filter out isDeleted by default
4. Can restore (set isDeleted = false)

#### Custom Tagging

- Add tags to customers (e.g., "vegan", "allergic_nuts")
- Use for filtering, bulk operations
- Support for segmentation

---

## INFRASTRUCTURE & DEPLOYMENT

### Hosting Options (Free/Low-Cost)

#### 1. Backend Deployment

**Render.com (Recommended)**

- Free tier: 0.5GB RAM, auto-sleep after 15 min inactivity
- Paid: $7/month (0.5GB RAM, always-on)
- Deploy: Push to GitHub, auto-deploy
- Environment variables: Stored securely
- PostgreSQL: Free tier available (but using MongoDB)

**Railway.app**

- Pay-as-you-go ($5/month credit)
- Node.js support
- Easy GitHub integration

**Fly.io**

- Free tier: 3 shared CPU cores, 3GB RAM across 3 apps
- Global deployment (edge computing)
- Docker-based deployment

#### 2. Database Deployment

**MongoDB Atlas**

- Free tier: M0 (512MB storage, 100 max connections)
- Shared cluster
- Auto-managed backups (8 snapshots)
- Point-in-time restore (last 7 days)
- Sufficient for MVP/early stage

#### 3. File Storage

**Cloudinary**

- Free tier: 25GB storage, 25GB bandwidth
- Image/PDF uploads
- No cost for basic operations

**AWS S3**

- Pay-per-use ($0.023 per GB storage)
- More complex than Cloudinary

#### 4. SSL Certificate

**Let's Encrypt (Free)**

- Issue certificates
- Auto-renewal every 90 days
- Certbot automation on server

### Deployment Checklist

#### Pre-Deployment

- [ ] All environment variables set
- [ ] Database migrations run (if using)
- [ ] Seeds applied (test data)
- [ ] SSL certificate generated
- [ ] Reverse proxy configured (Nginx)
- [ ] Node modules installed
- [ ] Tests pass
- [ ] Build successful (if applicable)

#### Deployment Steps

1. Push code to GitHub
2. Trigger deployment (Render: automatic)
3. Environment variables loaded
4. Dependencies installed
5. Start command: `node index.js`
6. Health check: GET `/health` → 200
7. Monitor logs for errors

#### Post-Deployment

- [ ] Test health endpoint
- [ ] Test auth flow (send/verify OTP)
- [ ] Test payment webhook
- [ ] Test FCM notifications
- [ ] Monitor error logs
- [ ] Set up monitoring (Sentry optional)

### Health Check

**Endpoint:** `GET /health` (public)

**Response:**

```json
{
  "status": "ok",
  "uptime": 3600,
  "db": "connected"
}
```

**Used by:** Load balancer, monitoring, uptime checkers

### Logging & Monitoring

#### Winston Logger

- **Levels:** error, warn, info, debug
- **Format:** JSON in production (for parsing)
- **Transport:** File + console
- **Redaction:** Phone, OTP, tokens
- **Rotation:** Daily file rotation (optional)

#### Morgan HTTP Logger

- **Format:** Combined (production), dev (development)
- **Log:** Request method, path, status, duration
- **Include:** Request ID for tracing

#### Error Tracking (Optional)

**Sentry:**

- Free tier: 5k events/month
- Captures exceptions with full stack trace
- Integration: `@sentry/node`
- Environment: Set in config
- Benefits: Alerting, grouped errors

### Scaling Strategy

#### Stage 1: Single Instance

- 1 Node.js server (Render.com)
- 1 MongoDB Atlas (M0)
- Cron jobs on single instance

#### Stage 2: Load Balancer

- Add ALB/load balancer
- 2-3 Node.js instances
- Stateless REST API (JWT only)
- Socket.io with sticky sessions or Redis adapter

#### Stage 3: Caching

- Add Redis for:
  - Rate limit counters
  - Session/token blocklist
  - API response cache
  - Socket.io adapter (for broadcast)

#### Stage 4: Database Scaling

- Upgrade MongoDB to M10+ (dedicated)
- Enable read replicas
- Configure read preference for analytics

#### Stage 5: Critical Jobs

- Separate cron instance (one-off)
- Use distributed lock (Redis) for multi-instance safety
- Or: Leader election mechanism

### Monitoring & Uptime

**Status Page (Optional):**

- Use Statuspage.io (free tier limited)
- Or build custom dashboard
- Show: API status, DB status, last check time

**Alerting:**

- Email on error threshold
- Slack integration (optional)
- SMS critical alerts (Twilio)

---

## TECHNOLOGY STACK

### Frontend (Not Included)

**Framework:** Flutter (Dart)

- Mobile app (iOS + Android)
- Real-time delivery tracking
- In-app notifications
- Payment integration
- Camera/GPS features

### Backend (Node.js)

**Core Framework:**

- `express` ^5.2.1: Web server
- `mongoose` ^9.2.2: MongoDB ODM
- `cors` ^2.8.6: Enable cross-origin requests
- `helmet` ^8.1.0: Security headers

**Authentication & Validation:**

- `jsonwebtoken` ^9.0.3: JWT signing/verification
- `joi` ^18.0.2: Request/form validation
- `bcryptjs` ^3.0.3: Password hashing (reserved)

**Database:**

- `mongodb` (via Mongoose): NoSQL database
- Indexes on: phone, status, customerId, date, ownerId

**Real-time Communication:**

- `socket.io` ^4.8.3: WebSocket library
- Namespace: `/delivery`
- Authentication via JWT

**External Services:**

- `razorpay` ^2.9.6: Payment gateway (India)
- `firebase-admin` ^13.6.1: FCM push notifications
- `cloudinary` ^2.9.0: File/document storage
- `pdfkit` ^0.17.2: PDF generation

**SMS/OTP:**

- Integrated with MSG91 API (HTTP calls)
- Alternative: Twilio, Fast2SMS

**Scheduled Jobs:**

- `node-cron` ^4.2.1: Cron job scheduling
- Jobs: Daily delivery generation, subscription expiry

**Logging & Monitoring:**

- `morgan` ^1.10.1: HTTP request logging
- `winston` ^3.19.0: Structured logging
- `express-rate-limit` ^8.2.1: Rate limiting

**Development:**

- `nodemon` ^3.1.11: Auto-reload on file changes
- `prettier` ^3.8.1: Code formatting
- Post-launch: `jest`, `supertest` for testing

**Utilities:**

- `dotenv` ^17.3.1: Environment variable loading
- `cookie-parser` ^1.4.7: Cookie parsing
- `cross-env` ^10.1.0: Cross-platform environment variables

### Database

**MongoDB:**

- Hosted on MongoDB Atlas (free M0 or paid)
- Collections: 16 models
- Indexes: Compound indexes on frequently-queried fields
- TTL Indexes: On Otp.expiresAt (auto-cleanup)
- GeoJSON: Customer.location for GPS
- Backup: Automated daily snapshots
- Point-in-time restore: Last 7 days

### Optional Tools (Planned/For Production)

- `jest`: Unit/integration testing framework
- `supertest`: HTTP assertion library
- `swagger-ui-express`: API documentation UI
- `swagger-jsdoc`: OpenAPI spec generation
- `@sentry/node`: Error tracking & monitoring
- `redis`: Caching, rate limiting (multi-instance)
- `bull`: Job queue (advanced scheduling)

### Version Summary

| Technology     | Version   | Purpose        |
| -------------- | --------- | -------------- |
| Node.js        | 18+ (LTS) | Runtime        |
| Express        | 5.2.1     | Web server     |
| MongoDB        | Latest    | Database       |
| Mongoose       | 9.2.2     | ODM            |
| Socket.io      | 4.8.3     | Real-time      |
| Firebase Admin | 13.6.1    | Notifications  |
| Razorpay       | 2.9.6     | Payments       |
| Joi            | 18.0.2    | Validation     |
| JWT            | 9.0.3     | Authentication |
| Winston        | 3.19.0    | Logging        |

---

## SUMMARY: WHAT'S IMPLEMENTED

### ✅ Fully Implemented (95% Complete)

1. **Authentication**
   - OTP send (MSG91)
   - OTP verify
   - JWT token generation (access + refresh)
   - Token refresh
   - Logout
   - Profile update

2. **Customer Management**
   - CRUD operations
   - Pagination + filtering
   - Bulk import
   - Soft delete
   - Status tracking
   - Geolocation support

3. **Plans & Subscriptions**
   - Plan CRUD
   - Subscription CRUD
   - Subscription renewal
   - Subscription cancellation
   - Auto-expiry cron job
   - Delivery schedule (days of week, slots)

4. **Payments**
   - Manual payment recording (cash, cheque, UPI, bank transfer)
   - Razorpay order creation
   - Webhook verification
   - Invoice PDF generation
   - Cloudinary storage
   - Payment status tracking

5. **Invoices**
   - Invoice generation (manual + auto-range)
   - Discounts (flat/percent)
   - Tax calculations (GST)
   - Payment status tracking (unpaid/partial/paid)
   - Share token system
   - Overdue invoice queries
   - Void invoice functionality

6. **Delivery & Orders**
   - Daily order generation (cron)
   - Today's delivery list
   - Mark delivered
   - Status tracking (pending → delivered)
   - Cancellation with reason
   - Real-time Socket.io updates

7. **Real-time Features**
   - Socket.io `/delivery` namespace
   - JWT authentication handshake
   - Location tracking (`location_update`)
   - Delivery updates broadcast
   - Room-based delivery-today

8. **Notifications**
   - FCM push integration
   - Token management
   - Subscription alerts
   - Delivery updates
   - Payment confirmations
   - Auto-invalid token removal

9. **Reporting**
   - Summary reports (daily/weekly/monthly)
   - Revenue aggregation
   - Delivery counts
   - Subscription analytics
   - Period-based filtering

10. **Security**
    - CORS configuration
    - Helmet security headers
    - Rate limiting (global + auth-specific)
    - JWT validation
    - Input validation (Joi)
    - Sensitive data redaction in logs
    - Razorpay webhook signature verification

11. **Advanced Features**
    - Inventory management (RawMaterial)
    - Daily menu planning
    - Delivery staff management
    - Zone management
    - Audit logging
    - Generic order model
    - Customer report tokens

12. **Infrastructure**
    - Environment configuration validation
    - Health check endpoint
    - Structured logging (Winston + Morgan)
    - Error handling & custom error classes
    - Audit trails

---

## GAPS & FUTURE FEATURES (Not Fully Implemented)

### Phase 7: Advanced Features

1. **Testing**
   - Unit tests for services
   - Integration tests for endpoints
   - E2E tests

2. **API Documentation**
   - Swagger/OpenAPI spec
   - Postman collection

3. **Performance**
   - Redis caching
   - Database query optimization
   - Response compression

4. **Scaling**
   - Multi-instance Socket.io (Redis adapter)
   - Distributed cron (leader election)
   - Database replication

5. **Additional Integrations**
   - Email (SendGrid)
   - WhatsApp (Twilio)
   - Google Maps integration
   - Truecaller (mentioned, not implemented)
   - Analytics dashboard (Grafana)

6. **Advanced Security**
   - 2FA (two-factor authentication)
   - API key authentication
   - OAuth2 integration

7. **Customer Portal**
   - Web dashboard
   - Order history
   - Invoice downloads
   - Subscription management
   - Payment history

8. **Admin Dashboard**
   - KPI monitoring
   - Staff assignment UI
   - Inventory alerts
   - Customer communication

---

## KEY FILES & STRUCTURE

```
server/
├── index.js                         # Entry point
├── server.js                        # Express app setup
├── package.json                     # Dependencies
├── .env                            # Environment variables (git-ignored)
├── .env.example                    # Template
│
├── config/
│  ├── index.js                    # Centralized config
│  ├── firebase.js                 # Firebase setup
│  └── corsOptions.js              # CORS configuration
│
├── models/                         # 16 Mongoose schemas
│  ├── User.model.js
│  ├── Customer.model.js
│  ├── Subscription.model.js
│  ├── Payment.model.js
│  ├── Invoice.model.js
│  ├── DailyOrder.model.js
│  ├── Delivery.model.js
│  ├── DeliveryStaff.model.js
│  ├── Zone.model.js
│  ├── DailyMenu.model.js
│  ├── RawMaterial.model.js
│  ├── Order.model.js
│  ├── Notification.model.js
│  ├── AuditLog.model.js
│  ├── Otp.model.js
│  └── Plan.model.js
│
├── controllers/                    # 11 Controllers
│  ├── auth.controller.js
│  ├── customer.controller.js
│  ├── plan.controller.js
│  ├── subscription.controller.js
│  ├── payment.controller.js
│  ├── invoice.controller.js
│  ├── dailyOrder.controller.js
│  ├── delivery.controller.js
│  ├── notification.controller.js
│  ├── report.controller.js
│  └── webhook.controller.js
│
├── routes/                         # 14 Route files
│  ├── auth.routes.js
│  ├── customer.routes.js
│  ├── plan.routes.js
│  ├── subscription.routes.js
│  ├── payment.routes.js
│  ├── invoice.routes.js
│  ├── dailyOrder.routes.js
│  ├── delivery.routes.js
│  ├── notification.routes.js
│  ├── report.routes.js
│  ├── webhook.routes.js
│  ├── public.routes.js
│  └── index.js                    # Mount all routes
│
├── services/                       # 10 Business logic services
│  ├── token.service.js            # JWT operations
│  ├── otp.service.js              # OTP sending/verification
│  ├── payment.service.js          # Razorpay integration
│  ├── notification.service.js     # FCM push
│  ├── pdf.service.js              # Invoice PDF generation
│  ├── report.service.js           # Reporting aggregations
│  ├── subscription.service.js     # Subscription logic
│  ├── delivery.service.js         # Delivery operations
│  ├── dailyOrder.service.js       # Daily order processing
│  └── index.js
│
├── middleware/                     # 6 Middleware functions
│  ├── auth.middleware.js          # JWT verification
│  ├── errorHandler.js             # Centralized error handling
│  ├── requestId.js                # Request ID generation
│  └── (rate limit setup in routes)
│
├── jobs/                           # 2 Cron jobs
│  ├── deliveryCron.js             # Daily delivery generation
│  └── subscriptionExpiryCron.js   # Daily expiry check
│
├── socket/
│  └── delivery.socket.js          # Socket.io namespace
│
├── class/                          # Custom classes
│  ├── apiErrorClass.js            # Error structure
│  ├── apiResponseClass.js         # Response structure
│  └── statusCode.js               # HTTP status codes
│
├── utils/                          # Utility functions
│  ├── asyncHandler.js             # Error handling wrapper
│  ├── logger.js                   # Winston configuration
│  └── (other helpers)
│
├── db/
│  └── connectMongoDB.js           # MongoDB connection setup
│
├── public/                         # Static files
│  └── invoices/                   # Generated invoice storage
│
└── docs/                           # Documentation
   ├── PROJECT_ROADMAP.md
   ├── PHASE_COMPLETION_STATUS.md
   ├── NEXT_15_DAY_PLAN.md
   ├── COMPLETE_STATUS_SUMMARY.md
   ├── ER_DIAGRAM.md
   ├── DATA_FLOW_DIAGRAM.md
   ├── SOCKET.md
   └── (this file)
```

---

## CONCLUSION

TiffinCRM Backend is **95% feature-complete** with comprehensive coverage of:

- ✅ Authentication (OTP + JWT)
- ✅ Customer Management (CRUD, bulk import, soft delete)
- ✅ Subscription Lifecycle (create, renew, cancel, auto-expiry)
- ✅ Payment Processing (manual + Razorpay webhook)
- ✅ Invoice Management (generation, discounts, taxes, sharing)
- ✅ Daily Delivery Orders (cron generation, tracking, completion)
- ✅ Real-time Socket.io (location updates, delivery broadcasts)
- ✅ FCM Push Notifications (subscription, delivery, payment alerts)
- ✅ Reporting & Analytics (aggregation pipelines by period)
- ✅ Security (CORS, Helmet, rate limiting, JWT, input validation)
- ✅ Audit Logging (track all major actions)
- ✅ Inventory Management (raw materials, low-stock alerts)
- ✅ Delivery Staff & Zones (management and assignment)
- ✅ Daily Menu Planning (meal scheduling)

**Next Steps for Production Readiness:**

1. Implement comprehensive test suite (Jest + Supertest)
2. Generate Swagger/OpenAPI documentation
3. Add performance monitoring (Sentry or similar)
4. Set up CI/CD pipeline (GitHub Actions)
5. Load testing and optimization
6. Deploy to free-tier hosting (Render/Railway/Fly.io)
7. Configure monitoring and alerting

---

**Document Generated:** February 27, 2026  
**Status:** Ready for Testing & Production Hardening Phase
