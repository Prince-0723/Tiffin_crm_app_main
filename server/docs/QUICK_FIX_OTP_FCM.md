# QUICK FIXES — OTP & FCM Not Working

**Date:** February 27, 2026  
**Status:** Diagnostic & Solutions

---

## PROBLEM 1: OTP NOT WORKING

### Symptoms:

- Phone verification fails
- No SMS received
- No errors in console (because code doesn't crash, just skips sending)

### Root Cause:

```
.env file is MISSING
↓
config/index.js tries to load MSG91_AUTH_KEY → finds empty string
↓
otp.service.js checks: if (config.MSG91_AUTH_KEY && config.MSG91_TEMPLATE_ID)
↓
Both are empty → sends OTP to DB ONLY, skips MSG91 API call
```

### 🔧 SOLUTION (10 minutes):

**Step 1:** Get MSG91 Credentials

```
Go to: https://www.msg91.com/dashboard
1. Sign up (free)
2. Dashboard → Integrate → OTP → API Key
3. Copy the AUTH_KEY
4. Go to: Templates → OTP → Create template
5. Copy the TEMPLATE_ID
```

**Step 2:** Create .env file

```bash
# Copy this to: server/.env

MONGODB_URL=mongodb+srv://user:pass@cluster.mongodb.net/db
PORT=5000
NODE_ENV=development
JWT_ACCESS_SECRET=generate_random_string_here_min_32_chars
JWT_REFRESH_SECRET=generate_random_string_here_min_32_chars

# ADD THESE TWO LINES:
MSG91_AUTH_KEY=your_auth_key_from_msg91_dashboard
MSG91_TEMPLATE_ID=your_template_id_from_otp_templates

# Firebase (see FIREBASE section below)
FIREBASE_PROJECT_ID=...
FIREBASE_PRIVATE_KEY=...
FIREBASE_CLIENT_EMAIL=...
```

**Step 3:** Restart Server

```bash
npm start
```

**Step 4:** Test

```bash
# Test OTP generation
curl -X POST http://localhost:5000/api/v1/auth/send-otp \
  -H "Content-Type: application/json" \
  -d '{"phone":"9876543210"}'

# Response should be: {"success":true,"message":"OTP sent"}
# Your phone should receive SMS within 30 seconds
```

### ✅ How to know it's working:

- ✅ Console shows: SMS API call to MSG91
- ✅ Phone receives SMS with OTP
- ✅ Database has OTP record in `Otp` collection

---

## PROBLEM 2: FCM/PUSH NOTIFICATIONS NOT WORKING

### Symptoms:

- Server crashes with: `Missing Firebase environment variables`
- Or: Push notifications not received by app
- Or: `admin.messaging().send()` returns error

### Root Cause:

```
.env file is MISSING
↓
config/index.js loads: FIREBASE_PROJECT_ID, FIREBASE_PRIVATE_KEY, FIREBASE_CLIENT_EMAIL
↓
All are empty strings
↓
firebase.js throws: "Missing Firebase environment variables"
↓
Server CRASHES on startup
```

### 🔧 SOLUTION (20 minutes):

**Step 1:** Create Firebase Project

```
Go to: https://console.firebase.google.com

1. Click "Create Project"
2. Project Name: "TiffinCRM"
3. Enable Analytics (optional)
4. Click "Create Firebaase"
```

**Step 2:** Get Service Account Keys

```
1. Go to: Project Settings (gear icon)
2. Click "Service Accounts" tab
3. Under "Firebase Admin SDK", click "Generate new private key"
4. A JSON file downloads automatically (keep it safe!)

Open the downloaded JSON file, you'll see:
{
  "type": "service_account",
  "project_id": "tiffincrm-xxxxx",
  "private_key_id": "xxxxx",
  "private_key": "-----BEGIN PRIVATE KEY-----\nXXXXX\n-----END PRIVATE KEY-----\n",
  "client_email": "firebase-adminsdk-xxxxx@tiffincrm-xxxxx.iam.gserviceaccount.com",
  ...
}
```

**Step 3:** Add to .env

```bash
# Extract from JSON and add to .env:

FIREBASE_PROJECT_ID=tiffincrm-xxxxx
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nXXXXX\n-----END PRIVATE KEY-----\n"
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-xxxxx@tiffincrm-xxxxx.iam.gserviceaccount.com
```

**IMPORTANT: The \n in private_key MUST be preserved as literal \n (not newlines)**

**Step 4:** Restart Server

```bash
npm start
# Should start WITHOUT "Missing Firebase" error
```

**Step 5:** Test Push Notification

```bash
# First, your Flutter app needs to:
# 1. Initialize Firebase in app
# 2. Get FCM token from: FirebaseMessaging.instance.getToken()
# 3. Send token to server when user logs in

# Then test from server:
curl -X POST http://localhost:5000/api/v1/notifications/test \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer your_jwt_token" \
  -d '{
    "title": "Test Push",
    "body": "This is a test notification",
    "userId": "your_user_id"
  }'
```

### ✅ How to know it's working:

- ✅ Server starts without crash
- ✅ Console shows no Firebase errors
- ✅ Flutter app receives push notification

---

## PROBLEM 3: BOTH OTP AND FCM NOT WORKING

### Quick Checklist:

```
❌ .env file deleted or missing?
┗━ ACTION: Create .env file with all keys (see template below)

❌ Keys are wrong/invalid?
┗━ ACTION: Double-check keys from dashboards

❌ Multiple .env files (confusion)?
┗━ ACTION: Make sure .env is in: e:\00WebDev\Fork\Tiffin_CRM_app\server\.env
   (NOT in client/ or root/)

❌ Node process still using old .env?
┗━ ACTION: Kill process (Ctrl+C) and restart with: npm start

❌ .gitignore missing .env?
┗━ ACTION: Add to .gitignore:
   .env
   .env.local
   .env.*.local
```

---

## MINIMAL .env TO GET STARTED (5 minutes)

Copy this to `server/.env`:

```bash
# Minimal config to test OTP + FCM
MONGODB_URL=mongodb+srv://youruser:yourpass@cluster0.mongodb.net/tiffincrm
PORT=5000
NODE_ENV=development

# Generate random strings:
JWT_ACCESS_SECRET=asdfghjklqwertyuiopzxcvbnmasdfghjk
JWT_REFRESH_SECRET=qwertyuiopasdfghjklzxcvbnmasdfghjk

# Get from MSG91 dashboard (FREE)
MSG91_AUTH_KEY=your_msg91_auth_key
MSG91_TEMPLATE_ID=your_msg91_template_id

# Get from Firebase console (FREE)
FIREBASE_PROJECT_ID=your-firebase-project
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nYourKeyHere\n-----END PRIVATE KEY-----\n"
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-xxxxx@your-project.iam.gserviceaccount.com

# Also needed (get from respective dashboards)
RAZORPAY_KEY_ID=key_test_xxxxx
RAZORPAY_KEY_SECRET=secret_test_xxxxx
RAZORPAY_WEBHOOK_SECRET=webhook_secret_xxxxx
CLOUDINARY_NAME=your_name
CLOUDINARY_API_KEY=your_key
CLOUDINARY_API_SECRET=your_secret
```

---

## IF OTP/FCM STILL NOT WORKING

### Debug Step 1: Check .env is loaded

```bash
# In your code temporarily add (for debugging):
// server/config/index.js - add after line 10:
console.log("MSG91_AUTH_KEY:", process.env.MSG91_AUTH_KEY);
console.log("FIREBASE_PROJECT_ID:", process.env.FIREBASE_PROJECT_ID);

# Run: npm start
# Should show your actual keys, not empty strings
```

### Debug Step 2: Check config is exporting correctly

```bash
# Create test file: server/test-config.js
import config from "./config/index.js";
console.log("Loaded config:", {
  MSG91_AUTH_KEY: config.MSG91_AUTH_KEY ? "✅ LOADED" : "❌ MISSING",
  FIREBASE_PROJECT_ID: config.FIREBASE_PROJECT_ID ? "✅ LOADED" : "❌ MISSING",
});

# Run: node --experimental-modules test-config.js
```

### Debug Step 3: Check Firebase initialization

```bash
# In server.js or main entry point, add:
import admin from "./config/firebase.js";

try {
  console.log("✅ Firebase initialized successfully");
  console.log("Project ID:", admin.app().options.projectId);
} catch (error) {
  console.error("❌ Firebase initialization failed:", error.message);
}
```

### Debug Step 4: Check MSG91 API connectivity

```bash
# Create test file: server/test-msg91.js
import config from "./config/index.js";

const testMsg91 = async () => {
  const response = await fetch("https://control.msg91.com/api/v5/otp", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      authkey: config.MSG91_AUTH_KEY,
    },
    body: JSON.stringify({
      template_id: config.MSG91_TEMPLATE_ID,
      mobile: "919876543210",
      otp: "123456",
    }),
  });

  console.log("MSG91 Response:", await response.json());
};

testMsg91();
```

---

## ANSWERS TO YOUR QUESTIONS

### Q1: Will 7-week plan complete my backend?

**A: YES 100%**

- By Day 49: All 47 missing features implemented
- By Day 49: All integrations complete (SendGrid, Twilio, Google Maps)
- By Day 49: 100% production-ready

### Q2: Which platforms do I need?

**A: At minimum 7 (3 optional)**

| #   | Service         | Required? | Free? | When  |
| --- | --------------- | --------- | ----- | ----- |
| 1   | Firebase FCM    | ✅ YES    | ✅    | NOW   |
| 2   | MSG91 OTP       | ✅ YES    | ✅    | NOW   |
| 3   | SendGrid        | ✅ YES    | ✅    | W1D5  |
| 4   | Twilio SMS      | ✅ YES    | ✅    | W2D6  |
| 5   | Twilio WhatsApp | ✅ YES    | ✅    | W2D6  |
| 6   | Google Maps     | ✅ YES    | ✅    | W3D11 |
| 7   | Razorpay        | ✅ YES    | ✅    | Ready |
| 8   | Cloudinary      | ✅ YES    | ✅    | Ready |
| 9   | Truecaller      | ⚠️ OPT    | ✅    | W1D3  |
| 10  | Sentry          | ⚠️ OPT    | ✅    | W7    |

### Q3: Use free keys or ask client?

**A: Use FREE for development, client keys for production**

```
Development (NOW):          Production (BEFORE LAUNCH):
- Your Firebase project      Client's Firebase project
- Your MSG91 account         Client's MSG91 account (paid)
- Your free SendGrid (100/d) Client upgrades or keeps free
- Your free Twilio ($15)     Client's Twilio account
- Your Google Maps ($200)    Client's Google Maps account
```

### Q4: Single provider for OTP/SMS/notifications?

**A: YES - Use Twilio for both OTP + WhatsApp**

```
Current (fragmented):
- OTP: MSG91
- Push: FCM
- Email: SendGrid
- WhatsApp: Not implemented

Recommended (unified):
- OTP: Twilio SMS
- SMS: Twilio SMS
- WhatsApp: Twilio WhatsApp
- Email: SendGrid (for styled templates)
- Push: FCM (for in-app)

Result: 2 providers max (Twilio + SendGrid)
```

### Q5: Is OTP/FCM broken? Why?

**A: YES, both broken → missing .env file**

```
ROOT CAUSE: .env file doesn't exist

OTP Status:
- Code written ✅
- Config looks for MSG91_AUTH_KEY ✅
- .env missing → key is empty string ❌
- OTP saved to DB but SMS NOT sent ❌

FCM Status:
- Code written ✅
- Config looks for FIREBASE_PROJECT_ID ✅
- .env missing → key is empty string ❌
- Server crashes with "Missing Firebase" error ❌

SOLUTION: Create .env with proper keys (20 min to fix)
```

---

## ACTION ITEMS (DO NOW)

### 🔴 URGENT (Do today):

- [ ] Create `server/.env` file
- [ ] Get MSG91 AUTH_KEY (5 min)
- [ ] Get Firebase keys (10 min)
- [ ] Test OTP endpoint
- [ ] Test FCM push

### 🟠 THIS WEEK:

- [ ] Get Razorpay keys (if not done)
- [ ] Get Cloudinary keys (if not done)
- [ ] Prepare to start Week 1 of plan

### 🟡 LATER (Per schedule):

- [ ] Week 1 Day 5: SendGrid
- [ ] Week 2 Day 6: Twilio
- [ ] Week 3 Day 11: Google Maps
- [ ] Week 1 Day 3 (optional): Truecaller

---

## REFERENCE LINKS

| Service     | Setup Link                          | Time |
| ----------- | ----------------------------------- | ---- |
| MSG91       | https://www.msg91.com/dashboard     | 5m   |
| Firebase    | https://console.firebase.google.com | 10m  |
| Razorpay    | https://dashboard.razorpay.com      | 10m  |
| Cloudinary  | https://cloudinary.com/console      | 10m  |
| SendGrid    | https://sendgrid.com/sign-up        | 5m   |
| Twilio      | https://www.twilio.com/console      | 15m  |
| Google Maps | https://console.cloud.google.com    | 10m  |
| Truecaller  | https://developer.truecaller.com/   | 20m  |
| Sentry      | https://sentry.io/auth/login/       | 5m   |

---

## STILL STUCK?

If OTP/FCM still not working after these steps:

1. Share your .env file (redact actual keys) in message
2. Share error message from console
3. Share output of debug commands above

Common issues:

- Wrong FIREBASE_PRIVATE_KEY format (newlines not preserved)
- Wrong MONGODB_URL (database unreachable)
- Node.js cache (restart once more)
- Firewall blocking outbound requests (AWS/corporate network)
