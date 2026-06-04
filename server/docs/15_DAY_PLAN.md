# TiffinCRM Backend — 15-Day Plan (Max 20 Days)

**Target:** Complete backend in 15 days. Use Days 16–20 as buffer if needed.

---

## How to use this plan

- **Each day:** Do the tasks in order. Mark tasks done (e.g. checkbox) as you go.
- **Hours:** Assume ~4–6 focused hours per day; adjust if you have more or less.
- **Blockers:** If a day slips, use buffer days (16–20). Don’t skip phases.
- **Free tier:** Use the [Part 6 — Free-tier-first](#) section in `PROJECT_ROADMAP.md` for every service.

---

## Day 1 — Project setup & foundation (Phase 0 start)

**Goal:** Dependencies, body parsing, CORS, env structure.

| # | Task | Done |
|---|------|------|
| 1 | Install: `cors`, `helmet`, `express-rate-limit`, `morgan`, `winston`, `joi` (or `zod`). | ☐ |
| 2 | Create `config/index.js`: load `dotenv`, export `PORT`, `MONGODB_URL`, `NODE_ENV`, `JWT_ACCESS_SECRET`, `JWT_REFRESH_SECRET`. Validate required vars and throw on missing. | ☐ |
| 3 | In `server.js`: add `express.json()`, `express.urlencoded({ extended: true })`, `cors` with `origin` from config (or env). | ☐ |
| 4 | Create `config/corsOptions.js` or set CORS in server: allow your Flutter app origin(s) only in prod. | ☐ |
| 5 | Update `index.js`: load config from `config/index.js` and use `config.PORT` (so env is validated at startup). | ☐ |
| 6 | Test: run app; call `GET /public` and one `POST` with JSON body; confirm body is parsed and CORS works. | ☐ |

**Exit:** App runs with env validation, JSON body parsing, and CORS.

---

## Day 2 — Security, logging, health (Phase 0 finish)

**Goal:** Helmet, rate limit, morgan, winston, `/health`, `/api/v1` prefix.

| # | Task | Done |
|---|------|------|
| 1 | In `server.js`: add `helmet()`. | ☐ |
| 2 | Add global rate limit: `express-rate-limit` (e.g. 100 requests per 15 min per IP). | ☐ |
| 3 | Create `middleware/requestId.js`: generate or use `X-Request-Id`; attach to `req.id`. | ☐ |
| 4 | Add `morgan`: dev format in development, JSON (with request id) in production. | ☐ |
| 5 | Create `utils/logger.js` with winston: console + file transport; log level from env. Do not log secrets. | ☐ |
| 6 | Add `GET /health`: check MongoDB connection (e.g. mongoose.connection.readyState); return 200 + `{ status, uptime, db }`. | ☐ |
| 7 | Create `routes/index.js`: mount all API routes under `/api/v1`. In `server.js` use `app.use("/api/v1", routes)`. Keep error handler last. | ☐ |
| 8 | Add auth-specific rate limit: for `/api/v1/auth` (e.g. 5 req/15 min per IP for send-otp). | ☐ |
| 9 | Test: hit `/health`, trigger rate limit, check logs and security headers. | ☐ |

**Exit:** Phase 0 complete. Health check works; rate limit and logging in place.

---

## Day 3 — Auth: User & Otp models, token service (Phase 1 start)

**Goal:** User and Otp models; JWT generate/verify.

| # | Task | Done |
|---|------|------|
| 1 | Create `models/User.model.js`: schema with `phone` (unique, required), `name`, `role` (default `admin`), `fcmToken`, `createdAt`, `updatedAt`. Index on `phone`. | ☐ |
| 2 | Create `models/Otp.model.js`: `phone`, `otp`, `expiresAt`. TTL index on `expiresAt` (e.g. 600 seconds). | ☐ |
| 3 | Create `services/token.service.js`: `generateAccessToken(payload)`, `generateRefreshToken(payload)`, `verifyAccessToken(token)`, `verifyRefreshToken(token)`. Use JWT_ACCESS_SECRET, JWT_REFRESH_SECRET, short access expiry (e.g. 15m), long refresh (e.g. 7d). | ☐ |
| 4 | Add `services/index.js` (optional): re-export services for clean imports. | ☐ |
| 5 | Unit-style check: call token service generate then verify; confirm payload matches. | ☐ |

**Exit:** User and Otp models exist; token service generates and verifies JWTs.

---

## Day 4 — Auth: OTP service, middleware, routes (Phase 1 finish)

**Goal:** Send/verify OTP; auth middleware; auth routes working.

| # | Task | Done |
|---|------|------|
| 1 | Create `services/otp.service.js`: `sendOtp(phone)` — generate 6-digit OTP, save to Otp collection with `expiresAt = now + 10 min`, call Twilio or Fast2SMS (use env for keys). Return success/failure. | ☐ |
| 2 | In otp.service: `verifyOtp(phone, otp)` — find Otp by phone, check not expired, compare OTP, delete document. Return boolean. | ☐ |
| 3 | Create `middleware/auth.middleware.js`: extract Bearer token, verify via token.service, attach `req.user = { userId, phone }`. On invalid/expired return 401 with ApiError. | ☐ |
| 4 | Create `controllers/auth.controller.js`: `sendOtp`, `verifyOtp`, `refreshToken`, `logout`. Use asyncHandler; validate body (Joi: phone, otp where needed). In verifyOtp: find or create User, generate tokens, return tokens + user. | ☐ |
| 5 | Create `routes/auth.routes.js`: POST send-otp, verify-otp, refresh-token, logout. Mount under `/api/v1/auth` in routes/index.js. | ☐ |
| 6 | Test with Postman/Thunder: send-otp → verify-otp → get tokens; call a protected route with Bearer token. | ☐ |

**Exit:** Phase 1 complete. Full OTP + JWT auth working.

---

## Day 5 — Customer & Plan models and CRUD (Phase 2 start)

**Goal:** Customer and Plan models; list/get/create/update for both.

| # | Task | Done |
|---|------|------|
| 1 | Create `models/Customer.model.js`: name, phone (unique), address, location (GeoJSON Point), customerType (enum), status (enum), fcmToken, whatsapp, isDeleted (default false), timestamps. Indexes: phone, status, createdAt. | ☐ |
| 2 | Create `models/Plan.model.js`: name, type (enum), price, frequency, description, isActive (default true), timestamps. | ☐ |
| 3 | Create `controllers/customer.controller.js`: list (paginated: page, limit, filter by status/type), getById, create, update. Use asyncHandler and ApiResponse/ApiError. All methods use auth middleware. | ☐ |
| 4 | Create `routes/customer.routes.js`: GET /, GET /:id, POST /, PUT /:id. Apply auth middleware. Mount in routes/index.js as `/customers`. | ☐ |
| 5 | Create `controllers/plan.controller.js`: list, getById, create, update. | ☐ |
| 6 | Create `routes/plan.routes.js`: GET /, GET /:id, POST /, PUT /:id. Mount as `/plans`. | ☐ |
| 7 | Add request validation (Joi) for customer and plan create/update bodies. | ☐ |
| 8 | Test: create customer and plan; list with pagination and filters. | ☐ |

**Exit:** Customer and Plan CRUD working with auth and validation.

---

## Day 6 — Subscription model and CRUD (Phase 2 middle)

**Goal:** Subscription model; create, list, get, renew, cancel.

| # | Task | Done |
|---|------|------|
| 1 | Create `models/Subscription.model.js`: customerId (ref Customer), planId (ref Plan), startDate, endDate, status (enum), billingPeriod (enum), autoRenew, price, paymentId (ref Payment, optional), timestamps. Indexes: customerId, planId, status, endDate. | ☐ |
| 2 | Create `services/subscription.service.js`: helper to compute `endDate` from startDate + billingPeriod (daily/weekly/monthly). | ☐ |
| 3 | Create `controllers/subscription.controller.js`: create (validate customer & plan exist, set endDate), list (filter by status, customerId), getById, renew (new start/end, status active), cancel (status cancelled). | ☐ |
| 4 | Create `routes/subscription.routes.js`: GET /, GET /:id, POST /, PUT /:id/renew, PUT /:id/cancel. Mount as `/subscriptions`. | ☐ |
| 5 | Add Joi validation for subscription create/renew body. | ☐ |
| 6 | Test: create subscription for a customer+plan; list; renew; cancel. | ☐ |

**Exit:** Subscription CRUD and renew/cancel working.

---

## Day 7 — Customer bulk import & Phase 2 polish (Phase 2 end)

**Goal:** Bulk import; soft delete; pagination standard.

| # | Task | Done |
|---|------|------|
| 1 | In customer.controller: add `bulkCreate` — accept array of `{ name, phone, address?, ... }`. Validate each; insert many. Rate limit this route (e.g. 5 req/15 min). | ☐ |
| 2 | Add POST `/customers/bulk` in customer.routes.js. | ☐ |
| 3 | Implement soft delete: PUT /:id with isDeleted: true (or dedicated DELETE that sets isDeleted). List endpoints filter out isDeleted by default. | ☐ |
| 4 | Standardize list responses: `{ data, total, page, limit, totalPages }` for customers, plans, subscriptions. | ☐ |
| 5 | Test bulk import with 5–10 records; test soft delete and list. | ☐ |

**Exit:** Phase 2 complete. Bulk import and pagination standard done.

---

## Day 8 — Delivery model, service, routes, cron (Phase 3 start)

**Goal:** Delivery APIs and daily generation cron.

| # | Task | Done |
|---|------|------|
| 1 | Create `models/Delivery.model.js`: customerId (ref), subscriptionId (ref), date, status (enum), deliveryBoyId (ref User, optional), location (GeoJSON), completedAt, timestamps. Indexes: date, status, customerId. | ☐ |
| 2 | Create `services/delivery.service.js`: `getTodaysDeliveries()` — find active subscriptions for today, merge with existing Delivery records for today; return list with customer/address. | ☐ |
| 3 | Create `controllers/delivery.controller.js`: getToday (call service), completeDelivery (update status to delivered, set completedAt). | ☐ |
| 4 | Create `routes/delivery.routes.js`: GET /today, PUT /:id/complete. Mount as `/deliveries`. | ☐ |
| 5 | Add cron job (e.g. in a `cron/` or `jobs/` folder, required from index.js after DB connect): at 00:00 (or configurable), find active subscriptions for today, create Delivery documents if not exist. Use `node-cron`. | ☐ |
| 6 | Test: create subscriptions; run cron or manually create deliveries; GET /deliveries/today; PUT complete. | ☐ |

**Exit:** Today’s deliveries and mark-complete working; cron creates daily deliveries.

---

## Day 9 — Socket.io real-time delivery (Phase 3 end)

**Goal:** Real-time delivery tracking (single instance; no Redis yet).

| # | Task | Done |
|---|------|------|
| 1 | Install `socket.io`. In `index.js` (or server.js): attach Socket.io to same HTTP server. | ☐ |
| 2 | Create `socket/delivery.socket.js` (or in a socket folder): namespace `/delivery`. On connection, verify JWT from handshake auth; attach user to socket. | ☐ |
| 3 | On event e.g. `location_update`, accept `{ lat, lng }` and broadcast to room (e.g. `delivery-today`) or to all in namespace. | ☐ |
| 4 | Emit server events e.g. `delivery_updated` when delivery is marked complete (from delivery.controller call socket emit). | ☐ |
| 5 | Document in API docs or README: connection URL, auth, event names. | ☐ |
| 6 | Test with a simple client (e.g. script or Flutter) if available. | ☐ |

**Exit:** Phase 3 complete. Real-time delivery updates over Socket.io (single node).

---

## Day 10 — Payment model, manual payment, Razorpay order (Phase 4 start)

**Goal:** Payment model; list; create (manual); Razorpay create order.

| # | Task | Done |
|---|------|------|
| 1 | Create `models/Payment.model.js`: customerId (ref), subscriptionId (ref optional), amount, method (enum), status (enum), razorpayOrderId, razorpayPaymentId, invoiceUrl, timestamps. | ☐ |
| 2 | Create `controllers/payment.controller.js`: list (filter by customerId, date range), create (manual: amount, method, customerId, subscriptionId?). | ☐ |
| 3 | Create `routes/payment.routes.js`: GET /, POST /. Mount as `/payments`. | ☐ |
| 4 | Install `razorpay`. Create `services/payment.service.js`: `createRazorpayOrder(amount, receiptId)` — call Razorpay API, return orderId. | ☐ |
| 5 | Add POST `/payments/create-order` (or similar): body amount, receipt (e.g. paymentId or subscriptionId); return Razorpay order_id and key_id for Flutter. | ☐ |
| 6 | Add Joi validation for payment create and create-order. | ☐ |
| 7 | Test: create manual payment; create Razorpay order (use test keys). | ☐ |

**Exit:** Payment list and create; Razorpay order creation working.

---

## Day 11 — Razorpay webhook, PDF invoice (Phase 4 end)

**Goal:** Webhook; PDF generation; invoice URL.

| # | Task | Done |
|---|------|------|
| 1 | Add Razorpay webhook route: raw body for signature verification. Verify signature with webhook secret; handle `payment.captured` (or equivalent): create/update Payment, link to subscription if applicable. Make handler idempotent (check razorpayPaymentId). | ☐ |
| 2 | Install `pdfkit`. Create `services/pdf.service.js`: `generateInvoice(paymentId)` — fetch Payment + Customer + Subscription, build PDF, save to Cloudinary (or local file then upload). Return public URL. | ☐ |
| 3 | Store `invoiceUrl` on Payment after generation. | ☐ |
| 4 | Add GET `/reports/invoice/:id` (or `/payments/:id/invoice`): check auth; return redirect to invoiceUrl or stream PDF. | ☐ |
| 5 | Create Cloudinary free account; configure upload in pdf service (or use file system + static URL for free tier). | ☐ |
| 6 | Test: complete a Razorpay test payment → webhook → Payment updated; generate invoice → GET invoice. | ☐ |

**Exit:** Phase 4 complete. Webhook and PDF invoice working.

---

## Day 12 — Firebase FCM and notification service (Phase 5 start)

**Goal:** FCM push from backend.

| # | Task | Done |
|---|------|------|
| 1 | Install `firebase-admin`. Create `config/firebase.js`: init with service account (from env or JSON file). | ☐ |
| 2 | Create `services/notification.service.js`: `sendToToken(token, title, body, data?)` — use Firebase Admin messaging. Handle invalid token (e.g. remove from User/Customer). | ☐ |
| 3 | Add endpoint to save FCM token: e.g. PUT `/api/v1/auth/me` or PATCH user profile with `fcmToken`. Store on User model. | ☐ |
| 4 | Trigger a test notification from a route (e.g. POST `/api/v1/notifications/test` for admin) that sends to req.user.fcmToken. | ☐ |
| 5 | Document how Flutter should send fcmToken after login. | ☐ |
| 6 | Test with Flutter app or a test token from Firebase console. | ☐ |

**Exit:** FCM send from backend working; token stored on User.

---

## Day 13 — Reports and subscription-expiry cron (Phase 5 end)

**Goal:** Report APIs; expiry cron.

| # | Task | Done |
|---|------|------|
| 1 | Create `services/report.service.js`: aggregation pipelines for summary — e.g. by period (day/week/month): active subscriptions count, revenue (from Payment), delivery counts. | ☐ |
| 2 | Create `controllers/report.controller.js`: getSummary (query param period). | ☐ |
| 3 | Create `routes/report.routes.js`: GET /summary. Mount as `/reports`. | ☐ |
| 4 | Add cron: daily (e.g. 01:00), find subscriptions where endDate < today, set status to `expired`. Optionally send FCM to customer. | ☐ |
| 5 | Wire report routes; test GET /reports/summary?period=monthly. | ☐ |
| 6 | Test expiry cron (temporarily set a subscription endDate in past and run job). | ☐ |

**Exit:** Phase 5 complete. Reports and expiry cron working.

---

## Day 14 — Validation, 404, errors, API docs (Phase 6)

**Goal:** Consistent validation and errors; basic API docs.

| # | Task | Done |
|---|------|------|
| 1 | Add Joi (or Zod) validation middleware: validate body/query/params per route; return 400 with clear messages for all public and protected routes. | ☐ |
| 2 | Add 404 handler: for any unregistered route return JSON `{ success: false, message: "Not found", code: "NOT_FOUND" }` with status 404. | ☐ |
| 3 | Ensure all controller errors use ApiError with consistent statusCode and optional error code (e.g. AUTH_001). | ☐ |
| 4 | Enforce max `limit` on all list APIs (e.g. 100). | ☐ |
| 5 | Create OpenAPI/Swagger spec or Postman collection: document all endpoints, request/response, auth header, error responses. | ☐ |
| 6 | Add a short README section: how to run, env vars, health check, main endpoints. | ☐ |

**Exit:** Phase 6 complete. Validation and API docs in place.

---

## Day 15 — Integration check and deploy prep

**Goal:** Full flow test; production env and deploy checklist.

| # | Task | Done |
|---|------|------|
| 1 | Run through full flow: send OTP → verify → create customer → plan → subscription → delivery today → mark complete → payment → invoice. | ☐ |
| 2 | Create `.env.example` with all required variables (no secrets). Document in README. | ☐ |
| 3 | Confirm all secrets come from env (no hardcoded keys). | ☐ |
| 4 | Choose free host (Render / Railway / Fly.io). Prepare: build command, start command, env vars, health check path. | ☐ |
| 5 | Ensure `/health` is used as health check URL. | ☐ |
| 6 | Optional: add PM2 config (ecosystem.config.js) for local or single-box production. | ☐ |

**Exit:** Backend feature-complete; ready to deploy on free tier.

---

## Days 16–20 — Buffer and polish (use if needed)

Use these only if you are behind or want extra quality.

| Day | Suggested focus |
|-----|------------------|
| **16** | Catch-up: complete any unfinished task from Days 1–15; fix bugs from integration test. |
| **17** | Testing: add a few critical route tests (e.g. auth, customer create, subscription create) with supertest or similar. |
| **18** | Performance: review indexes on all models; add any missing; test list APIs with 100+ records. |
| **19** | Security: run `npm audit`; review rate limits and CORS; ensure no secrets in logs. |
| **20** | Deploy: deploy to Render/Railway/Fly; configure MongoDB Atlas M0, Cloudinary, Razorpay test/live; test from Flutter. |

---

## One-page checklist (print or pin)

| Day | Focus |
|-----|--------|
| 1 | Setup, deps, config, body parsing, CORS |
| 2 | Helmet, rate limit, morgan, winston, /health, /api/v1 |
| 3 | User, Otp models; token service |
| 4 | OTP service, auth middleware, auth routes |
| 5 | Customer, Plan models + CRUD |
| 6 | Subscription model + CRUD + renew/cancel |
| 7 | Bulk import, soft delete, pagination |
| 8 | Delivery model, service, routes, cron |
| 9 | Socket.io delivery namespace |
| 10 | Payment model, list, create, Razorpay order |
| 11 | Webhook, PDF invoice, Cloudinary |
| 12 | Firebase Admin, notification service |
| 13 | Reports, expiry cron |
| 14 | Validation, 404, API docs |
| 15 | Integration test, deploy prep |
| 16–20 | Buffer, tests, security, deploy |

---

**All tech in Part 6:** Use free tiers (Atlas M0, Cloudinary free, Firebase Spark, Razorpay, Twilio/Fast2SMS free). Upgrade only when you need more storage, traffic, or multi-instance (e.g. Redis + load balancer). See `PROJECT_ROADMAP.md` Part 6 for the full free-tier table.
