# TiffinCRM Backend — Professional Roadmap

**Goal:** Build a production-grade, high-performance, secure backend with load balancing and full TiffinCRM feature parity.

- **15-day daily plan (max 20):** See [15_DAY_PLAN.md](./15_DAY_PLAN.md) for day-by-day tasks.
- **Free-tier-first tech:** Part 6 below lists free production options and when to upgrade.

---

## Part 1 — Step-by-step implementation order

Follow this sequence. Complete each phase before moving to the next.

---

### Phase 0: Foundation (Week 1)

**Objective:** Solid base for security, performance, and structure.

| Step | Task | Details |
|------|------|--------|
| 0.1 | **Add body parsing & CORS** | `express.json()`, `express.urlencoded()`, `cors` with allowed origins from env. |
| 0.2 | **Environment config** | Central `config/index.js` — validate required env (e.g. `MONGODB_URL`, `JWT_SECRET`, `NODE_ENV`). Use different `.env` per environment. |
| 0.3 | **Security middleware** | `helmet` (headers), `express-rate-limit` (global + stricter for `/auth`). |
| 0.4 | **Request logging** | `morgan` (JSON in prod, dev format in dev). Log request id, method, path, status, duration. |
| 0.5 | **Structured logging** | `winston` — levels, file + console. No secrets in logs. |
| 0.6 | **Health check** | `GET /health` — DB connected, uptime. Used by load balancer later. |
| 0.7 | **API versioning** | All routes under `/api/v1`. Keep `server.js` clean: mount `routes` only. |

**Exit criteria:** App runs with env validation, security headers, rate limit, logging, and `/health` returning 200 when DB is up.

---

### Phase 1: Authentication (Week 2)

**Objective:** OTP + JWT auth, no shortcuts.

| Step | Task | Details |
|------|------|--------|
| 1.1 | **User model** | `phone` (unique), `name`, `role`, `fcmToken`, timestamps. Index on `phone`. |
| 1.2 | **Otp model** | `phone`, `otp`, `expiresAt`. TTL index on `expiresAt` (e.g. 10 min). |
| 1.3 | **Token service** | Generate access (short) + refresh (long) JWT. Verify access token; optional refresh rotation. |
| 1.4 | **OTP service** | Send via Twilio or Fast2SMS. Store hashed or plain OTP with TTL. Rate limit per phone. |
| 1.5 | **Auth middleware** | Verify `Authorization: Bearer <token>`, attach `req.user`. Return 401 on invalid/expired. |
| 1.6 | **Auth routes** | `POST /api/v1/auth/send-otp`, `verify-otp`, `refresh-token`, `logout`. Use `asyncHandler`, validate body (e.g. Joi/Zod). |
| 1.7 | **Auth controller** | Thin controllers: call services, return `ApiResponse` or throw `ApiError`. |

**Exit criteria:** Flutter can send OTP, verify, get JWT, and call a protected route with the token.

---

### Phase 2: Core domain models & CRUD (Weeks 3–4)

**Objective:** Customer, Plan, Subscription with full CRUD and validation.

| Step | Task | Details |
|------|------|--------|
| 2.1 | **Customer model** | Per ER diagram. Indexes: `phone` (unique), `status`, `createdAt`. Geo index on `location` if used. |
| 2.2 | **Plan model** | name, type, price, frequency, description, isActive. |
| 2.3 | **Customer routes & controller** | List (paginated, filter by status/type), get by id, create, update, soft delete. All protected. |
| 2.4 | **Plan routes & controller** | List, get, create, update. Protected. |
| 2.5 | **Subscription model** | customerId, planId, startDate, endDate, status, billingPeriod, autoRenew, price, paymentId. Indexes: customerId, planId, status, endDate. |
| 2.6 | **Subscription routes & controller** | List (filter by status/customer), get, create, renew, cancel. Validate customer & plan exist; compute endDate from billingPeriod. |
| 2.7 | **Bulk import** | `POST /api/v1/customers/bulk` — accept array, validate, insert many. Rate limit. |

**Exit criteria:** All CRUD for Customer, Plan, Subscription working; pagination and filters in place.

---

### Phase 3: Delivery & real-time (Weeks 5–6)

**Objective:** Daily delivery list, status updates, optional real-time tracking.

| Step | Task | Details |
|------|------|--------|
| 3.1 | **Delivery model** | customerId, subscriptionId, date, status, deliveryBoyId, location (GeoJSON), completedAt. Indexes: date, status, customerId. |
| 3.2 | **Delivery service** | “Today’s deliveries”: active subscriptions for date + existing delivery records. Create/update delivery rows. |
| 3.3 | **Delivery routes** | `GET /api/v1/deliveries/today`, `PUT /api/v1/deliveries/:id/complete` (and optional status update). |
| 3.4 | **Socket.io** | Namespace e.g. `/delivery`. Auth via JWT in handshake. Server receives location updates; broadcast to relevant clients. |
| 3.5 | **Cron: daily delivery generation** | `node-cron` at midnight (or configurable): create delivery records for active subscriptions for today. |

**Exit criteria:** Today’s list API works; delivery can be marked complete; optional live location over Socket.io.

---

### Phase 4: Payments & invoices (Weeks 7–8)

**Objective:** Record payments, Razorpay integration, PDF invoices.

| Step | Task | Details |
|------|------|--------|
| 4.1 | **Payment model** | customerId, subscriptionId, amount, method, status, razorpayOrderId/paymentId, invoiceUrl. |
| 4.2 | **Payment routes** | List (filter by customer/date), create (manual), Razorpay create-order. Webhook for Razorpay (verify signature, idempotent). |
| 4.3 | **PDF service** | Use `pdfkit` (or similar): generate invoice from Payment + Customer + Subscription. Store in Cloudinary or S3; save `invoiceUrl` on Payment. |
| 4.4 | **Invoice route** | `GET /api/v1/reports/invoice/:id` — return PDF or redirect to stored URL. Protected. |

**Exit criteria:** Manual and Razorpay payments recorded; webhook updates status; invoice PDF generated and URL stored.

---

### Phase 5: Notifications & reporting (Weeks 9–10)

**Objective:** FCM push, reports, analytics endpoints.

| Step | Task | Details |
|------|------|--------|
| 5.1 | **Firebase Admin** | Init with service account. Store FCM tokens on User/Customer. |
| 5.2 | **Notification service** | Send to token(s); handle errors (invalid token → remove). Use for subscription expiry, delivery updates, etc. |
| 5.3 | **Reports service** | Aggregation pipelines: summary by period (day/week/month), active/expired counts, revenue, delivery counts. |
| 5.4 | **Reports routes** | `GET /api/v1/reports/summary?period=monthly`, etc. Protected. |
| 5.5 | **Cron: subscription expiry** | Daily job: set status to `expired` where endDate < today; optionally trigger notifications. |

**Exit criteria:** Push sent from backend; report APIs return correct aggregates; expiry cron runs.

---

### Phase 6: Hardening & polish (Week 11)

**Objective:** Validation, errors, and small features.

| Step | Task | Details |
|------|------|--------|
| 6.1 | **Request validation** | Joi or Zod for every body/query/params. Return 400 with clear messages. |
| 6.2 | **404 handler** | For unknown routes return consistent JSON 404. |
| 6.3 | **Error codes** | Use your `ApiError`; consistent codes (e.g. AUTH_001, CUST_002) for client handling. |
| 6.4 | **Pagination standard** | All list APIs: `page`, `limit`, `sort`. Response: `data`, `total`, `page`, `limit`, `totalPages`. |
| 6.5 | **API documentation** | OpenAPI/Swagger or Postman collection; document all endpoints, auth, and errors. |

**Exit criteria:** All inputs validated; 404 and errors consistent; docs up to date.

---

## Part 2 — High traffic & performance

### 2.1 Application-level

| Area | Action |
|------|--------|
| **Async everywhere** | No blocking sync I/O. Use `asyncHandler` for route handlers. |
| **Lean queries** | Select only needed fields (`.select()`). Use `lean()` for read-only responses. |
| **Indexes** | Index every filter/sort (e.g. customerId, date, status, phone). Compound indexes for common queries. |
| **Pagination** | Enforce max `limit` (e.g. 100). Cursor-based for very large lists if needed later. |
| **Connection pool** | Mongoose default pool is fine; tune `maxPoolSize` if needed (e.g. 10–50). |
| **Compression** | `compression()` middleware for JSON responses. |

### 2.2 Caching (add when traffic grows)

| Layer | Use case | Tool |
|-------|----------|-----|
| **In-memory** | Rate-limit counters, short-lived OTP cache | Already in app |
| **Redis** | Session/refresh token blocklist, API response cache (e.g. today’s delivery list for 1 min), rate limit store | Redis |
| **HTTP cache** | Static assets, public health | Cache-Control headers |

Cache invalidation: invalidate on write (e.g. when delivery is updated, clear “today’s list” cache).

### 2.3 Database

| Action | Details |
|--------|--------|
| **MongoDB Atlas** | Use M10+ for production; enable backup and point-in-time restore. |
| **Read preference** | For reporting/analytics, use `readPreference: 'secondary'` if you have replicas. |
| **Aggregation** | Use pipelines for reports; avoid N+1. |
| **TTL indexes** | Use for Otp and any temporary data. |

---

## Part 3 — Load balancing & scaling

### 3.1 Single region (to start)

```
                    [Load Balancer]
                          |
         +----------------+----------------+
         |                |                |
    [Node 1]         [Node 2]         [Node 3]
         |                |                |
         +----------------+----------------+
                          |
                    [MongoDB Atlas]
```

- **Load balancer:** AWS ALB, GCP LB, or Nginx. Health check: `GET /health` every 10–30 s.
- **Nodes:** Same Node.js app on multiple instances (e.g. 2–4). Stateless: no in-memory sessions; JWT only.
- **Sticky sessions:** Not required for REST; for Socket.io see below.

### 3.2 Socket.io with multiple nodes

- Use **Redis adapter** for Socket.io so rooms and broadcasts work across nodes.
- Sticky sessions (by session id) on the load balancer so the same client hits the same Node instance for that WebSocket (optional but can simplify).

### 3.3 Horizontal scaling checklist

1. No in-memory state for user data (only JWT validation).
2. Rate limit and session/blocklist in Redis when you introduce it.
3. File uploads to Cloudinary/S3, not local disk.
4. Cron: run on one instance only (e.g. leader election via Redis lock or run cron on a separate “worker” process).

---

## Part 4 — Security & privacy

### 4.1 Authentication & authorization

| Item | Action |
|------|--------|
| **JWT** | Short-lived access token (15–60 min). Refresh token long-lived, stored securely in app only; rotate on use. |
| **Secrets** | Store in env (e.g. `JWT_ACCESS_SECRET`, `JWT_REFRESH_SECRET`). Never in code. Use different secrets per environment. |
| **Roles** | Add `role` to User and JWT payload. Middleware: `requireRole('admin')` for sensitive routes. |
| **Logout** | Optional: blacklist refresh token in Redis until expiry. |

### 4.2 Input & output

| Item | Action |
|------|--------|
| **Validation** | Validate and sanitize all body, query, params. Reject unknown fields if desired (e.g. Joi strip). |
| **IDs** | Use MongoDB ObjectIds; validate format to avoid injection. |
| **Passwords** | Not used in OTP flow; if you add password later, hash with bcrypt (cost 10–12). |
| **Sensitive response** | Never return OTP, tokens, or internal errors to client. Log full error server-side only. |

### 4.3 Transport & infrastructure

| Item | Action |
|------|--------|
| **HTTPS** | Enforce TLS in production (load balancer or reverse proxy). |
| **Headers** | Helmet: X-Content-Type-Options, X-Frame-Options, etc. |
| **CORS** | Allow only your Flutter app origin(s); no wildcard in prod. |
| **Rate limiting** | Global (e.g. 100/min per IP) + stricter on auth (e.g. 5/min per phone for send-otp). |

### 4.4 Data privacy

| Item | Action |
|------|--------|
| **PII** | Treat phone, name, address as PII. Access only for authenticated/authorized users. |
| **Logs** | Sanitize: no phone, email, or address in logs (you already have patterns in errorHandler; apply to all log lines). |
| **Retention** | Define retention for Otp (already TTL), logs, and backups. Document in privacy policy. |
| **Deletion** | Soft delete customers; support hard delete or anonymize for GDPR-style requests. |

### 4.5 Dependencies

- Run `npm audit` regularly; fix high/critical.
- Pin major versions; update dependencies in a controlled way.

---

## Part 5 — Checklist: all TiffinCRM features

Use this to ensure nothing is missed.

| # | Feature | API / component | Phase |
|---|---------|-----------------|--------|
| 1 | OTP send | POST /auth/send-otp | 1 |
| 2 | OTP verify + JWT | POST /auth/verify-otp | 1 |
| 3 | Refresh token | POST /auth/refresh-token | 1 |
| 4 | Logout | POST /auth/logout | 1 |
| 5 | Customer CRUD | /api/v1/customers | 2 |
| 6 | Customer bulk import | POST /api/v1/customers/bulk | 2 |
| 7 | Plan CRUD | /api/v1/plans | 2 |
| 8 | Subscription CRUD | /api/v1/subscriptions | 2 |
| 9 | Subscribe / Renew / Cancel | PUT .../renew, .../cancel | 2 |
| 10 | Today’s deliveries | GET /api/v1/deliveries/today | 3 |
| 11 | Mark delivery complete | PUT /api/v1/deliveries/:id/complete | 3 |
| 12 | Real-time location | Socket.io /delivery | 3 |
| 13 | Daily delivery generation | Cron | 3 |
| 14 | List payments | GET /api/v1/payments | 4 |
| 15 | Record payment | POST /api/v1/payments | 4 |
| 16 | Razorpay order + webhook | POST payments, webhook | 4 |
| 17 | PDF invoice | GET /api/v1/reports/invoice/:id | 4 |
| 18 | FCM push | Notification service | 5 |
| 19 | Reports summary | GET /api/v1/reports/summary | 5 |
| 20 | Subscription expiry cron | Cron | 5 |
| 21 | Health check | GET /health | 0 |
| 22 | Rate limit + Helmet | Middleware | 0 |

---

## Part 6 — Suggested tech list (summary)

### Free-tier-first for production (upgrade when needed)

Use free tiers in production; upgrade only when you hit limits or need real-time scale.

| Concern | Choice (free tier) | Free limit / notes | When to upgrade |
|--------|---------------------|--------------------|------------------|
| **Validation** | Joi or Zod | No limit (OSS) | — |
| **Auth** | JWT (jsonwebtoken) | No limit (OSS) | — |
| **Refresh blocklist** | In-memory Set (or skip) | Single instance only | Add Redis when multi-node or logout must work across instances |
| **OTP** | Twilio Trial or Fast2SMS | Twilio: trial credits. Fast2SMS: free tier (limited SMS/day) | Paid when SMS volume grows |
| **DB** | MongoDB Atlas **M0 (Free)** | 512 MB, shared cluster | M10+ when you need more storage, backups, or dedicated |
| **Cache** | Skip initially | — | Add Redis (e.g. Redis Cloud 30MB free, Upstash) when you need cache or multi-node Socket.io |
| **File storage** | **Cloudinary** free tier | 25 credits/month, 25 GB storage, 25 GB bandwidth | Paid when storage/bandwidth grows |
| **PDF** | pdfkit | No limit (OSS) | — |
| **Real-time** | Socket.io (no Redis) | Single Node instance | Add Redis adapter when you run 2+ Node instances behind LB |
| **Cron** | node-cron | No limit (OSS) | — |
| **Push** | **Firebase** (Spark / free) | Unlimited FCM; no cost for FCM itself | Blaze if you use Firestore/Cloud Functions at scale |
| **Payments** | **Razorpay** | No monthly fee; pay per transaction | — |
| **Logging** | winston + morgan | No limit (OSS) | — |
| **Security** | helmet, express-rate-limit, CORS | No limit (OSS) | — |
| **Process manager** | PM2 (free) | No limit (OSS) | — |
| **Hosting** | **Render** free / **Railway** trial / **Fly.io** free | Render: free tier for web services. Railway: trial credits. Fly: free allowance | Paid tier when you need always-on, more RAM, or custom domain without limits |
| **Load balancer** | Skip until multi-instance | — | Use cloud LB (e.g. AWS ALB, GCP LB) when you run 2+ app instances |

**Summary:** Start with Atlas M0, Cloudinary free, Firebase Spark, Razorpay, Twilio/Fast2SMS free tier, single Node on Render/Railway/Fly free. Add Redis and load balancer only when you go multi-instance or need cross-instance logout/cache.

### Full tech list (reference)

| Concern | Choice |
|--------|--------|
| Validation | Joi or Zod |
| Auth | JWT (jsonwebtoken) + optional Redis for refresh blocklist |
| OTP | Twilio or Fast2SMS |
| DB | MongoDB Atlas (M0 free → M10+ prod) |
| Cache (later) | Redis (e.g. Redis Cloud free, Upstash) |
| File storage | Cloudinary or S3 |
| PDF | pdfkit |
| Real-time | Socket.io (+ Redis adapter when multi-node) |
| Cron | node-cron |
| Push | Firebase Admin SDK |
| Payments | Razorpay (webhook + signature verify) |
| Logging | winston + morgan |
| Security | helmet, express-rate-limit, CORS |
| Process manager (single box) | PM2 cluster mode |
| Load balancer | Only when 2+ instances (e.g. Render/Railway/Fly scale-out or cloud LB) |

---

## Part 7 — Order of execution (recap)

1. **Phase 0** — Foundation (env, security, logging, health, API prefix).
2. **Phase 1** — Auth (User, Otp, JWT, OTP service, middleware, routes).
3. **Phase 2** — Customer, Plan, Subscription (models, CRUD, bulk import).
4. **Phase 3** — Delivery (model, today’s list, complete, Socket.io, cron).
5. **Phase 4** — Payment (model, Razorpay, webhook, PDF invoice).
6. **Phase 5** — Notifications (FCM), reports, expiry cron.
7. **Phase 6** — Validation, 404, pagination standard, API docs.
8. **Then** — Add Redis (cache + Socket.io adapter), load balancer, and multi-instance deployment.

Following this roadmap will give you a step-by-step path to a complete, high-performance, load-balanced, and secure TiffinCRM backend. If you tell me your current phase, I can outline the exact files and code changes for the next step.
