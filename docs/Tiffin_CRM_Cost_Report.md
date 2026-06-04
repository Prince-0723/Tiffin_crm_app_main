# Tiffin CRM — Third-Party Cost Report

**Purpose:** Summarize **recurring and one-time** costs for **external (3rd party) services** that this codebase integrates with via environment variables (see `server/.env.example`, `client/.env.example`, and root `.env.example`).

**Report period:** _[e.g. Monthly — April 2026]_  
**Prepared for:** _[Client / business name]_  
**Date:** _[YYYY-MM-DD]_

---

## 1. How to read this

| Column | Meaning |
|--------|--------|
| **Service** | What it does in the product. |
| **Provider** | The vendor. |
| **Billing** | How you are typically charged (check current pricing on the provider’s site). |
| **Paid by** | **Client** = billed to the restaurant / business. **Project / vendor** = absorbed in your quote or passed through as agreed. |

> Replace `_TBD_` with amounts from your invoices or provider dashboards.

---

## 2. Summary (fill in)

| | Amount |
|---|--------|
| **Estimated monthly 3rd party total** | _₹_____ / month_ |
| **Estimated one-time setup (year 1)** | _₹_____ (if any)_ |
| **Notes** | _[e.g. SMS scales with OTP volume; Razorpay is % of GMV]_ |

---

## 3. Services used (from project env templates)

These are the **only** third-party products named in the project’s `.env.example` files. JWT secrets, `PORT`, `CORS_ORIGIN`, etc. are **not** listed here (they are not vendor subscriptions).

### 3.1 Database

| Service | Provider | Env vars | Used for | Billing (typical) | Est. cost | Paid by |
|---------|----------|----------|----------|-------------------|-----------|---------|
| MongoDB | [MongoDB Atlas](https://www.mongodb.com/atlas) (or any MongoDB-compatible host in `MONGODB_URL`) | `MONGODB_URL` | App data | Free tier / per cluster & storage | _TBD_ | _Client / Vendor_ |

### 3.2 Push notifications

| Service | Provider | Env vars | Used for | Billing (typical) | Est. cost | Paid by |
|---------|----------|----------|----------|-------------------|-----------|---------|
| Firebase Admin (FCM) | Google Firebase | `FIREBASE_PROJECT_ID`, `FIREBASE_PRIVATE_KEY`, `FIREBASE_CLIENT_EMAIL` | Server-side FCM; works with OneSignal setup | Spark / pay-as-you-go | _TBD_ | _Client / Vendor_ |
| OneSignal | OneSignal | `ONESIGNAL_APP_ID`, `ONESIGNAL_REST_API_KEY` (server); client also uses `ONESIGNAL_APP_ID` / `onesignal.env` | Push to mobile | Free tier / MAU-based | _TBD_ | _Client / Vendor_ |

**Client:** Root `.env.example` includes `FCM_SENDER_ID` (Firebase Cloud Messaging sender ID for the Flutter app).

### 3.3 SMS, OTP, and messaging

| Service | Provider | Env vars | Used for | Billing (typical) | Est. cost | Paid by |
|---------|----------|----------|----------|-------------------|-----------|---------|
| MSG91 | MSG91 | `MSG91_AUTH_KEY`, `MSG91_TEMPLATE_ID` | SMS / OTP templates | Per SMS | _TBD_ | _Client / Vendor_ |
| Twilio | Twilio | `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `TWILIO_SERVICE_SID`; optional `TWILIO_PHONE_NUMBER`, `TWILIO_WHATSAPP_NUMBER` | OTP via Verify; optional SMS/WhatsApp | Usage + Verify | _TBD_ | _Client / Vendor_ |

### 3.4 Email

| Service | Provider | Env vars | Used for | Billing (typical) | Est. cost | Paid by |
|---------|----------|----------|----------|-------------------|-----------|---------|
| SendGrid | Twilio SendGrid | `SENDGRID_API_KEY`, `FROM_EMAIL` | Transactional email | Free tier / per email | _TBD_ | _Client / Vendor_ |

### 3.5 Payments

| Service | Provider | Env vars | Used for | Billing (typical) | Est. cost | Paid by |
|---------|----------|----------|----------|-------------------|-----------|---------|
| Razorpay | Razorpay | `RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET`, `RAZORPAY_WEBHOOK_SECRET` (server); client `.env` also has key id/secret for checkout | Online payments & webhooks | % + fixed per transaction | _TBD_ | _Usually from settlements; document %_ |

### 3.6 Maps

| Service | Provider | Env vars | Used for | Billing (typical) | Est. cost | Paid by |
|---------|----------|----------|----------|-------------------|-----------|---------|
| Google Maps Platform | Google Cloud | `GOOGLE_MAPS_API_KEY` (root `.env.example` / `client/.env`) | Maps / routing in the app | Per request + monthly credit | _TBD_ | _Client / Vendor_ |

### 3.7 File storage (configured in backend template)

| Service | Provider | Env vars | Used for | Billing (typical) | Est. cost | Paid by |
|---------|----------|----------|----------|-------------------|-----------|---------|
| Cloudinary | Cloudinary | `CLOUDINARY_NAME`, `CLOUDINARY_API_KEY`, `CLOUDINARY_API_SECRET` | Intended for media / invoice storage per project docs | Free tier / usage | _TBD_ | _Client / Vendor_ |

### 3.8 Error monitoring (optional)

| Service | Provider | Env vars | Used for | Billing (typical) | Est. cost | Paid by |
|---------|----------|----------|----------|-------------------|-----------|---------|
| Sentry | Sentry | `SENTRY_DSN` | Error tracking (optional) | Free tier / events | _TBD_ | _Client / Vendor_ |

---

## 4. Not covered by `.env.example` (document separately if needed)

The env templates do **not** define **app/API hosting**, **domains**, or **app store** fees. If the client pays those, track them outside this table or add a short appendix.

---

## 5. What the client typically pays vs what you include

**Option A — Client pays providers directly**  
- Client creates accounts for: _[e.g. Razorpay, MongoDB Atlas, Firebase, OneSignal, MSG91/Twilio, SendGrid, Google Cloud (Maps), Cloudinary]_ as applicable.

**Option B — You resell / pass-through**  
- You pay providers; client sees line items on your invoice: _[describe]_.

**Option C — Hybrid**  
- _[Describe]_.

---

## 6. Assumptions & exclusions

- Costs depend on **traffic**, **OTP/SMS volume**, and **payment volume**.  
- **Excluded:** internal labour, custom development not tied to these vendors.  
- **Taxes / FX:** As applicable.

---

## 7. Sign-off

| Role | Name | Date | Signature |
|------|------|------|-----------|
| Client | | | |
| Vendor / implementer | | | |

---

## 8. Version history

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | _YYYY-MM-DD_ | Initial template |
| 1.1 | 2026-04-02 | Scoped to services named in project `.env.example` files |
