# TiffinCRM Backend — QUICK REFERENCE GUIDE

**Document:** [COMPREHENSIVE_REQUIREMENTS.md](./COMPREHENSIVE_REQUIREMENTS.md)  
**Purpose:** Quick lookup for API endpoints, models, features, and integrations  
**Last Updated:** February 27, 2026

---

## 📋 ALL API ENDPOINTS (50+ Total)

### Authentication (4 endpoints)

```
POST   /api/v1/auth/send-otp            → Send OTP to phone
POST   /api/v1/auth/verify-otp          → Verify OTP, get JWT tokens
POST   /api/v1/auth/refresh-token       → Refresh access token (15 min expiry)
POST   /api/v1/auth/logout              → Logout, invalidate tokens
PUT    /api/v1/auth/me                  → Update owner profile
```

### Customers (6 endpoints)

```
GET    /api/v1/customers                → List (paginated, filterable by status)
GET    /api/v1/customers/:id            → Get by ID
POST   /api/v1/customers                → Create
PUT    /api/v1/customers/:id            → Update
DELETE /api/v1/customers/:id            → Delete (soft or hard)
POST   /api/v1/customers/bulk           → Bulk import (rate-limited: 5/15min)
```

### Plans (4 endpoints)

```
GET    /api/v1/plans                    → List plans
GET    /api/v1/plans/:id                → Get by ID
POST   /api/v1/plans                    → Create
PUT    /api/v1/plans/:id                → Update
```

### Subscriptions (5 endpoints)

```
GET    /api/v1/subscriptions            → List (filterable by status, customer, plan)
GET    /api/v1/subscriptions/:id        → Get by ID
POST   /api/v1/subscriptions            → Create (validates customer & plan)
PUT    /api/v1/subscriptions/:id/renew  → Renew (extend by billing period)
PUT    /api/v1/subscriptions/:id/cancel → Cancel
```

### Payments (4 endpoints)

```
GET    /api/v1/payments                 → List (filterable)
POST   /api/v1/payments                 → Record manual payment (cash/cheque/upi)
POST   /api/v1/payments/create-order    → Create Razorpay order
GET    /api/v1/payments/:id/invoice     → Get/download invoice PDF
```

### Invoices (7 endpoints)

```
GET    /api/v1/invoices                 → List invoices
GET    /api/v1/invoices/:id             → Get by ID
POST   /api/v1/invoices/generate        → Generate invoices for date range
PUT    /api/v1/invoices/:id             → Update invoice
POST   /api/v1/invoices/:id/share       → Generate public share token
POST   /api/v1/invoices/:id/void        → Void/cancel invoice
GET    /api/v1/invoices/overdue         → Get overdue invoices
```

### Daily Orders (7 endpoints)

```
GET    /api/v1/daily-orders/today       → Get today's delivery list
POST   /api/v1/daily-orders/process     → Process today's orders
POST   /api/v1/daily-orders/mark-delivered → Mark delivery complete
POST   /api/v1/daily-orders/generate    → Manually generate daily orders
GET    /api/v1/daily-orders/debug/subscriptions → Debug: list subscriptions
GET    /api/v1/daily-orders/debug/subscription/:id → Debug: single subscription
GET    /api/v1/daily-orders/debug/match → Debug: match subscriptions for date
```

### Delivery (1 endpoint)

```
GET    /api/v1/delivery/                → Alias for /daily-orders/today
```

### Reports (1 endpoint)

```
GET    /api/v1/reports/summary          → Summary (period: daily/weekly/monthly)
```

### Notifications (1 endpoint)

```
POST   /api/v1/notifications/test       → Send test push notification (admin)
```

### Webhooks (1 endpoint)

```
POST   /api/v1/webhooks/razorpay        → Razorpay webhook handler (raw body)
```

### Public (3 endpoints, no auth required)

```
GET    /api/v1/public/health            → Health check (API version)
GET    /api/v1/public/invoice/:shareToken → Get invoice by public share token
GET    /api/v1/public/customer-report/:token → Get customer report by public token
GET    /health                          → System health (DB connection status)
```

---

## 📊 DATABASE MODELS (16 Total)

| Model             | Fields                                                       | Purpose                    |
| ----------------- | ------------------------------------------------------------ | -------------------------- |
| **User**          | phone, name, businessName, fcmToken, settings                | Business owner             |
| **Customer**      | name, phone, address, location, status, balance, zone        | Tiffin customer            |
| **Plan**          | name, type, price, frequency, isActive                       | Meal plan offering         |
| **Subscription**  | customerId, planId, startDate, endDate, status, deliveryDays | Active subscription        |
| **Payment**       | customerId, amount, method, razorpayId, receiptUrl           | Transaction record         |
| **Invoice**       | customerId, invoiceNumber, billing dates, lineItems, totals  | Billing document           |
| **DailyOrder**    | customerId, orderDate, mealType, status, deliveryStaffId     | Daily tiffin order         |
| **Delivery**      | customerId, date, status, location, completedAt              | Delivery tracking (legacy) |
| **DeliveryStaff** | name, phone, areas, zones, fcmToken, isActive                | Delivery personnel         |
| **Zone**          | name, description, color, isActive                           | Delivery area              |
| **DailyMenu**     | date, mealTime, items, notes                                 | Meal planning              |
| **RawMaterial**   | name, unit, currentStock, minimumStock, costPerUnit          | Inventory item             |
| **Order**         | customerId, items, price, orderType, activeDays              | Generic order              |
| **Notification**  | customerId, type, title, message, channel, isRead            | Alert history              |
| **AuditLog**      | action, resource, resourceId, details, ip, userAgent         | Change tracking            |
| **Otp**           | phone, otp, expiresAt (10-min TTL)                           | One-time password          |

---

## 🔌 EXTERNAL INTEGRATIONS

| Service            | Purpose                     | Config                                    |
| ------------------ | --------------------------- | ----------------------------------------- |
| **MSG91**          | SMS OTP sending             | `MSG91_AUTH_KEY`, `MSG91_TEMPLATE_ID`     |
| **Razorpay**       | Payment gateway             | `RAZORPAY_KEY_ID`, `RAZORPAY_SECRET`      |
| **Firebase Admin** | FCM push notifications      | `/config/firebase-adminsdk-*.json`        |
| **Cloudinary**     | PDF/file storage            | `CLOUDINARY_API_KEY`, `CLOUDINARY_SECRET` |
| **Socket.io**      | Real-time delivery tracking | Namespace: `/delivery`                    |
| **node-cron**      | Scheduled jobs (2 total)    | Time-based triggers                       |

---

## 🔑 KEY FEATURES

### ✅ Working

- [ ] OTP-based authentication (6-digit, 10-min expiry)
- [ ] JWT tokens (access 15min, refresh 7d)
- [ ] Customer CRUD + bulk import (5/15min rate-limited)
- [ ] Plan CRUD
- [ ] Subscription lifecycle (create, renew, cancel, auto-expiry cron)
- [ ] Manual payments (cash, cheque, UPI, bank transfer)
- [ ] Razorpay integration (order creation + webhook)
- [ ] Invoice generation (manual + range) with discounts & taxes
- [ ] Daily delivery order generation (00:00 cron)
- [ ] Mark deliveries complete with status tracking
- [ ] Real-time Socket.io `/delivery` namespace (location updates)
- [ ] FCM push notifications (subscription, delivery, payment events)
- [ ] Summary reports (daily/weekly/monthly aggregations)
- [ ] Rate limiting (global 100/15min, auth 5/15min)
- [ ] CORS, Helmet security headers, JWT validation
- [ ] Input validation (Joi schemas)
- [ ] Audit logging (all major actions tracked)
- [ ] Raw material inventory + low-stock alerts
- [ ] Delivery staff + zone management
- [ ] Daily menu planning

### ⚠️ Partial/Planned

- [ ] API documentation (Swagger/OpenAPI) - 20% done
- [ ] Testing suite (Jest/Supertest) - 0% done
- [ ] Performance optimization (caching) - 60% done
- [ ] Email notifications (SendGrid) - 0% done
- [ ] WhatsApp messaging (Twilio) - 0% done
- [ ] Google Maps integration - 0% done
- [ ] 2FA authentication - 0% done
- [ ] Sentry error tracking - 0% done

---

## 🚀 DEPLOYMENT

### Where to Deploy

- **Backend:** Render.com ($7/mo), Railway ($5+/mo), Fly.io (free tier)
- **Database:** MongoDB Atlas (free M0: 512MB)
- **Storage:** Cloudinary (free: 25GB)
- **SSL:** Let's Encrypt (free)

### Environment Variables

```
NODE_ENV=production
PORT=5800
MONGODB_URL=mongodb+srv://user:pass@cluster.mongodb.net/dbname
JWT_ACCESS_SECRET=<random-32-char-string>
JWT_REFRESH_SECRET=<random-32-char-string>
MSG91_AUTH_KEY=<msg91-key>
MSG91_TEMPLATE_ID=<msg91-template>
RAZORPAY_KEY_ID=<key>
RAZORPAY_SECRET=<secret>
RAZORPAY_WEBHOOK_SECRET=<webhook-secret>
CLOUDINARY_API_KEY=<key>
CLOUDINARY_SECRET=<secret>
FIREBASE_ADMIN_SDK=<path-or-json>
CORS_ORIGIN=https://app-domain.com
```

---

## 🧪 TESTING TODO

### High Priority

1. **Auth Tests** (send-otp, verify-otp, refresh-token)
   - Valid/invalid phone
   - Expired OTP
   - Duplicate OTP requests
   - Token refresh

2. **Subscription Tests** (create, renew, cancel)
   - Valid customer/plan
   - Auto-expiry cron
   - Delivery generation from active subs

3. **Payment Tests** (manual, Razorpay webhook)
   - Webhook signature verification
   - Idempotency (duplicate webhook)
   - Payment status updates

4. **Integration Tests**
   - Full flow: OTP → Create subscription → Daily order generated → Mark delivered
   - Full flow: Manual payment → Invoice generated → Customer notified

### Medium Priority

5. Customer CRUD + bulk import
6. Invoice generation + PDF
7. Socket.io real-time delivery
8. FCM notifications (mock Firebase)

---

## 📈 ARCHITECTURE OVERVIEW

```
┌─────────────────────────────────────────┐
│        Flutter Mobile App               │
│   (REST API + Socket.io WebSocket)      │
└────────────┬────────────────────────────┘
             │
             ├──────── HTTPS + JWT Auth
             │
┌────────────▼──────────────────────────────┐
│      Express.js Node.js Backend           │
├───────────────────────────────────────────┤
│ Middleware Stack:                        │
│ • Helmet (security headers)              │
│ • CORS, Rate-limit, Morgan (logging)     │
│ • AuthMiddleware (JWT validation)        │
├───────────────────────────────────────────┤
│ Routes & Controllers (~50 endpoints)     │
│ • Auth, Customer, Plan, Subscription     │
│ • Payment, Invoice, DailyOrder           │
│ • Report, Notification, Webhook          │
├───────────────────────────────────────────┤
│ Services & Business Logic                │
│ • Token, OTP, Payment, Notification      │
│ • Report, Delivery, Subscription         │
├───────────────────────────────────────────┤
│ Models (16 collections)                  │
│ • User, Customer, Plan, Subscription     │
│ • Payment, Invoice, DailyOrder, etc.     │
└────────────┬──────────────────────────────┘
             │
    ┌────────┴────────┬──────────┬─────────┐
    │                 │          │         │
┌───▼────┐  ┌────────▼─┐  ┌─────▼──┐  ┌──▼───┐
│MongoDB  │  │Firebase  │  │Razorpay│  │Cloud │
│ Atlas   │  │ FCM      │  │Gateway │  │nary  │
└─────────┘  └──────────┘  └────────┘  └──────┘

Socket.io: /delivery namespace (real-time)
Cron Jobs: Daily delivery generation, expiry check
```

---

## 💔 CRITICAL GAPS (Must Address)

1. **API Documentation** (need OpenAPI/Swagger)
2. **Testing** (need Jest + Supertest)
3. **CI/CD Pipeline** (need GitHub Actions)
4. **Error Monitoring** (need Sentry or equivalent)
5. **Performance Metrics** (need APM logging)

---

## 📞 QUICK LOOKUPS

### "How do I...?"

**Send OTP?**

```
POST /api/v1/auth/send-oTP
Body: { "phone": "9876543210" }
```

**Create subscription?**

```
POST /api/v1/subscriptions
Auth: Bearer <token>
Body: {
  "customerId": "...",
  "planId": "...",
  "startDate": "2026-03-01",
  "billingPeriod": "monthly"
}
```

**Record payment via Razorpay?**

```
1. POST /api/v1/payments/create-order (get orderId)
2. Mobile: open Razorpay checkout
3. Razorpay calls webhook: POST /api/v1/webhooks/razorpay
4. Backend verifies, creates Payment record
```

**Generate daily delivery orders?**

```
- Automatic: Cron job daily at 00:00
- Manual: POST /api/v1/daily-orders/generate
- Finds active subscriptions matching today's weekday
- Creates DailyOrder for each match
```

**Track delivery real-time?**

```
WebSocket: ws://api:5800/delivery
Auth: { token: accessToken }
Emit: socket.emit("location_update", { lat, lng })
Watch: socket.on("delivery_updated", callback)
```

**Generate invoice PDF?**

```
POST /api/v1/invoices/generate
Auto: Razorpay webhook
Manual: Call endpoint with dateRange
Output: PDF URL (Cloudinary)
```

---

## 🎯 PRODUCTION READINESS CHECKLIST

- [ ] All 50+ endpoints tested
- [ ] Error monitoring (Sentry) configured
- [ ] Database backups automated
- [ ] SSL certificate (Let's Encrypt) issued
- [ ] Environment variables secured (.env not in Git)
- [ ] Rate limiting tuned per endpoint
- [ ] Logging redacts PII (phone, OTP, tokens)
- [ ] CORS whitelist configured (production domain only)
- [ ] Razorpay webhook secret verified
- [ ] Firebase service account loaded
- [ ] Cloudinary credentials secure
- [ ] MongoDB Atlas IP whitelist updated
- [ ] Health check endpoint responding
- [ ] Load balancer configured
- [ ] Monitoring & alerting active

---

## 📖 FULL DOCUMENTATION

**See:** [COMPREHENSIVE_REQUIREMENTS.md](./COMPREHENSIVE_REQUIREMENTS.md)

This file contains:

- Full API documentation with request/response examples
- Complete database schema definitions
- Detailed business logic flows
- Security implementation details
- Infrastructure & deployment guides
- Technology stack with versions
- Known gaps & future roadmap

---

**Status:** 95% Feature-Complete | Ready for Testing & Hardening

**Last Generated:** February 27, 2026
