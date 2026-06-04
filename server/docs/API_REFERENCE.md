# Tiffin CRM — API Reference

> **Base URL:** `http://localhost:5000/api/v1` (dev) · `https://your-domain.com/api/v1` (prod)
> **Content-Type:** `application/json` for all requests.
> **Auth header:** `Authorization: Bearer <accessToken>`

---

## Quick Reference — All Endpoints

| # | Method | Path | Auth / Role |
|---|--------|------|-------------|
| 1 | POST | `/auth/send-otp` | Public |
| 2 | POST | `/auth/verify-otp` | Public |
| 3 | POST | `/auth/truecaller` | Public |
| 4 | POST | `/auth/refresh-token` | Public |
| 5 | POST | `/auth/forgot-password` | Public |
| 6 | POST | `/auth/reset-password` | Public |
| 7 | POST | `/auth/logout` | Bearer (any) |
| 8 | GET | `/auth/me` | Bearer (any) |
| 9 | PUT | `/auth/me` | Bearer (any) |
| 10 | PUT | `/auth/change-password` | Bearer (any) |
| 11 | GET | `/customers` | vendor · admin |
| 12 | GET | `/customers/:id` | vendor · admin |
| 13 | POST | `/customers` | vendor · admin |
| 14 | POST | `/customers/bulk` | vendor · admin |
| 15 | PUT | `/customers/:id` | vendor · admin |
| 16 | DELETE | `/customers/:id` | vendor · admin |
| 17 | POST | `/customers/:id/wallet/credit` | vendor · admin |
| 18 | POST | `/customers/:customerId/plans` | vendor · admin |
| 19 | GET | `/customer/me` | customer |
| 20 | PUT | `/customer/me` | customer |
| 21 | GET | `/customer/me/plan` | customer |
| 22 | GET | `/customer/me/orders` | customer |
| 23 | GET | `/items` | vendor · admin |
| 24 | GET | `/items/:id` | vendor · admin |
| 25 | POST | `/items` | vendor · admin |
| 26 | PUT | `/items/:id` | vendor · admin |
| 27 | DELETE | `/items/:id` | vendor · admin |
| 28 | GET | `/delivery-staff/me` | delivery_staff |
| 29 | PATCH | `/delivery-staff/me` | delivery_staff |
| 30 | GET | `/delivery-staff` | vendor · admin |
| 31 | GET | `/delivery-staff/:id` | vendor · admin |
| 32 | POST | `/delivery-staff` | vendor · admin |
| 33 | PUT | `/delivery-staff/:id` | vendor · admin |
| 34 | DELETE | `/delivery-staff/:id` | vendor · admin |
| 35 | GET | `/plans` | vendor · admin |
| 36 | GET | `/plans/:id` | vendor · admin |
| 37 | POST | `/plans` | vendor · admin |
| 38 | PUT | `/plans/:id` | vendor · admin |
| 39 | DELETE | `/plans/:id` | vendor · admin |
| 40 | GET | `/subscriptions` | vendor · admin |
| 41 | GET | `/subscriptions/:id` | vendor · admin |
| 42 | POST | `/subscriptions` | vendor · admin |
| 43 | PUT | `/subscriptions/:id/renew` | vendor · admin |
| 44 | PUT | `/subscriptions/:id/cancel` | vendor · admin |
| 45 | PUT | `/subscriptions/:id/pause` | vendor · admin · customer |
| 46 | PUT | `/subscriptions/:id/unpause` | vendor · admin · customer |
| 47 | GET | `/daily-orders/today` | vendor · admin |
| 48 | POST | `/daily-orders/process` | vendor · admin |
| 49 | POST | `/daily-orders/mark-delivered` | vendor · admin |
| 50 | POST | `/daily-orders/assign-bulk` | vendor · admin |
| 51 | POST | `/daily-orders/generate` | vendor · admin |
| 52 | POST | `/daily-orders/generate-week` | vendor · admin |
| 53 | PATCH | `/daily-orders/:id/assign` | vendor · admin |
| 54 | PATCH | `/daily-orders/:id/status` | vendor · admin · delivery_staff |
| 55 | PATCH | `/daily-orders/:id/quantities` | customer |
| 56 | POST | `/daily-orders/:id/accept` | delivery_staff |
| 57 | POST | `/daily-orders/:id/reject` | delivery_staff |
| 58 | GET | `/delivery` | vendor · admin |
| 59 | GET | `/delivery/my-deliveries` | delivery_staff |
| 60 | GET | `/payments` | vendor · admin |
| 61 | POST | `/payments` | vendor · admin |
| 62 | POST | `/payments/create-order` | vendor · admin |
| 63 | GET | `/payments/:id/invoice` | vendor · admin |
| 64 | GET | `/invoices` | vendor · admin |
| 65 | POST | `/invoices/generate` | vendor · admin |
| 66 | GET | `/invoices/overdue` | vendor · admin |
| 67 | GET | `/invoices/:id` | vendor · admin |
| 68 | PUT | `/invoices/:id` | vendor · admin |
| 69 | POST | `/invoices/:id/share` | vendor · admin |
| 70 | POST | `/invoices/:id/void` | vendor · admin |
| 71 | POST | `/notifications/test` | vendor · admin |
| 72 | GET | `/reports/summary` | vendor · admin |
| 73 | GET | `/reports/today-deliveries` | vendor · admin |
| 74 | GET | `/reports/expiring-subscriptions` | vendor · admin |
| 75 | GET | `/reports/pending-payments` | vendor · admin |
| 76 | GET | `/admin/stats` | admin |
| 77 | GET | `/admin/vendors` | admin |
| 78 | GET | `/admin/customers` | admin |
| 79 | GET | `/admin/delivery-staff` | admin |
| 80 | GET | `/admin/plans` | admin |
| 81 | GET | `/admin/items` | admin |
| 82 | GET | `/admin/subscriptions` | admin |
| 83 | GET | `/admin/orders` | admin |
| 84 | GET | `/admin/payments` | admin |
| 85 | GET | `/admin/invoices` | admin |
| 86 | GET | `/admin/notifications` | admin |
| 87 | GET | `/public/health` | Public |
| 88 | GET | `/public/invoice/:shareToken` | Public |
| 89 | GET | `/public/customer-report/:token` | Public |
| 90 | POST | `/webhooks/razorpay` | Razorpay signature |

---

## Standard Response Shape

```json
// Success
{
  "success": true,
  "message": "Description",
  "data": { }
}

// Paginated success
{
  "success": true,
  "message": "Fetched",
  "data": {
    "data": [],
    "total": 100,
    "page": 1,
    "limit": 20,
    "totalPages": 5
  }
}

// Error
{
  "success": false,
  "message": "What went wrong",
  "errors": []
}
```

---

## Role Reference

| Role | Description |
|------|-------------|
| `vendor` | Food business owner. Full access to their own data. |
| `customer` | End customer. Self-service portal only. |
| `delivery_staff` | Delivery person. Sees only their assigned orders. |
| `admin` | Super admin. Cross-vendor full access. |

---

# 1. Auth

**Base:** `/api/v1/auth` · No auth required unless noted.

---

### POST `/api/v1/auth/send-otp`

Send OTP to a phone number.

**Headers:**
```
Content-Type: application/json
```

**Body:**
```json
{
  "phone": "9876543210"
}
```

> `phone` — 10-digit Indian mobile (starts with 6–9). Required.

**Response `200`:**
```json
{
  "success": true,
  "message": "OTP sent successfully"
}
```

---

### POST `/api/v1/auth/verify-otp`

Verify OTP and get tokens. Creates a new user on first login.

**Headers:**
```
Content-Type: application/json
```

**Body:**
```json
{
  "phone": "9876543210",
  "otp": "123456"
}
```

> `phone` — Required. `otp` — exactly 6 digits. Required.

**Response `200`:**
```json
{
  "success": true,
  "message": "Login successful",
  "data": {
    "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "user": {
      "id": "664abc123def456",
      "phone": "9876543210",
      "name": "Ramesh Kumar",
      "role": "vendor",
      "staffId": null,
      "customerId": null
    }
  }
}
```

> **Role auto-detection:**
> - Phone added as delivery staff by a vendor → `"delivery_staff"` + `staffId`
> - Phone added as customer by a vendor → `"customer"` + `customerId`
> - New phone or vendor → `"vendor"`

---

### POST `/api/v1/auth/truecaller`

Login using Truecaller SDK access token.

**Headers:**
```
Content-Type: application/json
```

**Body:**
```json
{
  "accessToken": "truecaller_sdk_access_token_here",
  "profile": {
    "phone": "9876543210",
    "name": "Ramesh Kumar",
    "truecallerId": "tc_id_optional"
  }
}
```

> `accessToken` — Required. `profile` — Optional.

**Response `200`:** Same as `verify-otp`.

---

### POST `/api/v1/auth/refresh-token`

Get a new access + refresh token pair using an existing refresh token.

**Headers:**
```
Content-Type: application/json
```

**Body:**
```json
{
  "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Response `200`:**
```json
{
  "success": true,
  "message": "Tokens refreshed",
  "data": {
    "accessToken": "eyJhbGci...",
    "refreshToken": "eyJhbGci...",
    "user": {
      "id": "664abc...",
      "phone": "9876543210",
      "name": "Ramesh Kumar",
      "role": "vendor"
    }
  }
}
```

---

### POST `/api/v1/auth/forgot-password`

Trigger a password-reset email.

**Headers:**
```
Content-Type: application/json
```

**Body:**
```json
{
  "phone": "9876543210"
}
```

**Response `200`:**
```json
{
  "success": true,
  "message": "If the phone is registered, a reset link has been sent"
}
```

---

### POST `/api/v1/auth/reset-password`

Set a new password using the reset token from the email.

**Headers:**
```
Content-Type: application/json
```

**Body:**
```json
{
  "token": "reset_token_from_email",
  "newPassword": "NewPass@123"
}
```

> `newPassword` — Min 8 chars, must include uppercase, lowercase, and a digit.

**Response `200`:** Same as `verify-otp` (returns tokens + user).

---

### POST `/api/v1/auth/logout`

**Headers:**
```
Authorization: Bearer <accessToken>
```

**Body:** None

**Response `200`:**
```json
{
  "success": true,
  "message": "Logged out successfully"
}
```

---

### GET `/api/v1/auth/me`

Get the logged-in user's profile.

**Headers:**
```
Authorization: Bearer <accessToken>
```

**Response `200`:**
```json
{
  "success": true,
  "data": {
    "id": "664abc...",
    "phone": "9876543210",
    "name": "Ramesh Kumar",
    "role": "vendor",
    "email": "ramesh@example.com",
    "businessName": "Ramesh Tiffin Centre",
    "ownerName": "Ramesh Kumar",
    "city": "Mumbai",
    "settings": {
      "lowBalanceThreshold": 100
    }
  }
}
```

---

### PUT `/api/v1/auth/me`

Update the logged-in user's profile. At least one field required.

**Headers:**
```
Authorization: Bearer <accessToken>
Content-Type: application/json
```

**Body:**
```json
{
  "fcmToken": "fcm_device_token_from_firebase",
  "businessName": "Ramesh Tiffin Centre",
  "ownerName": "Ramesh Kumar",
  "city": "Mumbai",
  "address": "Shop 5, Market Road",
  "email": "ramesh@example.com",
  "logoUrl": "https://example.com/logo.png"
}
```

> All fields are optional but at least one is required.

**Response `200`:**
```json
{
  "success": true,
  "message": "Profile updated",
  "data": {
    "user": {
      "id": "664abc...",
      "phone": "9876543210",
      "businessName": "Ramesh Tiffin Centre",
      "ownerName": "Ramesh Kumar",
      "city": "Mumbai",
      "fcmToken": "fcm_device_token_from_firebase"
    }
  }
}
```

---

### PUT `/api/v1/auth/change-password`

**Headers:**
```
Authorization: Bearer <accessToken>
Content-Type: application/json
```

**Body:**
```json
{
  "currentPassword": "OldPass@123",
  "newPassword": "NewPass@456"
}
```

**Response `200`:**
```json
{
  "success": true,
  "message": "Password changed, please login again"
}
```

---

# 2. Customers (Vendor / Admin)

**Base:** `/api/v1/customers`

**Headers for all routes:**
```
Authorization: Bearer <accessToken>
Content-Type: application/json
```

---

### GET `/api/v1/customers`

List all customers (vendor-scoped automatically).

**Query params:**
```
GET /api/v1/customers?page=1&limit=20&status=active&lowBalance=true
```

| Param | Values | Default |
|-------|--------|---------|
| `page` | integer ≥ 1 | `1` |
| `limit` | 1 – 100 | `20` |
| `status` | `active` · `inactive` · `blocked` | all |
| `lowBalance` | `true` | — |

> `lowBalance=true` returns only customers whose wallet balance is below the vendor's configured `lowBalanceThreshold`.

**Response `200`:**
```json
{
  "success": true,
  "data": {
    "data": [
      {
        "_id": "664cust001",
        "name": "Sita Sharma",
        "phone": "9876543211",
        "address": "Flat 4B, Andheri West",
        "area": "Andheri",
        "balance": 250.00,
        "status": "active",
        "tags": ["veg", "morning"],
        "whatsappUrl": "https://wa.me/919876543211"
      }
    ],
    "total": 45,
    "page": 1,
    "limit": 20,
    "totalPages": 3
  }
}
```

---

### GET `/api/v1/customers/:id`

**Response `200`:**
```json
{
  "success": true,
  "data": {
    "_id": "664cust001",
    "name": "Sita Sharma",
    "phone": "9876543211",
    "whatsapp": "9876543299",
    "address": "Flat 4B, Andheri West",
    "area": "Andheri",
    "landmark": "Near SBI Bank",
    "balance": 250.00,
    "status": "active",
    "tags": ["veg"],
    "notes": "Prefers morning delivery",
    "location": {
      "type": "Point",
      "coordinates": [72.8347, 19.1136]
    },
    "whatsappUrl": "https://wa.me/919876543299"
  }
}
```

---

### POST `/api/v1/customers`

Create a new customer.

**Body:**
```json
{
  "name": "Sita Sharma",
  "phone": "9876543211",
  "address": "Flat 4B, Andheri West",
  "area": "Andheri",
  "landmark": "Near SBI Bank",
  "whatsapp": "9876543299",
  "notes": "Prefers morning delivery",
  "tags": ["veg", "morning"],
  "status": "active",
  "location": {
    "type": "Point",
    "coordinates": [72.8347, 19.1136]
  }
}
```

> Required: `name`, `phone`, `address`. All others optional.
> `whatsapp` — separate WhatsApp number if different from `phone`.
> `location.coordinates` — `[longitude, latitude]`.

**Response `201`:**
```json
{
  "success": true,
  "message": "Customer created",
  "data": {
    "_id": "664cust001",
    "name": "Sita Sharma",
    "phone": "9876543211",
    "balance": 0,
    "status": "active"
  }
}
```

---

### POST `/api/v1/customers/bulk`

Import up to 100 customers at once. Duplicates (same phone under this vendor) are silently skipped.

> Rate limited: **5 requests per 15 minutes**.

**Body:**
```json
{
  "customers": [
    {
      "name": "Sita Sharma",
      "phone": "9876543211",
      "address": "Flat 4B, Andheri",
      "status": "active",
      "whatsapp": "9876543299"
    },
    {
      "name": "Mohan Das",
      "phone": "9876543212",
      "address": "Plot 12, Borivali"
    }
  ]
}
```

> `customers` — array of 1–100 items. Required per item: `name`, `phone`.

**Response `201`:**
```json
{
  "success": true,
  "data": {
    "created": 18,
    "skipped": 2,
    "data": []
  }
}
```

---

### PUT `/api/v1/customers/:id`

Update a customer. Send only the fields you want to change.

**Body:**
```json
{
  "name": "Sita Sharma Updated",
  "phone": "9876543211",
  "address": "New address, Andheri",
  "area": "Andheri East",
  "landmark": "Near Subway",
  "whatsapp": "9876543200",
  "notes": "Updated note",
  "tags": ["veg"],
  "status": "active",
  "location": {
    "type": "Point",
    "coordinates": [72.8347, 19.1136]
  }
}
```

---

### DELETE `/api/v1/customers/:id`

Soft-delete (sets `isDeleted: true`). Data is preserved.

**Body:** None

**Response `200`:**
```json
{
  "success": true,
  "message": "Customer deleted (soft)"
}
```

---

### POST `/api/v1/customers/:id/wallet/credit`

Add money to a customer's wallet. Automatically creates a Payment record.

**Body:**
```json
{
  "amount": 500.00,
  "paymentMethod": "cash",
  "notes": "Cash collected on March 12"
}
```

> `amount` — Required, > 0.
> `paymentMethod` — Optional (default: `cash`). Values: `cash` · `upi` · `card` · `razorpay` · `bank_transfer` · `cheque`.

**Response `201`:**
```json
{
  "success": true,
  "data": {
    "newBalance": 1000.00,
    "amountAdded": 500.00,
    "paymentId": "664pay001"
  }
}
```

---

### POST `/api/v1/customers/:customerId/plans`

Create a **customer-specific** meal plan (only assignable to this one customer).

**Body:** Same as `POST /api/v1/plans` — see [Meal Plans → POST](#post-apiv1plans).

**Response `201`:**
```json
{
  "success": true,
  "message": "Custom plan created for customer Sita Sharma",
  "data": { }
}
```

---

# 3. Customer Portal (Self-Service)

**Base:** `/api/v1/customer`

**Headers for all routes:**
```
Authorization: Bearer <accessToken>
```

> Only the `customer` role can access these endpoints.

---

### GET `/api/v1/customer/me`

Get own profile.

**Response `200`:**
```json
{
  "success": true,
  "message": "Profile fetched",
  "data": {
    "_id": "664cust001",
    "name": "Sita Sharma",
    "phone": "9876543211",
    "address": "Flat 4B, Andheri West",
    "area": "Andheri",
    "balance": 750.00,
    "status": "active",
    "tags": ["veg"],
    "notes": ""
  }
}
```

---

### PUT `/api/v1/customer/me`

Update own profile. At least one field required.

**Headers:**
```
Authorization: Bearer <accessToken>
Content-Type: application/json
```

**Body:**
```json
{
  "name": "Sita Sharma",
  "address": "New Flat 5C, Andheri West",
  "fcmToken": "new_fcm_device_token",
  "location": {
    "type": "Point",
    "coordinates": [72.8347, 19.1136]
  }
}
```

---

### GET `/api/v1/customer/me/plan`

Get active or paused subscription with full plan and item details.

**Response `200`:**
```json
{
  "success": true,
  "message": "Active plan fetched",
  "data": {
    "_id": "sub123",
    "status": "active",
    "startDate": "2026-03-01T00:00:00.000Z",
    "endDate": "2026-03-31T00:00:00.000Z",
    "deliverySlot": "morning",
    "deliveryDays": [1, 2, 3, 4, 5, 6],
    "planId": {
      "_id": "plan456",
      "planName": "Lunch Basic",
      "price": 150,
      "planType": "monthly",
      "mealSlots": [
        {
          "slot": "lunch",
          "items": [
            {
              "itemId": {
                "_id": "item001",
                "name": "Roti",
                "unitPrice": 5,
                "unit": "piece"
              },
              "quantity": 4
            },
            {
              "itemId": {
                "_id": "item002",
                "name": "Dal",
                "unitPrice": 25,
                "unit": "bowl"
              },
              "quantity": 1
            }
          ]
        }
      ]
    }
  }
}
```

> Returns `null` data if no active or paused subscription.

---

### GET `/api/v1/customer/me/orders`

Paginated order history.

**Query params:**
```
GET /api/v1/customer/me/orders?page=1&limit=20&status=delivered
```

| Param | Values |
|-------|--------|
| `page` | integer |
| `limit` | integer |
| `status` | `pending` · `processing` · `out_for_delivery` · `delivered` · `cancelled` · `failed` · `skipped` |

**Response `200`:**
```json
{
  "success": true,
  "data": {
    "data": [
      {
        "_id": "order001",
        "orderDate": "2026-03-12T00:00:00.000Z",
        "status": "out_for_delivery",
        "amount": 150.00,
        "resolvedItems": [
          { "name": "Roti", "quantity": 4, "unitPrice": 5, "subtotal": 20 }
        ],
        "deliveryStaffId": {
          "_id": "staff001",
          "name": "Raju",
          "phone": "9123456789"
        }
      }
    ],
    "total": 30,
    "page": 1,
    "limit": 20,
    "totalPages": 2
  }
}
```

> When `status === "out_for_delivery"`, `deliveryStaffId.name` and `deliveryStaffId.phone` are populated so the customer can contact the delivery person.

---

# 4. Items

**Base:** `/api/v1/items`

**Headers for all routes:**
```
Authorization: Bearer <accessToken>
Content-Type: application/json
```

---

### GET `/api/v1/items`

**Query params:**
```
GET /api/v1/items?page=1&limit=20&isActive=true&category=roti
```

**Response `200`:**
```json
{
  "success": true,
  "data": {
    "data": [
      {
        "_id": "item001",
        "name": "Roti",
        "unitPrice": 5,
        "unit": "piece",
        "category": "roti",
        "isActive": true
      }
    ],
    "total": 10,
    "page": 1,
    "limit": 20,
    "totalPages": 1
  }
}
```

---

### GET `/api/v1/items/:id`

---

### POST `/api/v1/items`

**Body:**
```json
{
  "name": "Roti",
  "unitPrice": 5,
  "unit": "piece",
  "category": "roti",
  "isActive": true
}
```

> Required: `name`, `unitPrice`.
> `unit` — `piece` · `bowl` · `plate` · `glass` · `other`.

**Response `201`:**
```json
{
  "success": true,
  "message": "Item created",
  "data": {
    "_id": "item001",
    "name": "Roti",
    "unitPrice": 5,
    "unit": "piece",
    "isActive": true
  }
}
```

---

### PUT `/api/v1/items/:id`

Send only the fields to change.

**Body:**
```json
{
  "name": "Roti",
  "unitPrice": 6,
  "unit": "piece",
  "category": "roti",
  "isActive": true
}
```

---

### DELETE `/api/v1/items/:id`

Returns `400` if the item is used in any active plan.

**Body:** None

---

# 5. Delivery Staff

**Base:** `/api/v1/delivery-staff`

---

### GET `/api/v1/delivery-staff/me`

**Auth:** `delivery_staff` role

**Headers:**
```
Authorization: Bearer <accessToken>
```

**Response `200`:** Own `DeliveryStaff` document.

---

### PATCH `/api/v1/delivery-staff/me`

Update FCM token and/or GPS location. Call this **on every app open** to keep push notifications and location fresh.

**Auth:** `delivery_staff` role

**Headers:**
```
Authorization: Bearer <accessToken>
Content-Type: application/json
```

**Body:**
```json
{
  "fcmToken": "new_fcm_device_token_from_firebase",
  "location": {
    "type": "Point",
    "coordinates": [72.8347, 19.1136]
  }
}
```

---

### GET `/api/v1/delivery-staff`

**Auth:** `vendor` or `admin`

**Query params:**
```
GET /api/v1/delivery-staff?page=1&limit=20&isActive=true
```

---

### GET `/api/v1/delivery-staff/:id`

**Auth:** `vendor` or `admin`

---

### POST `/api/v1/delivery-staff`

**Auth:** `vendor` or `admin`

**Headers:**
```
Authorization: Bearer <accessToken>
Content-Type: application/json
```

**Body:**
```json
{
  "name": "Raju Delivery",
  "phone": "9123456789",
  "areas": ["Andheri", "Bandra"],
  "joiningDate": "2026-01-15",
  "isActive": true
}
```

> Required: `name`, `phone`.

**Response `201`:**
```json
{
  "success": true,
  "message": "Delivery staff created",
  "data": {
    "_id": "staff001",
    "name": "Raju Delivery",
    "phone": "9123456789",
    "areas": ["Andheri", "Bandra"],
    "isActive": true
  }
}
```

---

### PUT `/api/v1/delivery-staff/:id`

**Auth:** `vendor` or `admin`

Send only the fields to change.

**Body:**
```json
{
  "name": "Raju Updated",
  "phone": "9123456789",
  "areas": ["Andheri"],
  "joiningDate": "2026-01-15",
  "isActive": true,
  "fcmToken": "fcm_token_here"
}
```

---

### DELETE `/api/v1/delivery-staff/:id`

**Auth:** `vendor` or `admin`

Soft-deactivates (`isActive: false`). Returns `400` if staff has any `pending` / `processing` / `out_for_delivery` orders today.

**Body:** None

---

# 6. Meal Plans

**Base:** `/api/v1/plans`

**Headers for all routes:**
```
Authorization: Bearer <accessToken>
Content-Type: application/json
```

---

### GET `/api/v1/plans`

**Query params:**
```
GET /api/v1/plans?page=1&limit=20&isActive=true&planType=monthly
GET /api/v1/plans?customerId=664cust001
GET /api/v1/plans?generic=true
```

| Param | Notes |
|-------|-------|
| `isActive` | boolean |
| `planType` | `daily` · `weekly` · `monthly` · `custom` |
| `customerId` | Returns generic plans + this customer's specific plans |
| `generic` | `true` = only plans with no `customerId` |

---

### GET `/api/v1/plans/:id`

---

### POST `/api/v1/plans`

**Body:**
```json
{
  "planName": "Lunch Basic",
  "price": 150,
  "planType": "monthly",
  "mealSlots": [
    {
      "slot": "lunch",
      "items": [
        { "itemId": "664item001", "quantity": 4 },
        { "itemId": "664item002", "quantity": 1 },
        { "itemId": "664item003", "quantity": 1 }
      ]
    }
  ],
  "customerId": null,
  "isActive": true,
  "color": "#FF5733"
}
```

> Required: `planName`, `price`, `mealSlots` (min 1 slot).
> `slot` values: `breakfast` · `lunch` · `dinner` · `snack` · `early_morning`. No duplicate slots.
> `customerId` — if set, this plan is only assignable to that customer.
> All `itemId` values must belong to the vendor and be active.

**Response `201`:**
```json
{
  "success": true,
  "message": "Plan created",
  "data": {
    "_id": "plan001",
    "planName": "Lunch Basic",
    "price": 150,
    "includesLunch": true,
    "includesBreakfast": false,
    "includesDinner": false,
    "mealSlots": [ ]
  }
}
```

---

### PUT `/api/v1/plans/:id`

Send only the fields to change.

**Body:**
```json
{
  "planName": "Lunch Premium",
  "price": 180,
  "planType": "monthly",
  "isActive": true,
  "color": "#FF5733",
  "mealSlots": [
    {
      "slot": "lunch",
      "items": [
        { "itemId": "664item001", "quantity": 5 },
        { "itemId": "664item002", "quantity": 1 }
      ]
    }
  ]
}
```

---

### DELETE `/api/v1/plans/:id`

Returns `400` if active subscriptions use this plan or if future orders have been generated.

**Body:** None

---

# 7. Subscriptions

**Base:** `/api/v1/subscriptions`

**Headers for all routes:**
```
Authorization: Bearer <accessToken>
Content-Type: application/json
```

---

### GET `/api/v1/subscriptions`

**Auth:** `vendor` or `admin`

**Query params:**
```
GET /api/v1/subscriptions?page=1&limit=20&status=active&customerId=664cust001
```

---

### GET `/api/v1/subscriptions/:id`

**Auth:** `vendor` or `admin`

---

### POST `/api/v1/subscriptions`

**Auth:** `vendor` or `admin`

Assign a meal plan to a customer. Automatically generates the first daily order.

**Body:**
```json
{
  "customerId": "664cust001",
  "planId": "664plan001",
  "startDate": "2026-04-01",
  "endDate": "2026-04-30",
  "deliverySlot": "morning",
  "deliveryDays": [1, 2, 3, 4, 5, 6],
  "autoRenew": false,
  "notes": "No spicy food"
}
```

> Required: `customerId`, `planId`, `startDate`, `endDate`, `deliverySlot`, `deliveryDays`.
> `deliveryDays` — array of integers `0`=Sun, `1`=Mon … `6`=Sat. Min 1 day.
> `deliverySlot` — `morning` · `afternoon` · `evening`.

**Response `201`:**
```json
{
  "success": true,
  "data": {
    "_id": "sub001",
    "customerId": { "_id": "664cust001", "name": "Sita Sharma" },
    "planId": { "_id": "664plan001", "planName": "Lunch Basic", "price": 150 },
    "startDate": "2026-04-01T00:00:00.000Z",
    "endDate": "2026-04-30T00:00:00.000Z",
    "status": "active",
    "deliverySlot": "morning",
    "deliveryDays": [1, 2, 3, 4, 5, 6]
  }
}
```

---

### PUT `/api/v1/subscriptions/:id/renew`

**Auth:** `vendor` or `admin`

**Body:**
```json
{
  "startDate": "2026-05-01",
  "endDate": "2026-05-31"
}
```

---

### PUT `/api/v1/subscriptions/:id/cancel`

**Auth:** `vendor` or `admin`

**Body:** None (empty)

**Response `200`:**
```json
{
  "success": true,
  "data": { "status": "cancelled" }
}
```

---

### PUT `/api/v1/subscriptions/:id/pause`

**Auth:** `vendor` · `admin` · `customer`

Pause delivery for a date range. No daily orders are generated within the pause window.

**Body:**
```json
{
  "pausedFrom": "2026-04-10",
  "pausedUntil": "2026-04-15"
}
```

> Both dates must be today or future. `pausedUntil` must be ≤ subscription `endDate`.

**Response `200`:**
```json
{
  "success": true,
  "data": {
    "status": "paused",
    "pausedFrom": "2026-04-10T00:00:00.000Z",
    "pausedUntil": "2026-04-15T00:00:00.000Z"
  }
}
```

---

### PUT `/api/v1/subscriptions/:id/unpause`

**Auth:** `vendor` · `admin` · `customer`

**Body:** None (empty)

**Response `200`:**
```json
{
  "success": true,
  "data": { "status": "active", "pausedFrom": null, "pausedUntil": null }
}
```

---

# 8. Daily Orders

**Base:** `/api/v1/daily-orders`

**Headers for all routes:**
```
Authorization: Bearer <accessToken>
Content-Type: application/json
```

---

### GET `/api/v1/daily-orders/today`

**Auth:** `vendor` or `admin`

Get all orders for today.

**Response `200`:**
```json
{
  "success": true,
  "data": {
    "data": [
      {
        "_id": "order001",
        "orderDate": "2026-03-12T00:00:00.000Z",
        "status": "pending",
        "amount": 150.00,
        "customerId": { "_id": "664cust001", "name": "Sita", "phone": "9876543211" },
        "deliveryStaffId": null,
        "resolvedItems": [
          { "name": "Roti", "quantity": 4, "unitPrice": 5, "subtotal": 20 }
        ]
      }
    ],
    "total": 25
  }
}
```

---

### POST `/api/v1/daily-orders/process`

**Auth:** `vendor` or `admin`

Move all `pending` orders → `processing`. Sends FCM push to each customer.

**Body:**
```json
{
  "date": "2026-03-12"
}
```

> `date` — Optional. Defaults to today.

**Response `200`:**
```json
{
  "success": true,
  "data": { "processedCount": 12 }
}
```

---

### PATCH `/api/v1/daily-orders/:id/assign`

**Auth:** `vendor` or `admin`

Assign one delivery staff to one order.

**Body:**
```json
{
  "deliveryStaffId": "664staff001"
}
```

> Staff receives FCM notification on assignment.

**Response `200`:**
```json
{
  "success": true,
  "data": {
    "_id": "order001",
    "deliveryStaffId": { "_id": "664staff001", "name": "Raju" },
    "status": "processing"
  }
}
```

---

### POST `/api/v1/daily-orders/assign-bulk`

**Auth:** `vendor` or `admin`

Assign one delivery person to multiple orders at once.

**Body:**
```json
{
  "orderIds": ["order001", "order002", "order003"],
  "deliveryStaffId": "664staff001"
}
```

**Response `200`:**
```json
{
  "success": true,
  "data": {
    "assignedCount": 3,
    "deliveryStaffId": "664staff001",
    "staffName": "Raju"
  }
}
```

---

### PATCH `/api/v1/daily-orders/:id/status`

**Auth:** `vendor` · `admin` · `delivery_staff`

Update order status.

**Body:**
```json
{
  "status": "out_for_delivery"
}
```

> Allowed `status` values: `out_for_delivery` · `delivered`
>
> Valid transitions:
> - `pending` / `processing` → `out_for_delivery`
> - `pending` / `processing` / `out_for_delivery` → `delivered`
>
> On `delivered`: customer balance is deducted by `order.amount`. If new balance < `lowBalanceThreshold`, both customer and vendor receive a low-balance notification.

**Response `200`:**
```json
{
  "success": true,
  "data": {
    "order": { "_id": "order001", "status": "delivered" },
    "balanceDeducted": 150.00,
    "customerNewBalance": 350.00
  }
}
```

---

### POST `/api/v1/daily-orders/:id/accept`

**Auth:** `delivery_staff`

Accept an assigned task. Sets `acceptedAt` timestamp. Notifies the vendor.

**Body:** None (empty)

**Response `200`:**
```json
{
  "success": true,
  "data": { "orderId": "order001" }
}
```

---

### POST `/api/v1/daily-orders/:id/reject`

**Auth:** `delivery_staff`

Reject a task. Resets order to `processing` and clears staff assignment. Vendor is notified to reassign.

**Body:**
```json
{
  "reason": "Vehicle breakdown"
}
```

> `reason` — Optional.

**Response `200`:**
```json
{
  "success": true,
  "data": { "orderId": "order001" }
}
```

---

### PATCH `/api/v1/daily-orders/:id/quantities`

**Auth:** `customer` only

Adjust meal item quantities. Can only change quantities of **existing items** — cannot add or remove items.

**Body (array):**
```json
[
  { "itemId": "664item001", "quantity": 5 },
  { "itemId": "664item002", "quantity": 2 }
]
```

> `quantity` must be ≥ 1. All `itemId` values must already exist in the order.

**Response `200`:**
```json
{
  "success": true,
  "data": {
    "orderId": "order001",
    "resolvedItems": [
      { "name": "Roti", "quantity": 5, "unitPrice": 5, "subtotal": 25 },
      { "name": "Dal", "quantity": 2, "unitPrice": 25, "subtotal": 50 }
    ],
    "amount": 75.00
  }
}
```

---

### POST `/api/v1/daily-orders/mark-delivered`

**Auth:** `vendor` or `admin`

Bulk mark orders as delivered and deduct balances.

**Body:**
```json
{
  "orderDate": "2026-03-12",
  "customerId": "664cust001"
}
```

> `orderDate` — Required. `customerId` — Optional. If omitted, all customers' orders for that date are marked.

---

### POST `/api/v1/daily-orders/generate`

**Auth:** `vendor` or `admin`

Manually generate orders for a specific date.

**Body:**
```json
{
  "date": "2026-04-01"
}
```

**Response `200`:**
```json
{
  "success": true,
  "data": {
    "generatedCount": 15,
    "existingCount": 2,
    "date": "2026-04-01"
  }
}
```

---

### POST `/api/v1/daily-orders/generate-week`

**Auth:** `vendor` or `admin`

Generate orders for the next 7 days.

**Body:** None (empty)

**Response `200`:**
```json
{
  "success": true,
  "data": {
    "results": [
      { "date": "2026-03-12", "generatedCount": 15, "existingCount": 0 },
      { "date": "2026-03-13", "generatedCount": 12, "existingCount": 0 }
    ]
  }
}
```

---

# 9. Delivery (Staff View)

**Base:** `/api/v1/delivery`

---

### GET `/api/v1/delivery`

**Auth:** `vendor` or `admin`

Today's all orders (alias for `daily-orders/today`).

---

### GET `/api/v1/delivery/my-deliveries`

**Auth:** `delivery_staff`

**Headers:**
```
Authorization: Bearer <accessToken>
```

Today's orders assigned to the logged-in staff, sorted by area.

**Response `200`:**
```json
{
  "success": true,
  "data": {
    "data": [
      {
        "_id": "order001",
        "status": "processing",
        "amount": 150.00,
        "customerId": {
          "_id": "664cust001",
          "name": "Sita Sharma",
          "phone": "9876543211",
          "address": "Flat 4B, Andheri West",
          "area": "Andheri",
          "location": {
            "type": "Point",
            "coordinates": [72.8347, 19.1136]
          },
          "whatsappUrl": "https://wa.me/919876543211"
        }
      }
    ],
    "total": 6,
    "date": "2026-03-12"
  }
}
```

---

# 10. Payments

**Base:** `/api/v1/payments`

**Headers for all routes:**
```
Authorization: Bearer <accessToken>
Content-Type: application/json
```

> `vendor` or `admin` only.

---

### GET `/api/v1/payments`

**Query params:**
```
GET /api/v1/payments?page=1&limit=20&customerId=664cust001&fromDate=2026-03-01&toDate=2026-03-31
```

---

### POST `/api/v1/payments`

Record a manual payment (cash, UPI, cheque, etc.).

**Body:**
```json
{
  "customerId": "664cust001",
  "amount": 500.00,
  "paymentMethod": "upi",
  "invoiceId": null,
  "subscriptionId": null,
  "paymentDate": "2026-03-12",
  "transactionRef": "UPI_REF_12345"
}
```

> Required: `customerId`, `amount`, `paymentMethod`.
> If no `invoiceId` and no `subscriptionId` → wallet top-up (increases `Customer.balance`).
> If `invoiceId` → updates invoice `paidAmount` and `paymentStatus`.

**Response `201`:** Payment document with populated `customerId` and `invoiceId`.

---

### POST `/api/v1/payments/create-order`

Create a Razorpay order before showing the Razorpay checkout.

**Body:**
```json
{
  "amount": 500,
  "receipt": "invoice_march_2026",
  "customerId": "664cust001",
  "invoiceId": "664inv001"
}
```

> Required: `amount` (in rupees, ≥ 1), `receipt`.

**Response `200`:**
```json
{
  "success": true,
  "data": {
    "orderId": "order_rzp_abc123",
    "keyId": "rzp_live_xxxxxxxxxx",
    "amount": 50000,
    "receipt": "invoice_march_2026",
    "paymentId": "664pay001"
  }
}
```

> `amount` in paise (multiply rupees × 100) — pass this to Razorpay checkout.

---

### GET `/api/v1/payments/:id/invoice`

Fetch a payment record by ID.

---

# 11. Invoices

**Base:** `/api/v1/invoices`

**Headers for all routes:**
```
Authorization: Bearer <accessToken>
Content-Type: application/json
```

---

### GET `/api/v1/invoices`

**Query params:**
```
GET /api/v1/invoices?customerId=664cust001&paymentStatus=unpaid&month=2026-03
```

---

### POST `/api/v1/invoices/generate`

Generate an invoice from delivered orders in a date range.

**Body:**
```json
{
  "customerId": "664cust001",
  "billingStart": "2026-03-01",
  "billingEnd": "2026-03-31",
  "subscriptionId": null
}
```

> Required: `customerId`, `billingStart`, `billingEnd`.

**Response `201`:**
```json
{
  "success": true,
  "data": {
    "_id": "inv001",
    "invoiceNumber": "INV-2026-001",
    "totalAmount": 3600.00,
    "paidAmount": 0,
    "balanceDue": 3600.00,
    "paymentStatus": "unpaid",
    "lineItems": [ ],
    "warning": null
  }
}
```

> `warning` is non-null if no `delivered` orders found (falls back to `pending`/`processing` orders).

---

### GET `/api/v1/invoices/overdue`

Invoices where `dueDate < today`, `balanceDue > 0`, and not voided.

---

### GET `/api/v1/invoices/:id`

---

### PUT `/api/v1/invoices/:id`

Update notes or due date. Cannot update paid invoices.

**Body:**
```json
{
  "notes": "Customer promised payment by 20th",
  "dueDate": "2026-03-25"
}
```

---

### POST `/api/v1/invoices/:id/share`

Create a 48-hour shareable link (no login required to view).

**Body:** None (empty)

**Response `200`:**
```json
{
  "success": true,
  "data": {
    "url": "/api/v1/public/invoice/abc123sharetoken"
  }
}
```

---

### POST `/api/v1/invoices/:id/void`

Permanently void an invoice.

**Body:** None (empty)

---

# 12. Notifications

**Base:** `/api/v1/notifications`

---

### POST `/api/v1/notifications/test`

**Auth:** `vendor` or `admin`

Send a test push notification to a customer.

**Headers:**
```
Authorization: Bearer <accessToken>
Content-Type: application/json
```

**Body:**
```json
{
  "customerId": "664cust001",
  "type": "order_processing"
}
```

> `customerId` — Required.
> `type` — Optional. Must be one of the values below. Defaults to `order_processing`.

**Valid `type` values:**
```
subscription_activated
subscription_expired
order_processing
out_for_delivery
delivered
task_assigned
task_accepted
task_rejected
low_balance
plan_expiring
```

**Response `200`:**
```json
{
  "success": true,
  "data": {
    "result": { },
    "type": "order_processing",
    "validTypes": [
      "subscription_activated",
      "subscription_expired",
      "order_processing",
      "out_for_delivery",
      "delivered",
      "task_assigned",
      "task_accepted",
      "task_rejected",
      "low_balance",
      "plan_expiring"
    ]
  }
}
```

---

# 13. Reports

**Base:** `/api/v1/reports`

**Headers for all routes:**
```
Authorization: Bearer <accessToken>
```

> `vendor` or `admin` only.

---

### GET `/api/v1/reports/summary`

**Query params:**
```
GET /api/v1/reports/summary?period=monthly
```

> `period` — `daily` · `weekly` · `monthly` (default).

**Response `200`:**
```json
{
  "success": true,
  "data": {
    "period": "monthly",
    "revenue": 45000.00,
    "ordersDelivered": 300,
    "activeCustomers": 45,
    "activeSubscriptions": 40
  }
}
```

---

### GET `/api/v1/reports/today-deliveries`

**Response `200`:**
```json
{
  "success": true,
  "data": {
    "date": "2026-03-12",
    "total": 25,
    "byStatus": {
      "pending": 5,
      "processing": 8,
      "out_for_delivery": 7,
      "delivered": 5
    },
    "orders": [ ]
  }
}
```

---

### GET `/api/v1/reports/expiring-subscriptions`

**Query params:**
```
GET /api/v1/reports/expiring-subscriptions?days=7
```

> `days` — 1–90, default `7`.

**Response `200`:** List of subscriptions expiring within `N` days.

---

### GET `/api/v1/reports/pending-payments`

Returns invoices with `paymentStatus: unpaid` or `partial`, plus customers with negative balance.

---

# 14. Admin

**Base:** `/api/v1/admin`

**Headers for all routes:**
```
Authorization: Bearer <accessToken>
```

> `admin` role only. Cross-vendor access to all data.

All list endpoints support: `page`, `limit`, `vendorId` (to filter by one vendor).

---

### GET `/api/v1/admin/stats`

**Response `200`:**
```json
{
  "success": true,
  "data": {
    "vendors": { "total": 12, "active": 10 },
    "customers": { "total": 850 },
    "deliveryStaff": { "total": 45 },
    "plans": { "active": 120 },
    "subscriptions": { "active": 310 },
    "todayOrders": { "total": 280, "delivered": 190, "pending": 90 },
    "revenue": { "last30Days": 425000 }
  }
}
```

---

### GET `/api/v1/admin/vendors`

```
GET /api/v1/admin/vendors?page=1&limit=20&isActive=true
```

---

### GET `/api/v1/admin/customers`

```
GET /api/v1/admin/customers?page=1&limit=20&vendorId=664vendor001&status=active
```

---

### GET `/api/v1/admin/delivery-staff`

```
GET /api/v1/admin/delivery-staff?page=1&limit=20&vendorId=664vendor001&isActive=true
```

---

### GET `/api/v1/admin/plans`

```
GET /api/v1/admin/plans?page=1&limit=20&vendorId=664vendor001&isActive=true
```

---

### GET `/api/v1/admin/items`

```
GET /api/v1/admin/items?page=1&limit=20&vendorId=664vendor001&isActive=true
```

---

### GET `/api/v1/admin/subscriptions`

```
GET /api/v1/admin/subscriptions?page=1&limit=20&vendorId=664vendor001&status=active
```

> `status` — `active` · `paused` · `expired` · `cancelled`

---

### GET `/api/v1/admin/orders`

```
GET /api/v1/admin/orders?page=1&limit=20&vendorId=664vendor001&status=delivered&date=2026-03-12
```

> `status` — `pending` · `processing` · `out_for_delivery` · `delivered` · `cancelled` · `failed` · `skipped`

---

### GET `/api/v1/admin/payments`

```
GET /api/v1/admin/payments?page=1&limit=20&vendorId=664vendor001&status=captured&type=payment
```

> `status` — `pending` · `captured` · `failed` · `refunded`
> `type` — `payment` · `wallet_credit` · `order_deduction`

---

### GET `/api/v1/admin/invoices`

```
GET /api/v1/admin/invoices?page=1&limit=20&vendorId=664vendor001&paymentStatus=unpaid
```

---

### GET `/api/v1/admin/notifications`

```
GET /api/v1/admin/notifications?page=1&limit=20&vendorId=664vendor001&type=low_balance&isRead=false
```

---

# 15. Public (No Auth)

**Base:** `/api/v1/public`

No `Authorization` header required.

---

### GET `/api/v1/public/health`

**Response `200`:**
```json
{ "status": "ok", "version": "4.0" }
```

---

### GET `/api/v1/public/invoice/:shareToken`

View a shared invoice. Token valid for 48 hours.

**Response `200`:** Invoice data (sensitive fields stripped).

**Response `410`:**
```json
{ "success": false, "message": "TOKEN_EXPIRED" }
```

---

### GET `/api/v1/public/customer-report/:token`

View a customer's balance report (no login required).

**Response `200`:**
```json
{
  "success": true,
  "data": {
    "name": "Sita Sharma",
    "phone": "9876543211",
    "address": "Flat 4B, Andheri West",
    "area": "Andheri",
    "balance": 750.00,
    "totalDue": 0,
    "tags": ["veg"],
    "notes": ""
  }
}
```

---

# 16. Webhooks

### POST `/api/v1/webhooks/razorpay`

Razorpay webhook. **Do not call manually.** Razorpay calls this automatically after payment.

**Headers (set by Razorpay):**
```
Content-Type: application/json
x-razorpay-signature: <hmac_sha256_signature>
```

**Handled event:** `payment.captured` only.

**Response `200`:**
```json
{ "success": true, "message": "Processed" }
```

---

# 17. Socket.IO — Real-time Delivery Tracking

**Namespace:** `/delivery`
**Connection URL:** `ws://localhost:5000/delivery` (dev) · `wss://your-domain.com/delivery` (prod)

### Connect

Pass the JWT as a query parameter:

```javascript
const socket = io("https://your-domain.com/delivery", {
  query: { token: "eyJhbGci..." }
});
```

### Rooms (auto-joined on connect)

| Room | Joined by |
|------|-----------|
| `vendor:<ownerId>` | vendor |
| `customer:<customerId>` | customer |
| `staff:<staffId>` | delivery_staff |
| `admin` | admin |

---

### Emit — `location_update` (delivery staff → server)

Send GPS coordinates while delivering.

```javascript
socket.emit("location_update", {
  "orderId": "order001",
  "latitude": 19.1136,
  "longitude": 72.8697
});
```

---

### Receive — `location_updated` (server → vendor, customer, admin)

```json
{
  "staffId": "staff001",
  "orderId": "order001",
  "customerId": "cust001",
  "latitude": 19.1136,
  "longitude": 72.8697,
  "timestamp": "2026-03-12T10:30:00.000Z"
}
```

---

### Receive — `order_status_changed` (server → all relevant parties)

```json
{
  "orderId": "order001",
  "status": "out_for_delivery",
  "customerId": "cust001"
}
```

---

# Appendix A — Error Codes

| HTTP | When |
|------|------|
| `400` | Invalid or missing body fields — check `errors[]` |
| `401` | Missing or expired Bearer token |
| `403` | Valid token but wrong role |
| `404` | Resource not found or belongs to another vendor |
| `409` | Duplicate (e.g. phone already registered) |
| `410` | Token expired (share links, reset tokens) |
| `429` | Rate limit hit |
| `500` | Internal server error |
| `502` | Third-party failure (OTP / Truecaller) |
| `503` | Server starting up |

---

# Appendix B — Enum Values

### Order Status Flow

```
pending → processing → out_for_delivery → delivered
                    ↘ cancelled / failed / skipped
```

### Payment Methods

```
cash · upi · card · razorpay · bank_transfer · cheque
```

### Item Units

```
piece · bowl · plate · glass · other
```

### Meal Slot Names

```
breakfast · lunch · dinner · snack · early_morning
```

### Plan Types

```
daily · weekly · monthly · custom
```

### Delivery Slots

```
morning · afternoon · evening
```

### Subscription Status

```
active · paused · expired · cancelled
```

### Notification Types

| Type | Sent to | When |
|------|---------|------|
| `subscription_activated` | Customer | New subscription created |
| `subscription_expired` | Customer | Subscription expired (daily cron) |
| `order_processing` | Customer | Vendor starts cooking |
| `out_for_delivery` | Customer + Vendor | Order picked up |
| `delivered` | Customer + Vendor | Order delivered |
| `task_assigned` | Delivery Staff | Assigned to an order |
| `task_accepted` | Vendor | Staff accepted task |
| `task_rejected` | Vendor | Staff rejected task |
| `low_balance` | Customer + Vendor | Wallet below threshold after delivery |
| `plan_expiring` | Customer | (Future: pre-expiry warning) |

---

*Tiffin CRM API v4.0 — March 2026*
