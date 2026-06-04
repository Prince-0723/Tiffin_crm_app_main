# TiffinCRM Backend — Next 15-Day Plan (Days 16–30)

**Current Status:** Phase 0–5 Complete | Ready for Testing, Hardening & Production Prep  
**Target:** Production-ready backend with comprehensive tests, documentation, and optimization

---

## Overview: What's Next?

The first 15 days delivered all core features. The next 15 days focus on:

1. **Testing** — Unit & integration tests for critical paths
2. **Documentation** — API docs, Swagger/OpenAPI, deployment guides
3. **Performance** — Database optimization, caching strategy
4. **Hardening** — Security audit, rate limiting refinement, error handling
5. **DevOps** — CI/CD setup, deployment checklist, monitoring
6. **Advanced Features** — Enhancements to existing modules

---

## Day 16 — Test Framework Setup & Auth Tests (Testing Phase Start)

**Goal:** Set up test infrastructure; test authentication flow end-to-end.

| #   | Task                                                                                                                    | Done |
| --- | ----------------------------------------------------------------------------------------------------------------------- | ---- |
| 1   | Install `jest`, `supertest`, `@testing-library/jest-dom`. Add test script to package.json: `"test": "jest --coverage"`. | ☐    |
| 2   | Create `__tests__/setup.js`: MongoDB connection for tests (use test DB or in-memory mock).                              | ☐    |
| 3   | Create `__tests__/auth.test.js`: test sendOtp, verifyOtp, refreshToken, logout. Mock MSG91 API.                         | ☐    |
| 4   | Write tests: invalid phone format, expired OTP, invalid token, successful flow.                                         | ☐    |
| 5   | Run tests; ensure 100% pass rate and >80% code coverage for auth module.                                                | ☐    |
| 6   | Add lint script: `"lint": "eslint ."` and configure ESLint.                                                             | ☐    |

**Exit:** Auth tests pass; test framework ready for other modules.

---

## Day 17 — Customer & Subscription Tests

**Goal:** Test CRUD for customers and subscriptions.

| #   | Task                                                                                                      | Done |
| --- | --------------------------------------------------------------------------------------------------------- | ---- |
| 1   | Create `__tests__/customer.test.js`: test list, getById, create, update, bulk import, soft delete.        | ☐    |
| 2   | Create `__tests__/subscription.test.js`: test create (validate plan/customer exist), list, renew, cancel. | ☐    |
| 3   | Test edge cases: duplicate phone, invalid plan, renewal with past start date, multiple renewals.          | ☐    |
| 4   | Mock Customer and Plan dependencies; ensure isolation (no DB pollution).                                  | ☐    |
| 5   | Run tests; fix any failures. Aim for >85% coverage in these modules.                                      | ☐    |
| 6   | Optional: add Postman collection for manual testing (export from tests or create separately).             | ☐    |

**Exit:** Customer and subscription CRUD tests pass with high coverage.

---

## Day 18 — Payment & Invoice Tests

**Goal:** Test payment flow and invoice generation.

| #   | Task                                                                                                                  | Done |
| --- | --------------------------------------------------------------------------------------------------------------------- | ---- |
| 1   | Create `__tests__/payment.test.js`: test create payment, list, Razorpay order creation (mock API).                    | ☐    |
| 2   | Create `__tests__/webhook.test.js`: test Razorpay webhook signature verification, payment status update, idempotency. | ☐    |
| 3   | Create `__tests__/invoice.test.js`: test generate, list, share token expiry, PDF generation (mock Cloudinary).        | ☐    |
| 4   | Mock external APIs: Razorpay, Cloudinary, SMS service.                                                                | ☐    |
| 5   | Test error cases: invalid signature, duplicate webhook, Cloudinary upload failure.                                    | ☐    |
| 6   | Run all tests; target >80% coverage. Generate coverage report.                                                        | ☐    |

**Exit:** Payment and invoice flows tested with external APIs mocked.

---

## Day 19 — Delivery & Real-time Tests

**Goal:** Test delivery endpoints and Socket.io real-time functionality.

| #   | Task                                                                                                             | Done |
| --- | ---------------------------------------------------------------------------------------------------------------- | ---- |
| 1   | Create `__tests__/dailyOrder.test.js`: test getToday, processToday, markDelivered, generateOrders.               | ☐    |
| 2   | Create `__tests__/delivery.socket.test.js`: test Socket.io connection, location_update event, broadcast.         | ☐    |
| 3   | Test cron jobs: mock node-cron, verify delivery generation at expected times.                                    | ☐    |
| 4   | Test subscription expiry cron: simulate past-end-date subscriptions, verify status update and notification sent. | ☐    |
| 5   | Integration test: subscribe → receive delivery today → mark delivered → verify Socket.io events.                 | ☐    |
| 6   | Run tests; ensure Socket.io and cron logic are bulletproof.                                                      | ☐    |

**Exit:** Delivery and real-time flows tested; cron jobs verified.

---

## Day 20 — Integration Test Suite & CI/CD Pipeline Setup

**Goal:** Full-flow integration tests; CI/CD ready.

| #   | Task                                                                                                                                                                 | Done |
| --- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---- |
| 1   | Create `__tests__/integration.test.js`: full flow — send OTP → verify → create customer → plan → subscribe → get today's deliveries → mark complete → list payments. | ☐    |
| 2   | Set up `.github/workflows/test.yml`: run `npm test` on every push to main/dev.                                                                                       | ☐    |
| 3   | Add GitHub Actions badge to README.                                                                                                                                  | ☐    |
| 4   | Configure codecov or Coveralls for coverage reporting. Optional: add coverage badge.                                                                                 | ☐    |
| 5   | Set up pre-commit hook with husky: run lint and tests before commit.                                                                                                 | ☐    |
| 6   | Test CI/CD: push a branch, verify actions trigger, tests run, coverage reported.                                                                                     | ☐    |

**Exit:** CI/CD pipeline active; full-flow integration tests pass.

---

## Day 21 — API Documentation & Swagger Setup (Docs Phase Start)

**Goal:** OpenAPI/Swagger spec and API documentation.

| #   | Task                                                                                                                                                   | Done |
| --- | ------------------------------------------------------------------------------------------------------------------------------------------------------ | ---- |
| 1   | Install `swagger-ui-express` and `swagger-jsdoc`.                                                                                                      | ☐    |
| 2   | Create `swagger.js`: define OpenAPI 3.0 spec for all endpoints (auth, customer, plan, subscription, payment, delivery, invoice, notification, report). | ☐    |
| 3   | In `server.js`: add route `GET /api-docs` → Swagger UI serves spec.                                                                                    | ☐    |
| 4   | Document request/response schemas, status codes, errors for all endpoints.                                                                             | ☐    |
| 5   | Add security scheme (Bearer token) to Swagger.                                                                                                         | ☐    |
| 6   | Test: open `/api-docs`; verify all endpoints visible; test "Try it out" feature.                                                                       | ☐    |

**Exit:** Swagger API docs live at `/api-docs` with all endpoints documented.

---

## Day 22 — README & Deployment Guide

**Goal:** Complete README with setup, env vars, local development, deployment.

| #   | Task                                                                                                       | Done |
| --- | ---------------------------------------------------------------------------------------------------------- | ---- |
| 1   | Update main `README.md`: project overview, features, tech stack.                                           | ☐    |
| 2   | Add "Getting Started" section: clone, `npm install`, set `.env`, `npm run dev`.                            | ☐    |
| 3   | Document all environment variables with examples in `.env.example`.                                        | ☐    |
| 4   | Add "API Overview" section with examples of key endpoints (send-otp, list customers, create subscription). | ☐    |
| 5   | Add "Deployment" section: instructions for Render, Railway, or Fly.io. Include MongoDB Atlas M0 setup.     | ☐    |
| 6   | Add "Testing" section: how to run tests, coverage, CI/CD info.                                             | ☐    |
| 7   | Add "Architecture" section: project structure, file organization, design patterns used.                    | ☐    |

**Exit:** README complete; `.env.example` comprehensive; deployment guide clear.

---

## Day 23 — 404 Handler, Error Response Standardization & Hardening

**Goal:** Explicit error handlers, consistent error responses, security audit.

| #   | Task                                                                                                                                                     | Done |
| --- | -------------------------------------------------------------------------------------------------------------------------------------------------------- | ---- |
| 1   | Add explicit 404 route handler in `server.js` (after all routes): return `{ success: false, message: "Not found", code: "NOT_FOUND", statusCode: 404 }`. | ☐    |
| 2   | Review all error responses: standardize format (success, message, code, statusCode, data). Use ApiError consistently.                                    | ☐    |
| 3   | Add error code enum in `class/apiErrorClass.js` for consistent codes (e.g. `AUTH_001`, `CUST_001`, `PAYMENT_001`).                                       | ☐    |
| 4   | Update error handler middleware: ensure all errors are caught, logged (without secrets), and returned in standard format.                                | ☐    |
| 5   | Run `npm audit`: fix any high/critical vulnerabilities.                                                                                                  | ☐    |
| 6   | Security audit: verify CORS is restrictive in prod, rate limits are configured, HTTPS is enforced (via reverse proxy/host), secrets are in env.          | ☐    |

**Exit:** 404 handler works; errors are standardized; security audit passed.

---

## Day 24 — Performance Optimization & Database Indexing Review

**Goal:** Optimize queries, review indexes, benchmark critical endpoints.

| #   | Task                                                                                                                                  | Done |
| --- | ------------------------------------------------------------------------------------------------------------------------------------- | ---- |
| 1   | Review all models: verify indexes exist on frequently queried fields (phone, status, customerId, date, ownerId). Add missing indexes. | ☐    |
| 2   | Review list endpoints: use `.select()` to fetch only needed fields; ensure `.lean()` on read-only queries.                            | ☐    |
| 3   | Create N+1 query checks: ensure population is only where needed (not in loops).                                                       | ☐    |
| 4   | Add response compression middleware: `compression()` before routes.                                                                   | ☐    |
| 5   | Benchmark key endpoints: list customers (1000 records), list deliveries (100 records), get report. Log response times.                | ☐    |
| 6   | Optimize slow queries if found (e.g., add compound index for (ownerId, date)).                                                        | ☐    |

**Exit:** Indexes optimized; queries lean and performant; compression enabled.

---

## Day 25 — Rate Limiting Refinement & Endpoint Protection

**Goal:** Granular rate limiting, endpoint-specific protection.

| #   | Task                                                                                                                   | Done |
| --- | ---------------------------------------------------------------------------------------------------------------------- | ---- |
| 1   | Review current rate limits: global 100/15min, auth-specific (inherited from global?). Define endpoint-specific limits: | ☐    |
|     | - OTP send: 3 per 10 min per phone (not per IP, to prevent account enumeration)                                        | ☐    |
|     | - Bulk import: 2 per 30 min per user                                                                                   | ☐    |
|     | - Webhook: bypass (verify signature instead)                                                                           | ☐    |
|     | - List endpoints: 100 per min per user (no strict limit needed)                                                        | ☐    |
| 2   | Create custom rate limit middleware per route. Use `express-rate-limit` with keyGenerator for per-phone limits.        | ☐    |
| 3   | Test rate limits: exceed limits, verify 429 response and backoff guidance.                                             | ☐    |
| 4   | Document rate limits in README and Swagger.                                                                            | ☐    |
| 5   | Optional: prepare for Redis-based rate limiting when you scale (for now, in-memory store is fine).                     | ☐    |

**Exit:** Rate limits are granular and appropriate per endpoint.

---

## Day 26 — Logging, Monitoring & Error Tracking Setup

**Goal:** Production-ready logging; error tracking with Sentry.

| #   | Task                                                                                                                 | Done |
| --- | -------------------------------------------------------------------------------------------------------------------- | ---- |
| 1   | Install `@sentry/node`, `@sentry/tracing`.                                                                           | ☐    |
| 2   | In `config/index.js`: add `SENTRY_DSN` from env (optional, skip if not ready).                                       | ☐    |
| 3   | In `server.js`: initialize Sentry before routes; add error handler.                                                  | ☐    |
| 4   | Verify secrets are redacted in all logs: check logger patterns in `utils/logger.js`.                                 | ☐    |
| 5   | Test: trigger an error (e.g., invalid request); verify it's logged, sanitized, and sent to Sentry (if DSN provided). | ☐    |
| 6   | Document logging strategy in README: what's logged, retention, Sentry integration.                                   | ☐    |

**Exit:** Production logging in place; Sentry ready (optional).

---

## Day 27 — Advanced Features: Delivery Staff & Zone Management Endpoints

**Goal:** Full CRUD for delivery staff and zones; assign staff to zones.

| #   | Task                                                                                                                 | Done |
| --- | -------------------------------------------------------------------------------------------------------------------- | ---- |
| 1   | Create `controllers/deliveryStaff.controller.js`: list, getById, create, update, deactivate. Validate zone IDs.      | ☐    |
| 2   | Create `controllers/zone.controller.js`: list, getById, create, update, deactivate.                                  | ☐    |
| 3   | Create `routes/deliveryStaff.routes.js`: GET /, GET /:id, POST /, PUT /:id, DELETE /:id. Mount as `/delivery-staff`. | ☐    |
| 4   | Create `routes/zone.routes.js`: GET /, GET /:id, POST /, PUT /:id. Mount as `/zones`.                                | ☐    |
| 5   | Add endpoints for assigning staff to zones: PUT `/delivery-staff/:id/zones`.                                         | ☐    |
| 6   | Test: create zones, create delivery staff, assign staff to zone, list staff + zones.                                 | ☐    |

**Exit:** Delivery staff and zone CRUD fully functional.

---

## Day 28 — Advanced Features: Raw Materials & Inventory Endpoints

**Goal:** CRUD for raw materials; inventory tracking, low-stock alerts.

| #   | Task                                                                                                                          | Done |
| --- | ----------------------------------------------------------------------------------------------------------------------------- | ---- |
| 1   | Create `controllers/rawMaterial.controller.js`: list, getById, create, update, delete. Add filter by category, isActive.      | ☐    |
| 2   | Create `routes/rawMaterial.routes.js`: GET /, GET /:id, POST /, PUT /:id, DELETE /:id. Mount as `/raw-materials`.             | ☐    |
| 3   | Add low-stock check endpoint: GET `/raw-materials/low-stock` — returns materials where currentStock < minimumStock.           | ☐    |
| 4   | Add stock update endpoint: PUT `/raw-materials/:id/stock` — update currentStock (for issue/receive). Log changes in AuditLog. | ☐    |
| 5   | Create service function: `getLowStockMaterials(ownerId)` for alerts.                                                          | ☐    |
| 6   | Test: create materials, set low stock triggers, check alerts.                                                                 | ☐    |

**Exit:** Raw material CRUD and inventory tracking working.

---

## Day 29 — Advanced Features: Daily Menu Endpoints & Reports Enhancement

**Goal:** Daily menu management; enhanced reporting with inventory impact.

| #   | Task                                                                                                                      | Done |
| --- | ------------------------------------------------------------------------------------------------------------------------- | ---- |
| 1   | Create `controllers/dailyMenu.controller.js`: list, getById, create (for specific date), update, delete.                  | ☐    |
| 2   | Create `routes/dailyMenu.routes.js`: GET /, GET /:id, POST /, PUT /:id, DELETE /:id. Mount as `/daily-menu`.              | ☐    |
| 3   | Extend `report.service.js`: add `getMenuForDate(date)` and `getMaterialRequirementsForMenu(menu)`.                        | ☐    |
| 4   | Extend report routes: GET `/reports/menu-for-date?date=2026-02-28`, GET `/reports/material-requirements?date=2026-02-28`. | ☐    |
| 5   | Test: create menu, fetch materials needed, compare against current stock.                                                 | ☐    |
| 6   | Optional: add export-to-CSV for menus and material requirements.                                                          | ☐    |

**Exit:** Daily menu management and enhanced reporting active.

---

## Day 30 — Production Checklist, Deployment Prep & Final Polish

**Goal:** Ready for production deployment; deployment checklist complete.

| #   | Task                                                                                                                                                   | Done |
| --- | ------------------------------------------------------------------------------------------------------------------------------------------------------ | ---- |
| 1   | **Environment Setup:** Verify `.env.example` has all required vars (MONGODB_URL, JWT secrets, MSG91, Razorpay, Firebase, Cloudinary, Sentry optional). | ☐    |
| 2   | **Security Checklist:** Secrets not in code; CORS restrictive in prod; rate limits tuned; helmet active; HTTPS enforced.                               | ☐    |
| 3   | **Database:** MongoDB Atlas M0 created; backups configured; indexes verified.                                                                          | ☐    |
| 4   | **Cloudinary:** Account created; upload config in `config/` and `pdf.service.js`.                                                                      | ☐    |
| 5   | **Firebase:** Service account JSON loaded; FCM tokens stored correctly.                                                                                | ☐    |
| 6   | **Razorpay Test:** Test payment flow end-to-end with test keys.                                                                                        | ☐    |
| 7   | **Deployment Platform:** Render/Railway/Fly.io account created; app configured with build/start commands.                                              | ☐    |
| 8   | **Health Check:** `/health` endpoint returns 200 when app + DB are up; LB can use this.                                                                | ☐    |
| 9   | **Logs:** Setup log rotation; define retention policy (e.g., 30 days).                                                                                 | ☐    |
| 10  | **README:** Final review — all sections complete, clear, and up-to-date.                                                                               | ☐    |
| 11  | **Documentation:** Swagger docs live; Postman collection exported; deployment guide complete.                                                          | ☐    |
| 12  | **Final Test:** Full local flow test (OTP → subscribe → delivery → payment → invoice). Deploy to staging.                                              | ☐    |

**Exit:** Backend 100% production-ready; deployment checklist signed off.

---

## Days 31–35 (Buffer — Use if Needed)

Use these days if any of Days 16–30 slip, or for:

| Day    | Focus                                                                                                  |
| ------ | ------------------------------------------------------------------------------------------------------ |
| **31** | Write more comprehensive test cases; add E2E tests for critical flows.                                 |
| **32** | Performance tuning; database query optimization; benchmark under load (e.g., 100 concurrent requests). |
| **33** | Security hardening; penetration testing (basic); dependency audit and fixes.                           |
| **34** | Documentation polish; create video walkthroughs or interactive API guide.                              |
| **35** | Scaling prep: Redis setup docs, load balancer config, horizontal scaling playbook.                     |

---

## Parallel Work (Can Do Anytime)

These don't depend on specific days; start whenever ready:

- **Client Integration:** Have Flutter team use Swagger docs; run integration with staging backend.
- **DevOps:** Set up monitoring (e.g., Uptime Robot for health checks; simple dashboards).
- **Knowledge Transfer:** Document code patterns, architecture decisions in wiki or Notion.
- **Feedback Loop:** Collect feedback from testers; prioritize fixes.

---

## Success Criteria for Days 16–30

By the end of this phase, the backend should have:

- ✅ >85% test coverage for critical paths (auth, payment, subscription)
- ✅ Complete API documentation (Swagger + README)
- ✅ Explicit 404 and error handlers with standardized responses
- ✅ Optimized database queries and indexes
- ✅ Granular rate limiting
- ✅ Production logging and error tracking (Sentry optional)
- ✅ Advanced features (inventory, menus, zones, staff) fully functional
- ✅ CI/CD pipeline active
- ✅ Deployment checklist signed off
- ✅ Ready for production deployment

---

## Checklist: One-page view

| Day   | Focus                            | Status |
| ----- | -------------------------------- | ------ |
| 16    | Test framework setup, auth tests | ☐      |
| 17    | Customer & subscription tests    | ☐      |
| 18    | Payment & invoice tests          | ☐      |
| 19    | Delivery & real-time tests       | ☐      |
| 20    | Integration tests & CI/CD        | ☐      |
| 21    | API docs & Swagger               | ☐      |
| 22    | README & deployment guide        | ☐      |
| 23    | 404 handler, error hardening     | ☐      |
| 24    | Performance & indexing           | ☐      |
| 25    | Rate limiting refinement         | ☐      |
| 26    | Logging & error tracking         | ☐      |
| 27    | Delivery staff & zones           | ☐      |
| 28    | Raw materials & inventory        | ☐      |
| 29    | Daily menu & reports             | ☐      |
| 30    | Production checklist & polish    | ☐      |
| 31–35 | Buffer & optional tasks          | ☐      |

---

## Key Milestones

1. **End of Day 20:** Full integration tests pass; CI/CD active ✅ → **Ready for staging**
2. **End of Day 23:** All errors standardized; 404 working; security audit passed ✅ → **Hardening complete**
3. **End of Day 26:** Logging, monitoring, error tracking in place ✅ → **Production observability ready**
4. **End of Day 30:** Deployment checklist complete; ready to ship ✅ → **Production deployment**

---

## Notes

- **Testing:** Aim for >85% coverage on critical paths (auth, payment, subscription); >70% overall.
- **Docs:** Swagger UI should be your source of truth; keep it updated with code changes.
- **Performance:** Most endpoints should respond in <100ms in dev; <500ms in prod (with network).
- **Security:** Assume hostile users; validate all inputs; log nothing sensitive.
- **Deployment:** Use free tier initially (MongoDB M0, Cloudinary free, Render/Railway free). Upgrade only when needed.

---

## Conclusion

This 15-day plan takes the feature-complete backend and hardens it for production with comprehensive testing, documentation, performance optimization, and advanced feature polish. By the end, you'll have a rock-solid, well-documented, scalable backend ready for public deployment and user adoption.

**Phase Status:** From "feature-complete" → **"production-ready"** 🚀
