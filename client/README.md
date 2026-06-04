# TiffinCRM – Flutter Client

Flutter app for the Tiffin CRM platform. Supports **four roles**: Vendor, Customer, Delivery Staff, and Admin. All login via **phone + OTP**. The app talks to the live API at `https://tiffin-crm-app.onrender.com/api/v1` (no mock data in integrated flows).

---

## What Was Added / Changed (Summary)

### Core (Foundation)
- **API client**: `lib/core/network/dio_client.dart` – singleton Dio with auth header from `SecureStorage`, 401 → refresh token then retry (or clear storage and redirect to login).
- **Config**: `lib/core/config/app_config.dart` – `baseUrl`, `fcmSenderId`, `razorpayKeyId`, `truecallerAppKey` (from env or defaults).
- **Endpoints**: `lib/core/network/api_endpoints.dart` – all API paths as constants.
- **Storage**: `lib/core/storage/secure_storage.dart` – access/refresh token, `userRole`, `userId`, `clearAll()`.
- **Helpers**: `lib/core/utils/error_handler.dart`, `lib/core/utils/whatsapp_helper.dart`, `lib/core/utils/location_helper.dart`, `lib/core/utils/color_utils.dart`.
- **Exception**: `lib/core/network/api_exception.dart` – message + statusCode for API errors.

### Models
- Auth: `user_model`, `auth_response_model`.
- Extended **CustomerModel** (e.g. whatsapp, area, landmark, notes, tags, balance, location, vendorId, createdAt).
- Feature models: items, plans (with `MealSlotModel`), subscriptions, orders, delivery_staff, payments, invoices, admin stats, reports.

### API Modules (data layer)
- `AuthApi` – sendOtp, verifyOtp, getProfile, updateProfile, refreshToken, logout.
- `CustomerApi` – list, getById, create, update, delete, creditWallet, bulkImport.
- `ItemApi`, `PlanApi`, `SubscriptionApi`, `OrderApi`, `DeliveryApi`, `PaymentApi`, `InvoiceApi`, `AdminApi`, `ReportApi`.
- **Customer portal**: `CustomerPortalApi` – getMyProfile, updateMyProfile, getMyActivePlan, getMyOrders (for customer role).

### Auth Flow
- **Splash** → if no token → Login; if token → getProfile (with refresh on 401) → route by role.
- **Login** → 10-digit phone → `AuthApi.sendOtp(phone)`.
- **OTP** → `AuthApi.verifyOtp(phone, otp)` → save tokens + role + userId → optional FCM token via `AuthApi.updateProfile({'fcmToken': token})` → navigate by role.
- **Logout** (e.g. from drawer) → `AuthApi.logout()`, `SecureStorage.clearAll()`, `context.go(login)`.

### Routing & Role Homes
- **Routes**: Defined in `lib/core/router/app_routes.dart` and `app_router.dart`.
- **Role-based homes after login**:
  - **Vendor** → `/dashboard` (shell with drawer).
  - **Customer** → `/customer-home` (CustomerHomeScreen).
  - **Delivery staff** → `/delivery-dashboard` (DeliveryDashboardScreen).
  - **Admin** → `/admin-dashboard` (AdminDashboardScreen).

---

## Full App Flow (By Role)

### 1. Vendor Flow
- **Dashboard** (`/dashboard`) – Shell with drawer; home tab shows overview (mock stats on home; other tabs/screens use API).
- **Customers** (`/customers`) – List from `CustomerApi.list()` with filters (All / Active / Inactive / Low Balance), search, pagination, refresh. Add/Edit/Detail use `CustomerApi`; Detail has Credit Wallet, WhatsApp, Delete. **Bulk import** from contacts → `CustomerApi.bulkImport()`.
- **Menu Items** (`/items`) – List from `ItemApi.list()`; category/status filters; toggle active; Add/Edit via bottom sheet; Delete with confirmation.
- **Meal Plans** (`/meal-plans`) – List from `PlanApi.list()`; Global vs Custom sections; **Create Plan** (`/create-plan`) – name, price, plan type, meal slots (breakfast/lunch/dinner/evening) with item picker; **Assign to Customer** → subscriptions.
- **Subscriptions** (`/subscriptions`) – List from `SubscriptionApi.list(status)`; tabs Active / Paused / Expired / Cancelled; detail sheet: Pause, Unpause, Renew, Cancel, View Customer; **Assign Subscription** sheet – customer + plan, dates, delivery slot → `SubscriptionApi.create()`.
- **Daily Deliveries** (`/delivery`) – Today’s orders from `OrderApi.getToday()`; filters To Process / In Transit / Delivered; **Generate** / **Process**; per-order sheet: Assign delivery (staff picker → `OrderApi.assign` / `assignBulk`), Update status, WhatsApp; **Bulk assign** mode; FAB → View Map.
- **Delivery Staff** (`/delivery-staff`) – List from `DeliveryApi.listStaff()`; Add/Edit via `DeliveryApi`; per-row: active switch, Edit, Track on Map, Delete.
- **Payments** (`/payments`) – Collect payment (customer, amount, mode) → `PaymentApi.create()`; Overdue from `InvoiceApi.getOverdue()`; history from `PaymentApi.list()`.
- **Invoices** (`/invoices`) – List from `InvoiceApi.list()`; filter by status; Generate (customer, billing range); Share / Void in detail sheet.
- **Reports** (`/reports`) – Tabs Daily / Weekly / Monthly; revenue from `ReportApi.getSummary(period)`; existing chart UI kept.

### 2. Customer Flow (iMeals)
- **Customer Home** (`/customer-home`) – Bottom nav: **Home**, **Orders**, **Profile**.
  - **Home**: Active/paused plan from `CustomerPortalApi.getMyActivePlan()`; Pause 7 days / Resume via `SubscriptionApi`; shortcuts to Orders and Profile.
  - **Orders**: List from `CustomerPortalApi.getMyOrders(status)`; filters All / Pending / Processing / Out for delivery / Delivered.
  - **Profile**: Load `CustomerPortalApi.getMyProfile()`; edit name & address → `updateMyProfile`; **Share location with vendor** (GPS → `updateMyProfile` with GeoJSON location).

### 3. Delivery Staff Flow
- **My Deliveries** (`/delivery-dashboard`) – List from `DeliveryApi.getMyDeliveries()`; filters All / To deliver / In transit / Delivered; **Share my location** → `DeliveryApi.updateMe({ location })`; per-order sheet: Start delivery / Mark delivered (`OrderApi.updateStatus`), WhatsApp, Call, Open in Maps; **View on map** FAB → `/delivery-map`; Logout in menu.
- **Delivery Map** (`/delivery-map`) – Map with markers for assigned orders (customer location) and “me”; **Share my location** and refresh.

### 4. Admin Flow
- **Admin Dashboard** (`/admin-dashboard`) – Stats from `AdminApi.getStats()` (vendors, customers, orders, revenue, today, active subs, pending orders); list links to each entity.
- **Admin List** (`/admin-list` with `extra: AdminListType`) – One screen for Vendors, Customers, Delivery staff, Plans, Items, Subscriptions, Orders, Payments, Invoices; data from corresponding `AdminApi.get*()`; refresh and pull-to-refresh.

---

## Notifications (FCM)
- **main.dart**: After `Firebase.initializeApp()`, `_setupFcm()` runs: request permission, `onMessage` (foreground), `onMessageOpenedApp` and `getInitialMessage` (tap to open). If notification payload has `data['route']`, app navigates via `GoRouter.of(ctx).go(message.data['route'])`.
- **OTP success**: FCM token is sent to backend with `AuthApi.updateProfile({'fcmToken': token})`.

---

## Environment / Config
- **Base API URL**: `AppConfig.baseUrl` in `lib/core/config/app_config.dart` (local vs production).
- **`.env`** in `client/` (gitignored): FCM, Razorpay, Truecaller, etc. (no map API keys — maps use OpenStreetMap via `flutter_map`).

### Maps (OpenStreetMap)
In-app maps use **`flutter_map`** with OSM tiles (`lib/core/maps/osm_map_constants.dart`). External “open in maps” links use OpenStreetMap in the browser (`LocationHelper.openInMaps`).

Other optional defines: `FCM_SENDER_ID`, `RAZORPAY_KEY_ID`, `TRUECALLER_APP_KEY`.

**Truecaller (Android)** — set `TRUECALLER_CLIENT_ID` in `client/.env`. Gradle injects it into `AndroidManifest` at build time; rebuild after changing `.env`. Optional: `TRUECALLER_APP_KEY` for server-side use.

---

## Project Structure (Relevant Parts)

```
lib/
├── main.dart                 # Firebase init, FCM setup, runApp
├── app.dart                  # MaterialApp.router, DioClient navigator key
├── core/
│   ├── config/               # AppConfig (baseUrl, keys)
│   ├── maps/                 # OSM tile constants (flutter_map)
│   ├── network/              # dio_client, api_endpoints, api_exception
│   ├── router/               # app_router, app_routes
│   ├── storage/              # secure_storage
│   ├── theme/                # app_colors, app_theme
│   ├── utils/                # error_handler, whatsapp_helper, location_helper, color_utils
│   └── widgets/              # app_drawer, section_header, etc.
├── features/
│   ├── auth/                 # Login, OTP, Splash; AuthApi; role-based redirect
│   ├── customers/            # List, Detail, Add/Edit; CustomerApi; bulk import
│   ├── customer_portal/      # Customer home (plan, orders, profile); CustomerPortalApi
│   ├── dashboard/            # Vendor shell, meal plans, subscriptions, delivery, payments, invoices, reports
│   ├── delivery/             # Staff list, Add/Edit; Delivery dashboard & map; DeliveryApi
│   ├── items/                # Items list + Add/Edit sheet; ItemApi
│   ├── orders/               # OrderApi, OrderModel
│   ├── plans/                # PlanApi, CreatePlanScreen
│   ├── subscriptions/        # SubscriptionApi
│   ├── payments/             # PaymentApi, InvoiceApi
│   ├── admin/                # AdminApi, Admin dashboard, Admin list
│   └── reports/              # ReportApi
└── models/                   # CustomerModel, report_model, etc.
```

---

## How to Run
1. From repo root: `cd client`.
2. `flutter pub get`.
3. Copy `.env.example` to `.env` and set any keys you use (FCM, Razorpay, Truecaller, etc.).
4. `flutter run` (choose device; for mobile FCM works; web may have plugin compatibility issues with Firebase Messaging).

---

## Design Constraints (Respected)
- No changes to existing UI theme (e.g. `app_colors.dart`, `app_theme.dart`).
- No mock data in integrated flows; all data from live API.
- Tokens only in `SecureStorage`; auth uses Bearer token; 401 triggers refresh or logout.
- API errors surfaced via `ErrorHandler.show(context, e)`; WhatsApp via `WhatsAppHelper`; maps/directions via `LocationHelper.openInMaps`.

This README reflects the current state of the app after the full API integration and the addition of vendor, customer, delivery, and admin flows plus FCM.
