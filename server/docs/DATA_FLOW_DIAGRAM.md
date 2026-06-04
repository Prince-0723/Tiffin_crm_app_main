# TiffinCRM — Data Flow Diagram

View in VS Code (Mermaid extension), GitHub, or [mermaid.live](https://mermaid.live).

---

## Level 0 — High-level system flow

```mermaid
flowchart LR
    subgraph External
        FA[Flutter App]
        SMS[Twilio/Fast2SMS]
        FCM[Firebase FCM]
        RP[Razorpay]
        GM[Google Maps API]
    end

    subgraph Backend["Node.js API"]
        API[REST API + Socket.io]
    end

    subgraph DataStore["MongoDB"]
        DB[(Collections)]
    end

    FA -->|HTTPS + WebSocket| API
    API -->|Read/Write| DB
    API -->|Send OTP| SMS
    API -->|Push notification| FCM
    API -->|Payment verify| RP
    FA -->|Map/Location| GM
    GM -->|Geocoding| FA
```

---

## Level 1 — Core data flows by feature

```mermaid
flowchart TB
    subgraph External
        User((Admin User))
        App[Flutter App]
    end

    subgraph Auth["1. AUTH FLOW"]
        A1[Send OTP Request]
        A2[Verify OTP]
        A3[Issue JWT]
    end

    subgraph Customer["2. CUSTOMER FLOW"]
        C1[Create/Update Customer]
        C2[Import Contacts]
    end

    subgraph Subscription["3. SUBSCRIPTION FLOW"]
        S1[Create Plan]
        S2[Create Subscription]
        S3[Renew/Cancel]
    end

    subgraph Delivery["4. DELIVERY FLOW"]
        D1[Get Today's List]
        D2[Update Status]
        D3[GPS Broadcast]
    end

    subgraph Payment["5. PAYMENT FLOW"]
        P1[Record Payment]
        P2[Generate Invoice]
    end

    subgraph Reports["6. REPORTS FLOW"]
        R1[Summary/Analytics]
    end

    subgraph DB[MongoDB]
        UserDB[(User)]
        OtpDB[(Otp)]
        CustomerDB[(Customer)]
        PlanDB[(Plan)]
        SubDB[(Subscription)]
        DeliveryDB[(Delivery)]
        PaymentDB[(Payment)]
    end

    User --> App
    App --> A1
    A1 --> OtpDB
    A1 --> SMS
    A2 --> OtpDB
    A2 --> UserDB
    A3 --> App

    App --> C1
    C1 --> CustomerDB
    App --> C2
    C2 --> CustomerDB

    App --> S1
    S1 --> PlanDB
    App --> S2
    S2 --> CustomerDB
    S2 --> PlanDB
    S2 --> SubDB
    App --> S3
    S3 --> SubDB

    App --> D1
    D1 --> SubDB
    D1 --> CustomerDB
    D1 --> DeliveryDB
    App --> D2
    D2 --> DeliveryDB
    App --> D3
    D3 --> DeliveryDB

    App --> P1
    P1 --> PaymentDB
    P1 --> SubDB
    App --> P2
    P2 --> PaymentDB

    App --> R1
    R1 --> SubDB
    R1 --> DeliveryDB
    R1 --> PaymentDB
```

---

## Level 2 — Detailed process flows

### Auth flow

```mermaid
flowchart TD
    A[User enters phone] --> B[POST /auth/send-otp]
    B --> C{Valid phone?}
    C -->|No| E[400 Error]
    C -->|Yes| D[Generate 6-digit OTP]
    D --> F[Store in Otp DB - 10 min TTL]
    F --> G[Send via Twilio/Fast2SMS]
    G --> H[200 Success]

    I[User enters OTP] --> J[POST /auth/verify-otp]
    J --> K{OTP valid?}
    K -->|No| L[401 Unauthorized]
    K -->|Yes| M[Find/Create User]
    M --> N[Generate Access + Refresh JWT]
    N --> O[Return tokens + user]
    O --> P[Flutter stores tokens]
```

### Subscription → Delivery flow

```mermaid
flowchart LR
    subgraph Input
        S[Active Subscriptions]
        C[Cron or Manual]
    end

    subgraph Process
        P1[Get active subs for date]
        P2[Create Delivery records]
        P3[Assign to delivery boy]
    end

    subgraph Output
        D[(Delivery)]
    end

    C --> P1
    S --> P1
    P1 --> P2
    P2 --> P3
    P3 --> D
```

### Payment flow

```mermaid
flowchart TD
    A[Customer pays] --> B{Cash or Online?}
    B -->|Cash| C[Record payment manually]
    B -->|Razorpay| D[Create Razorpay order]
    D --> E[Flutter opens checkout]
    E --> F[Webhook / Verify]
    F --> G[Update payment status]

    C --> H[Create Payment record]
    G --> H
    H --> I[Optional: Update Subscription.paymentId]
    H --> J[Generate PDF invoice]
    J --> K[Store/Return URL]
```

---

## Level 3 — Request/response flow (API → DB)

```mermaid
flowchart TB
    subgraph Client
        Req[HTTP Request]
        Res[HTTP Response]
    end

    subgraph Middleware
        Auth[Auth Middleware - JWT]
        Valid[Validation]
    end

    subgraph Controllers
        Ctrl[Controller]
    end

    subgraph Services
        Svc[Service Layer]
    end

    subgraph Models
        Model[Mongoose Model]
    end

    subgraph DB[MongoDB]

    end

    Req --> Auth
    Auth --> Valid
    Valid --> Ctrl
    Ctrl --> Svc
    Svc --> Model
    Model --> DB
    DB --> Model
    Model --> Svc
    Svc --> Ctrl
    Ctrl --> Res
```

---

## Summary

| Flow           | Trigger        | Data in           | Process                     | Data out                |
|----------------|----------------|-------------------|-----------------------------|--------------------------|
| Auth (OTP)     | Flutter        | phone             | Send OTP, store in Otp      | SMS sent                 |
| Auth (Verify)  | Flutter        | phone, otp        | Verify, find/create User    | JWT, user                |
| Customer       | Flutter        | name, phone, addr | CRUD on Customer            | Customer doc             |
| Plan           | Flutter        | name, type, price | CRUD on Plan                | Plan doc                 |
| Subscription   | Flutter        | customerId, planId, dates | Create Subscription    | Subscription doc        |
| Delivery       | Cron / Flutter  | date, subscriptions | Create/update Delivery   | Delivery list            |
| Payment        | Flutter + Webhook | amount, method | Create Payment, update Sub  | Payment, invoice URL     |
| Reports        | Flutter        | period, filters   | Aggregate from collections  | Summary JSON             |
