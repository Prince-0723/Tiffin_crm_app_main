# TiffinCRM Backend — Platforms, APIs & Keys Required

**Last Updated:** February 27, 2026  
**Status:** Current requirement analysis

---

## CRITICAL ANSWER: Will 7-Week Plan Complete Your Backend?

### ✅ YES - But with conditions:

**After completing the 7-week REALISTIC_7_WEEK_PLAN:**

- ✅ 100% feature completion (all 47 missing features implemented)
- ✅ 100% endpoint coverage (all CRUD operations)
- ✅ 100% integration coverage (all external APIs)
- ✅ 100% production-ready status
- ✅ Full testing & documentation

**However, you MUST:**

1. ✅ Acquire API keys from all required platforms (see below)
2. ✅ Set up .env file with all keys
3. ✅ Complete each week sequentially (dependencies build on each other)
4. ✅ Do NOT skip any feature — they're all critical

**If you skip features:**

- ❌ GPS tracking without geofencing = unusable for delivery validation
- ❌ Notifications without WhatsApp = incomplete customer communication
- ❌ No email = broken password reset flow
- ❌ Missing CRUD = incomplete staff/zone management

---

## PLATFORMS & SERVICES REQUIRED

### 🎯 Current Status

Your current setup has:

- ✅ **MongoDB** — Configured (working)
- ✅ **Firebase Admin SDK** — Installed (but keys missing → **FCM NOT WORKING**)
- ✅ **MSG91** — Installed (keys missing → **OTP NOT WORKING**)
- ✅ **Razorpay** — Installed (ready when keys added)
- ✅ **Cloudinary** — Installed (ready when keys added)

Missing entirely:

- ❌ **SendGrid** — Email service (NOT INSTALLED)
- ❌ **Twilio** — WhatsApp API (NOT INSTALLED)
- ❌ **Google Maps API** — Route optimization (NOT INSTALLED)
- ❌ **Truecaller** — Alternative auth (NOT INSTALLED)
- ❌ **Sentry** — Error monitoring (optional but recommended)

---

## PLATFORM BREAKDOWN WITH PRICING

### TIER 1: REQUIRED FOR MINIMUM VIABILITY

#### 1️⃣ **Firebase Cloud Messaging (FCM)**

**Purpose:** Push notifications to mobile app  
**Current State:** ❌ NOT WORKING (missing keys)  
**Setup Time:** 15 minutes  
**Cost:** FREE (unlimited messages)  
**Why broken:** You configured code, but `FIREBASE_PROJECT_ID`, `FIREBASE_PRIVATE_KEY`, `FIREBASE_CLIENT_EMAIL` are empty in .env

**Setup:**

```
1. Go to https://console.firebase.google.com
2. Create new project (or use existing: "TiffinCRM")
3. Enable Cloud Messaging
4. Click "Generate new private key" → Download JSON
5. Extract from JSON:
   - projectId → FIREBASE_PROJECT_ID
   - privateKey → FIREBASE_PRIVATE_KEY (keep \n as is)
   - clientEmail → FIREBASE_CLIENT_EMAIL
6. Add to .env file
```

**Keys needed:**

```
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-xxxxx@your-project.iam.gserviceaccount.com
```

---

#### 2️⃣ **MSG91 SMS (for OTP)**

**Purpose:** Send OTP via SMS (currently via HTTP API)  
**Current State:** ❌ NOT WORKING (missing keys)  
**Setup Time:** 10 minutes  
**Cost:** ₹0.50-2 per SMS (~100 OTPs/month = ~₹100/month)  
**Why broken:** `MSG91_AUTH_KEY` and `MSG91_TEMPLATE_ID` missing in .env

**Setup:**

```
1. Register at https://www.msg91.com (free account)
2. Get AUTH_KEY from dashboard
3. Create OTP template → Get TEMPLATE_ID
4. Add to .env:
   MSG91_AUTH_KEY=your-auth-key
   MSG91_TEMPLATE_ID=your-template-id
```

**Keys needed:**

```
MSG91_AUTH_KEY=xxxxxxxxxxxxx
MSG91_TEMPLATE_ID=123456789
```

**NOTE:** In development, OTP is printed to console even without keys, but production needs this working.

---

#### 3️⃣ **MongoDB Atlas**

**Purpose:** Database (already working)  
**Current State:** ✅ WORKING  
**Setup Time:** Already done  
**Cost:** FREE M0 (512 MB)

---

#### 4️⃣ **Razorpay**

**Purpose:** Payment processing  
**Current State:** ⚠️ Installed but not tested  
**Setup Time:** 20 minutes  
**Cost:** FREE (2% fee on transactions, but free during testing with test keys)

**Setup:**

```
1. Register at https://razorpay.com
2. Get API keys from dashboard (Test + Live modes)
3. Add to .env:
   RAZORPAY_KEY_ID=key_xxxxx
   RAZORPAY_KEY_SECRET=secret_xxxxx
   RAZORPAY_WEBHOOK_SECRET=webhook_xxxxx (get from webhooks section)
```

**Keys needed:**

```
RAZORPAY_KEY_ID=key_test_xxxxx
RAZORPAY_KEY_SECRET=secret_test_xxxxx
RAZORPAY_WEBHOOK_SECRET=webhook_secret_xxxxx
```

---

### TIER 2: REQUIRED FOR WEEK 2 (Notifications)

#### 5️⃣ **SendGrid (Email)**

**Purpose:** Send emails for password reset, notifications, receipts  
**Setup Time:** 30 minutes  
**Cost:** FREE tier = 100 emails/day  
**Installation:** `npm install @sendgrid/mail`

**Setup:**

```
1. Register at https://sendgrid.com (free account)
2. Create API key with "Mail Send" permission
3. Create sender (verified email)
4. Add to .env:
   SENDGRID_API_KEY=SG.xxxxx
   FROM_EMAIL=noreply@tiffincrm.com (verified sender email)
```

**Keys needed:**

```
SENDGRID_API_KEY=SG.xxxxxxxxxxxxxxxxxxxxxxxx
FROM_EMAIL=your-verified-email@domain.com
```

**When to add:** Day 5 of Week 1

---

#### 6️⃣ **Twilio (WhatsApp)**

**Purpose:** Send WhatsApp notifications  
**Setup Time:** 45 minutes  
**Cost:** FREE trial balance ($15 USD) + pay-as-you-go after  
**Installation:** `npm install twilio`

**Setup:**

```
1. Register at https://www.twilio.com (free account with $15 trial)
2. Create WhatsApp Sandbox (for testing)
3. Get:
   - Account SID
   - Auth Token
   - WhatsApp Number (Twilio sandbox number)
4. Add to .env:
   TWILIO_ACCOUNT_SID=ACxxxxxx
   TWILIO_AUTH_TOKEN=your_auth_token
   TWILIO_WHATSAPP_NUMBER=+14155552671 (sandbox, will be different for production)
```

**Keys needed:**

```
TWILIO_ACCOUNT_SID=ACxxxxxxxxxxxxxxxx
TWILIO_AUTH_TOKEN=xxxxxxxxxxxxxxxx
TWILIO_WHATSAPP_NUMBER=+14155552671
```

**When to add:** Days 6-7 of Week 2

---

### TIER 3: REQUIRED FOR WEEK 3 (Geofencing)

#### 7️⃣ **Google Maps API**

**Purpose:** Route optimization, ETA calculation, geofencing  
**Setup Time:** 30 minutes  
**Cost:** FREE tier with $200 monthly credit (covers ~10,000 requests)  
**Installation:** Already available (no package needed, HTTP API)

**Setup:**

```
1. Go to https://console.cloud.google.com
2. Create new project
3. Enable APIs:
   - Maps JavaScript API
   - Directions API
   - Distance Matrix API
   - Geocoding API
4. Create API key (unrestricted for dev, restrict in prod)
5. Add to .env:
   GOOGLE_MAPS_API_KEY=AIzaSy...
```

**Keys needed:**

```
GOOGLE_MAPS_API_KEY=AIzaSyxxxxxxxxxxxxxxxx
```

**When to add:** Days 11-13 of Week 3

---

### TIER 4: OPTIONAL BUT RECOMMENDED

#### 8️⃣ **Truecaller (Alternative Auth)**

**Purpose:** Quick login without OTP  
**Setup Time:** 20 minutes  
**Cost:** FREE API  
**Installation:** `npm install truecaller` (or use SDK)

**Setup:**

```
1. Register business account at https://developer.truecaller.com
2. Apply for API access
3. Get API key once approved
4. Add to .env:
   TRUECALLER_API_KEY=xxxxx
```

**Keys needed:**

```
TRUECALLER_API_KEY=xxxxxxxxxxxxx
```

**When to add:** Days 3-4 of Week 1 (optional)

---

#### 9️⃣ **Sentry (Error Monitoring)**

**Purpose:** Track errors in production  
**Setup Time:** 15 minutes  
**Cost:** FREE tier (1GB events/month)  
**Installation:** `npm install @sentry/node`

**Setup:**

```
1. Register at https://sentry.io
2. Create new project (Node.js)
3. Get DSN (Data Source Name)
4. Add to .env:
   SENTRY_DSN=https://xxxxx@xxxxx.ingest.sentry.io/xxxxx
```

**Keys needed:**

```
SENTRY_DSN=https://xxxxx@xxxxx.ingest.sentry.io/123456
```

**When to add:** Week 7 (optional, for production monitoring)

---

## WHAT YOU NEED TO DO NOW

### ✅ STEP 1: Create .env File

Create file: `server/.env`

```bash
# Database
MONGODB_URL=mongodb+srv://username:password@cluster.mongodb.net/tiffincrm

# Port
PORT=5000
NODE_ENV=development

# JWT Secrets (generate random strings)
JWT_ACCESS_SECRET=your_random_access_secret_here_min_32_chars
JWT_REFRESH_SECRET=your_random_refresh_secret_here_min_32_chars

# Firebase (FCM) — GET FROM FIREBASE CONSOLE
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_PRIVATE_KEY=-----BEGIN PRIVATE KEY-----\nxxxxx\n-----END PRIVATE KEY-----\n
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-xxxxx@your-project.iam.gserviceaccount.com

# MSG91 (OTP via SMS) — GET FROM MSG91 DASHBOARD
MSG91_AUTH_KEY=your_msg91_auth_key
MSG91_TEMPLATE_ID=your_msg91_template_id

# Razorpay (Payments) — GET FROM RAZORPAY DASHBOARD
RAZORPAY_KEY_ID=key_test_xxxxx
RAZORPAY_KEY_SECRET=secret_test_xxxxx
RAZORPAY_WEBHOOK_SECRET=webhook_secret_xxxxx

# Cloudinary (File Storage) — GET FROM CLOUDINARY DASHBOARD
CLOUDINARY_NAME=your_cloudinary_name
CLOUDINARY_API_KEY=your_api_key
CLOUDINARY_API_SECRET=your_api_secret

# SendGrid (Email) — ADD DURING WEEK 1 DAY 5
SENDGRID_API_KEY=SG.xxxxxxxxxxxxxxxxxxxxxxxx
FROM_EMAIL=noreply@tiffincrm.com

# Twilio (WhatsApp) — ADD DURING WEEK 2 DAY 6
TWILIO_ACCOUNT_SID=ACxxxxxxxxxxxxxxxx
TWILIO_AUTH_TOKEN=xxxxxxxxxxxxxxxx
TWILIO_WHATSAPP_NUMBER=+14155552671

# Google Maps — ADD DURING WEEK 3 DAY 11
GOOGLE_MAPS_API_KEY=AIzaSyxxxxxxxxxxxxxxxx

# Truecaller (Optional) — ADD DURING WEEK 1 DAY 3
TRUECALLER_API_KEY=xxxxxxxxxxxxx

# Sentry (Optional) — ADD DURING WEEK 7
SENTRY_DSN=https://xxxxx@xxxxx.ingest.sentry.io/123456

# Frontend URLs
FRONTEND_URL=http://localhost:3000
```

---

### ✅ STEP 2: Which Keys to Use (FREE vs CLIENT KEYS)?

**RECOMMENDATION: Use FREE Tier Keys for Development**

| Service     | Dev (Free Tier)          | Production (Client Keys)             |
| ----------- | ------------------------ | ------------------------------------ |
| Firebase    | Your Google account      | Your Google account                  |
| MSG91       | Free account (test mode) | Client pays ₹100-200/month           |
| SendGrid    | Free 100/day             | Client upgrades tier (or keeps free) |
| Twilio      | Free $15 trial           | Client's account                     |
| Google Maps | Free $200/month          | Client's account                     |
| Razorpay    | Test keys                | Live keys (client account)           |

**Implementation Strategy:**

1. **NOW (Phase 1 - Development):**
   - You: Set up Firebase with YOUR Google account (free)
   - You: Create MSG91 free account (free)
   - You: Create SendGrid free account (100 emails/day) — sufficient for testing
   - You: Create Twilio free account ($15 trial)
   - You: Create Google Maps account (free tier with $200 credit)

   **Why?** So you can test everything without blocking on client

2. **BEFORE PRODUCTION (Phase 2 - Staging):**
   - CLIENT: Creates their own Firebase project (if different country/branding)
   - CLIENT: Provides MSG91 API key & budget
   - CLIENT: Provides SendGrid/Twilio/Google Maps API keys
   - CLIENT: Provides Razorpay LIVE keys
   - YOU: Update .env with client keys, test thoroughly
   - YOU: Deploy to staging environment

3. **AT GO-LIVE (Phase 3 - Production):**
   - All APIs pointing to client's accounts
   - Monitoring & error tracking enabled (Sentry)
   - Automatic backups configured
   - Support runbooks documented

---

## SOLUTION: Single Provider for OTP/SMS/Notifications

### Current Fragmented Approach:

- **OTP:** MSG91 (SMS-based)
- **Notifications:** FCM (push), Email (TBD), WhatsApp (TBD)
- **Issue:** 3-4 different providers, complex logic

### ✅ SIMPLIFIED: Use Twilio for Everything

**Twilio supports:**

- ✅ SMS (for OTP)
- ✅ WhatsApp (for rich notifications)
- ✅ Email (via SendGrid integration)
- ✅ Voice (future feature)

**Benefits:**

- Single API key & authentication
- Unified webhook handling
- Easier logging & debugging
- Consistent rate limiting

**Architecture Switch:**

```
Current:
OTP → MSG91
Notifications → FCM + (Email/WhatsApp - not implemented)

Proposed:
OTP → Twilio SMS
Notifications → Twilio WhatsApp
                + SendGrid Email (for styled templates)
                + FCM Push (for app-only users)

Result: 2 providers max (Twilio + SendGrid)
```

**Implementation Plan:**

```javascript
// services/twilio-otp.service.js (replaces msg91-otp)
import twilio from "twilio";

export const sendOtpViaTwilio = async (phone, otp) => {
  const client = twilio(
    process.env.TWILIO_ACCOUNT_SID,
    process.env.TWILIO_AUTH_TOKEN
  );

  return await client.messages.create({
    body: `Your TiffinCRM OTP is: ${otp}. Valid for 10 minutes.`,
    from: process.env.TWILIO_PHONE_NUMBER,
    to: phone,
  });
};

// services/unified-notification.service.js
export const sendNotification = async ({
  userId,
  type, // 'otp', 'payment_confirmed', 'delivery_update'
  phone,
  email,
  fcmToken,
}) => {
  switch (type) {
    case "otp":
      // SMS via Twilio
      return await sendOtpViaTwilio(phone, otp);

    case "payment_confirmed":
      // WhatsApp + Email + FCM
      return await Promise.all([
        sendWhatsAppViaTwilio(phone, message),
        sendEmailViaSendGrid(email, template),
        sendFcmPush(fcmToken, title),
      ]);
  }
};
```

---

## FIX 1: Why OTP Not Working

### Current Issue:

```javascript
// server/services/otp.service.js - Line 45-60
if (config.MSG91_AUTH_KEY && config.MSG91_TEMPLATE_ID) {
  // Only sends if keys exist
  const res = await fetch("https://control.msg91.com/api/v5/otp", {
    headers: { authkey: config.MSG91_AUTH_KEY },
    body: JSON.stringify({ template_id: config.MSG91_TEMPLATE_ID, ... })
  });
}
```

**Status:** In development, OTP is **saved to DB** but **NOT sent via MSG91**  
**Reason:** .env file missing `MSG91_AUTH_KEY` and `MSG91_TEMPLATE_ID`

### Solution:

1. **Create .env file** with:

   ```
   MSG91_AUTH_KEY=your_auth_key_from_msg91_dashboard
   MSG91_TEMPLATE_ID=your_template_id
   ```

2. **Test it:**
   ```bash
   # In server directory
   npm start
   # Try POST /api/v1/auth/send-otp with valid phone
   # Should receive SMS (if MSG91 config correct)
   ```

---

## FIX 2: Why FCM Not Working

### Current Issue:

```javascript
// server/config/firebase.js - Line 10
if (!FIREBASE_PROJECT_ID || !FIREBASE_PRIVATE_KEY || !FIREBASE_CLIENT_EMAIL) {
  throw new Error("Missing Firebase environment variables");
}
```

**Status:** Server will **CRASH on startup** if Firebase keys missing  
**Current:** You don't have .env, so Firebase keys are empty strings

### Solution:

1. **Get Firebase keys:**
   - Go to https://console.firebase.google.com
   - Select/Create "TiffinCRM" project
   - Go to "Project Settings" → "Service Accounts"
   - Click "Generate new private key" → Download JSON

2. **Extract from JSON:**

   ```json
   {
     "type": "service_account",
     "project_id": "tiffincrm-xxxxx",  ← Copy this
     "private_key_id": "xxxxx",
     "private_key": "-----BEGIN PRIVATE KEY-----\nxxx\n-----END PRIVATE KEY-----\n",  ← Copy (with \n preserved)
     "client_email": "firebase-adminsdk-xxxxx@tiffincrm-xxxxx.iam.gserviceaccount.com",  ← Copy this
   }
   ```

3. **Add to .env:**

   ```
   FIREBASE_PROJECT_ID=tiffincrm-xxxxx
   FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nxxxxx\n-----END PRIVATE KEY-----\n"
   FIREBASE_CLIENT_EMAIL=firebase-adminsdk-xxxxx@tiffincrm-xxxxx.iam.gserviceaccount.com
   ```

4. **Test it:**
   ```bash
   npm start
   # Should start without "Missing Firebase" error
   ```

---

## NEXT IMMEDIATE ACTIONS

### ✅ DO THIS TODAY (30 minutes):

1. **Create `.env` file** with basic config
2. **Set up Firebase** (15 min)
   - Create Google Cloud project
   - Download service account JSON
   - Extract keys into .env
3. **Set up MSG91** (10 min)
   - Create free account
   - Get AUTH_KEY and TEMPLATE_ID
   - Add to .env
4. **Test OTP + FCM:**
   ```bash
   npm start
   curl -X POST http://localhost:5000/api/v1/auth/send-otp \
     -H "Content-Type: application/json" \
     -d '{"phone":"9876543210"}'
   ```

### ✅ DO THIS THIS WEEK (Before Week 1):

1. Setup Razorpay (test keys)
2. Setup Cloudinary
3. Start Week 1 on password management

### ✅ SCHEDULE THESE:

- **Week 1 Day 5:** Setup SendGrid
- **Week 2 Day 6:** Setup Twilio
- **Week 3 Day 11:** Setup Google Maps

---

## SUMMARY TABLE

| Provider     | Required?   | Cost       | Setup Time | Status     | Week  |
| ------------ | ----------- | ---------- | ---------- | ---------- | ----- |
| Firebase FCM | ✅ YES      | FREE       | 15 min     | ❌ BROKEN  | NOW   |
| MSG91 OTP    | ✅ YES      | ₹100/mo    | 10 min     | ❌ BROKEN  | NOW   |
| MongoDB      | ✅ YES      | FREE M0    | Done       | ✅ WORKS   | -     |
| Razorpay     | ✅ YES      | 2% fee     | 20 min     | ⚠️ READY   | NOW   |
| SendGrid     | ✅ YES      | FREE 100/d | 30 min     | ❌ MISSING | W1D5  |
| Twilio       | ✅ YES      | FREE $15   | 45 min     | ❌ MISSING | W2D6  |
| Google Maps  | ✅ YES      | FREE $200  | 30 min     | ❌ MISSING | W3D11 |
| Cloudinary   | ✅ YES      | FREE 25GB  | 20 min     | ⚠️ READY   | W1    |
| Truecaller   | ⚠️ OPTIONAL | FREE       | 20 min     | ❌ MISSING | W1D3  |
| Sentry       | ⚠️ OPTIONAL | FREE       | 15 min     | ❌ MISSING | W7    |

---

## BOTTOM LINE

✅ **Following the 7-week plan = 100% production-ready backend**  
✅ **But you MUST get all these API keys first**  
✅ **Use FREE tier keys for now (development)**  
✅ **Client provides LIVE keys before production**

**First Action:** Fix Firebase + MSG91 RIGHT NOW (30 min) so OTP/FCM work
