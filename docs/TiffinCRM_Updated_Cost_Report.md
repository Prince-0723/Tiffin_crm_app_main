# Tiffin CRM — Third-Party Platform Cost Report

**Prepared:** 02 April 2026 · **Report period:** Monthly / Annual · **Currency:** INR (Rs.)

**Important:** Costs based on official published pricing as of April 2026. USD converted at approx. **1 USD = Rs. 84**. GST at 18% may apply on some services. Prices subject to change — always verify on each platform before purchase.

---

## Google Play & Apple App Store — developer fees (at a glance)

These are **separate from** monthly cloud/SMS costs below. They are paid to **Google** and **Apple** when you register to publish apps.

| Store | What you pay (official list price) | Approx. INR (at Rs. 84/USD) | Recurring? |
|-------|-------------------------------------|----------------------------|------------|
| **Google Play (Android)** | **One-time USD $25** registration fee | **~Rs. 2,100** | No — pay once to open a developer account |
| **Apple App Store (iOS)** | **USD $99 per year** (Apple Developer Program) | **~Rs. 8,316/year** (~Rs. 693/mo if spread over 12 months) | **Yes — annual** renewal required to keep the app on the App Store |

*Apple may show a slightly different INR total at checkout (taxes, rounding, regional pricing). Google bills the one-time fee in USD.*

---

## 1. Monthly cost summary — Tiffin CRM

| Category | Service | Free? | Starter (low vol) | Growth (mid vol) | Scale (high vol) |
|----------|---------|-------|-------------------|------------------|------------------|
| Database | MongoDB Atlas | YES | Rs. 0 (M0 Free) | Rs. 840/mo (M10) | Rs. 2,100+/mo (M20/M30) |
| Push (FCM) | Firebase FCM | YES | Rs. 0 | Rs. 0 | Rs. 0 |
| OTP / SMS | Twilio Verify API | NO | Rs. 840–1,680 (100–200 OTPs) | Rs. 4,200–8,400 (500–1K OTPs) | Rs. 8,400+ (1K+ OTPs) |
| Maps | Flutter Map (OSM) | YES | Rs. 0 | Rs. 0 | Rs. 0 |
| **App distribution (Android)** | **Google Play Console** | **NO** | **One-time ~Rs. 2,100 (USD $25)** — not a monthly line item | Same | Same |
| **App distribution (iOS)** | **Apple Developer Program** | **NO** | **~Rs. 693/mo effective** (USD **$99/year** ≈ Rs. 8,316/yr) | Same annual fee | Same annual fee |
| **TOTAL (excl. one-time & annual store fees)** | | | Rs. 840–1,680/mo | Rs. 5,040–9,240/mo | Rs. 10,500+/mo |

\* Twilio Verify API: ~Rs. 8.4 per OTP (India numbers). MongoDB Atlas M10 is the primary fixed monthly cost. FCM & Flutter Map are free. **Store fees:** add **USD $25 once** (Play) + **USD $99/year** (Apple) on top of the totals above when budgeting Year 1.

---

## 2. Annual cost estimate (Year 1)

| Scenario | Monthly cost (Rs.) | Annual cost (Rs.) | Notes |
|----------|-------------------|-------------------|-------|
| Starter (launch / low vol) | Rs. 840 – 1,680 | Rs. 10,080 – 20,160 | MongoDB M10 + Twilio OTPs; FCM & Flutter Map free. **Plus Google Play one-time USD $25 (~Rs. 2,100) and Apple USD $99 (~Rs. 8,316) in Year 1.** |
| Growth (mid vol) | Rs. 5,040 – 9,240 | Rs. 60,480 – 1,10,880 | Higher Twilio OTP volume; **Apple annual fee repeats every year.** |
| Scale (high vol) | Rs. 10,500+ | Rs. 1,26,000+ | MongoDB M20/M30 + 1K+ OTPs/month; other services unchanged. |

### One-time / annual fees (store accounts — separate from monthly)

| Item | USD (list) | INR (approx. @84) | Notes |
|------|------------|-------------------|-------|
| Google Play — one-time registration | **USD $25** | **~Rs. 2,100** | Pay once; no annual renewal for the developer account fee. |
| Apple Developer Program | **USD $99 / year** | **~Rs. 8,316 / year** | Billed every membership year; required to publish on the App Store. |

---

## 3. Database — MongoDB Atlas

**Service:** MongoDB Atlas · **Provider:** MongoDB Inc.  
**Used for:** App database — orders, customers, tiffin plans, delivery records.  
**Free tier:** M0 — 512 MB (dev/staging). **Paid:** M10 ~Rs. 840/mo · M20 ~Rs. 2,100/mo (e.g. AWS Mumbai).  
**Billing:** Pay-as-you-go per cluster/hour.

---

## 4. Push notifications — Firebase FCM

**Service:** Firebase Cloud Messaging (FCM) — Admin SDK · **Provider:** Google Firebase.  
**Used for:** Server-side push — order updates, delivery alerts, promotions.  
**Cost:** Spark plan — FCM pushes free; no caps for typical volumes.

---

## 5. OTP & login — Twilio Verify API

**Provider:** Twilio Inc. (USA).  
**Pricing:** ~Rs. 8.4 per OTP verification (India numbers).  
**Examples:** 100 OTPs → ~Rs. 840/mo; 500 → ~Rs. 4,200; 1,000 → ~Rs. 8,400/mo.

---

## 6. Maps — Flutter Map (OpenStreetMap)

**Provider:** OpenStreetMap / `flutter_map`.  
**Cost:** Rs. 0 — no API key or billing for default OSM tiles.

---

## 7. App store deployment costs

### 7a. Google Play Store (Android)

| Field | Detail |
|-------|--------|
| **List price (registration)** | **USD $25** one-time |
| **Approx. INR** | **~Rs. 2,100** (at Rs. 84/USD) |
| Monthly fee | Rs. 0 — no subscription for the registration fee |
| Revenue share | 15% on first $1M/year revenue; 30% above (standard Google policies — verify current rules) |

### 7b. Apple App Store (iOS)

| Field | Detail |
|-------|--------|
| **List price (membership)** | **USD $99 per year** |
| **Approx. INR** | **~Rs. 8,316/year** (~Rs. 693/mo amortised) |
| Renewal | **Required annually** to keep the app listed |
| Revenue share | 15% (small business) or 30% on IAP — per Apple’s current program rules |

### Store fee comparison

| Store | One-time (USD) | Annual (USD) | Approx. annual INR (@84) |
|-------|----------------|--------------|---------------------------|
| Google Play | **$25** | $0 | — + one-time ~Rs. 2,100 |
| Apple App Store | — | **$99** | ~Rs. 8,316/year |

**Year 1 typical store spend (both platforms):** ~USD $124 one-time + first year Apple = **~USD $124** if both paid in same year (**~Rs. 10,400** approx.), then **~USD $99/year** (~Rs. 8,316) for Apple only in following years.

---

## 8. Who sets up & pays?

| Platform | Account owner | Reason |
|----------|---------------|--------|
| MongoDB Atlas | Client | Data ownership; production cluster on client’s card |
| Firebase (FCM) | Client | Project + service account credentials |
| Twilio | Client | OTP billing tied to client account |
| Flutter Map (OSM) | N/A | No account |
| **Google Play** | Client | **One-time USD $25** — developer account under client |
| **Apple App Store** | Client | **USD $99/year** — Apple Developer Program under client’s Apple ID |

---

## 9. Important notes

1. Official vendor pages are the source of truth for **USD** amounts.  
2. INR equivalents use Rs. 84/USD; actual card charges may differ.  
3. GST may apply. Twilio bills in USD.  
4. This report excludes server hosting, domain, SSL unless added separately.

---

## 10. Sign-off

| Role | Name | Company | Date | Signature |
|------|------|---------|------|-----------|
| Client / Owner | | | | |
| Vendor / Developer | | | | |

---

*Tiffin CRM — Third-Party Platform Cost Report | Generated: April 2026 | Verify all prices before purchase.*
