# TiffinCRM — Entity Relationship Diagram

## Mermaid ER Diagram

View this file in VS Code (with Mermaid extension), GitHub, or [mermaid.live](https://mermaid.live).

```mermaid
erDiagram
    USER ||--o{ DELIVERY : "assigned_to"
    USER {
        ObjectId _id PK
        string phone UK "required"
        string name
        string role "admin, delivery"
        string fcmToken
        date createdAt
        date updatedAt
    }

    CUSTOMER ||--o{ SUBSCRIPTION : "has"
    CUSTOMER ||--o{ DELIVERY : "receives"
    CUSTOMER ||--o{ PAYMENT : "makes"
    CUSTOMER {
        ObjectId _id PK
        string name "required"
        string phone UK "required"
        string address
        GeoJSON location "lng, lat"
        string customerType "regular, corporate, trial"
        string status "active, inactive, pending, expired"
        string fcmToken
        string whatsapp
        boolean isDeleted "soft delete"
        date createdAt
        date updatedAt
    }

    PLAN ||--o{ SUBSCRIPTION : "subscribed_as"
    PLAN {
        ObjectId _id PK
        string name "required"
        string type "breakfast, lunch, dinner, custom"
        number price "required"
        string frequency "daily, weekly, monthly"
        string description
        boolean isActive
        date createdAt
        date updatedAt
    }

    SUBSCRIPTION ||--o{ DELIVERY : "generates"
    SUBSCRIPTION }o--|| PAYMENT : "last_payment"
    SUBSCRIPTION {
        ObjectId _id PK
        ObjectId customerId FK "required"
        ObjectId planId FK "required"
        date startDate "required"
        date endDate "required"
        string status "active, expired, cancelled, pending"
        string billingPeriod "daily, weekly, monthly"
        boolean autoRenew
        number price
        ObjectId paymentId FK "optional"
        date createdAt
        date updatedAt
    }

    DELIVERY {
        ObjectId _id PK
        ObjectId customerId FK "required"
        ObjectId subscriptionId FK "optional"
        date date "delivery date"
        string status "pending, in_transit, delivered, cancelled"
        ObjectId deliveryBoyId FK "optional"
        GeoJSON location
        date completedAt
        date createdAt
        date updatedAt
    }

    PAYMENT {
        ObjectId _id PK
        ObjectId customerId FK "required"
        ObjectId subscriptionId FK "optional"
        number amount "required"
        string method "cash, upi, card, razorpay"
        string status "pending, completed, failed, cancelled"
        string razorpayOrderId
        string invoiceUrl
        date createdAt
        date updatedAt
    }

    OTP {
        ObjectId _id PK
        string phone "required, indexed"
        string otp
        date expiresAt "TTL index"
        date createdAt
    }
```

---

## Relationship summary

| From        | To            | Cardinality | Description                    |
|------------|---------------|-------------|--------------------------------|
| User       | Delivery      | 1 : 0..n    | User (delivery boy) does many deliveries |
| Customer   | Subscription  | 1 : 0..n    | Customer has many subscriptions |
| Customer   | Delivery      | 1 : 0..n    | Customer receives many deliveries |
| Customer   | Payment       | 1 : 0..n    | Customer makes many payments |
| Plan       | Subscription  | 1 : 0..n    | Plan has many subscriptions |
| Subscription | Delivery    | 1 : 0..n    | Subscription generates many deliveries |
| Subscription | Payment     | 0..1 : 1    | Subscription has optional “last payment” reference |
| Otp        | —             | —           | Standalone; no FK to other entities |

---

## Legend

- **PK** = Primary Key (`_id`)
- **FK** = Foreign Key (reference to another collection)
- **UK** = Unique
- **GeoJSON** = `{ type: "Point", coordinates: [longitude, latitude] }`
