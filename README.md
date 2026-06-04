# 🍱 TiffinCRM

## Complete Full-Stack CRM System for Tiffin & Meal Subscription Businesses

**Package:** `com.tiffin.service.management.crm`  
**Platform:** Flutter (Android) + Node.js Backend  
**Database:** MongoDB  
**Version:** 2026 Production Documentation  
**Author:** Swati Sen  

---

## 📌 Introduction

TiffinCRM is a production-ready full-stack Customer Relationship Management (CRM) system designed specifically for tiffin and meal subscription businesses.

It replaces manual and paper-based operations with a scalable digital platform, enabling business owners to efficiently manage:

- Customers  
- Subscriptions  
- Meal Plans  
- Deliveries  
- Payments  
- Reports & Analytics  

The system consists of a Flutter Android mobile application connected to a Node.js backend API with a MongoDB database.

---

## 📑 Table of Contents

- [Architecture Overview](#-architecture-overview)
- [Tech Stack](#-tech-stack)
- [Target Users](#-target-users)
- [Core Features](#-core-features)
- [Authentication & Security](#-authentication--security)
- [App Modules](#-app-modules-screen-flow)
- [Backend Architecture](#-backend-architecture)
- [Database Schema](#-database-schema)
- [Installation](#-installation)
- [Configuration](#-configuration)
- [API Endpoints](#-api-endpoints)
- [Performance & Scalability](#-performance--scalability)
- [Future Enhancements](#-future-enhancements)
- [Troubleshooting](#-troubleshooting)
- [Contributors](#-contributors)
- [License](#-license)

---

## 🏗 Architecture Overview

```
Flutter Android App
        │
        ▼
   REST API (Node.js + Express)
        │
        ▼
     MongoDB Database
```

### Optional Integrations

- Firebase (Push Notifications)  
- Cloudinary (File Storage)  
- MongoDB Atlas (Cloud Database)  
- VPS / AWS / Render (Hosting)

---

## 🛠 Tech Stack

### 📱 Frontend (Mobile App)

- Flutter (Dart)  
- Android APK  
- Material UI (Dark Theme)  
- State Management: Provider / GetX  
- REST API Integration  

### 🖥 Backend

- Node.js  
- Express.js  
- REST API Architecture  
- JWT Authentication  
- MVC Structure  
- Secure Middleware  

### 🗄 Database

- MongoDB (NoSQL)  
- Mongoose ORM  
- Cloud / Local Deployment Support  

---

## 👥 Target Users

### 🏢 Admin / Owner

- Manage customers  
- Create meal plans  
- Monitor revenue  
- Assign deliveries  
- View reports  

### 🚚 Staff / Delivery Boy

- View daily delivery list  
- Update delivery status  
- Track routes  

### 🧑‍💼 Support Staff

- Customer management  
- Update payments  
- Manage renewals  

---

## ⭐ Core Features

### 1️⃣ Customer Management

- Add / Edit / Delete customers  
- Profile with address & phone  
- Active / Inactive status  
- WhatsApp quick contact  
- Customer history tracking  

### 2️⃣ Subscription & Meal Plans

- Create meal plans (Breakfast / Lunch / Dinner)  
- Weekly / Monthly subscriptions  
- Auto renewal tracking  
- Expiry alerts  
- Status automation  

### 3️⃣ Delivery Management

- Assign delivery staff  
- Daily delivery listing  
- Mark Delivered / Pending  
- Delivery history logs  
- Route tracking  

### 4️⃣ Payment & Billing

- Record payments  
- Track pending dues  
- Payment history  
- Subscription billing  
- Invoice generation (PDF)  

### 5️⃣ Notifications

- Firebase Push Notifications  
- Renewal reminders  
- Payment alerts  
- Delivery updates  

### 6️⃣ Reports & Analytics

- Daily revenue  
- Monthly performance  
- Active subscriptions  
- Customer growth tracking  
- Delivery performance analytics  

---

## 🔐 Authentication & Security

- OTP-based login  
- JWT token authentication  
- Secure session handling  
- Role-based access control  
- Encrypted password storage  
- HTTPS-only APIs  
- Secure MongoDB connections  

---

## 📲 App Modules (Screen Flow)

- Authentication  
- Dashboard  
- Customers Module  
- Meal Plan Module  
- Delivery Module  
- Payments Module  
- Reports Module  

---

## 🖥 Backend Architecture

### Folder Structure

```
server/
 ├── config/
 ├── controllers/
 ├── routes/
 ├── models/
 ├── middleware/
 ├── utils/
 └── server.js
```

### Key APIs

- Auth API  
- Customer API  
- Subscription API  
- Delivery API  
- Payment API  
- Reports API  

---

## 🗄 Database Schema

### Customers

```json
{
  "name": "String",
  "phone": "String",
  "address": "String",
  "status": "String",
  "subscriptionId": "ObjectId"
}
```

### Meal Plans

```json
{
  "planName": "String",
  "price": "Number",
  "mealsType": "String",
  "duration": "Number"
}
```

### Subscriptions

```json
{
  "customerId": "ObjectId",
  "planId": "ObjectId",
  "startDate": "Date",
  "endDate": "Date",
  "status": "String"
}
```

---

## 🚀 Installation

### Backend Setup

```bash
git clone <repository-url>
cd server
npm install
```

Create `.env` file:

```
PORT=5000
MONGO_URI=your_mongodb_connection
JWT_SECRET=your_secret_key
```

Run server:

```bash
npm start
```

### Flutter App Setup

```bash
flutter pub get
flutter run
```

---

## ⚙ Configuration

- Update MongoDB connection string in `.env`
- Configure Firebase for push notifications
- Set production API URL in Flutter app
- Configure Cloudinary if using media storage

---

## 🌐 API Endpoints (Sample)

| Method | Endpoint | Description |
|--------|----------|------------|
| POST | /api/auth/login | Login via OTP |
| GET | /api/customers | Get all customers |
| POST | /api/customers | Add new customer |
| POST | /api/subscriptions | Create subscription |
| POST | /api/payments | Record payment |
| GET | /api/reports/daily | Get daily report |

---

## 📊 Performance & Scalability

### Initial Stage

- Users: 5–20  
- Daily Requests: 500–2000  
- Basic Node.js server sufficient  

### Scaling Stage

- Users: 100–1000  
- Upgrade VPS  
- Add Redis caching (optional)  
- Load balancing if required  

---

## 🔮 Future Enhancements

- Web Admin Panel  
- Customer Mobile App  
- Razorpay Integration  
- Multi-vendor SaaS Model  
- Multi-language Support  
- AI-powered Analytics Dashboard  

---

## 🛠 Troubleshooting

### MongoDB Connection Error

- Verify `MONGO_URI`
- Check IP whitelist in MongoDB Atlas

### JWT Authentication Error

- Ensure correct `JWT_SECRET`
- Verify token expiration settings

### Flutter API Not Connecting

- Confirm API base URL
- Check backend server status

---

## 👩‍💻 Contributors

**Swati Sen**  
Full Stack Developer (Flutter + Node.js)  
Production CRM Application – 2026  

---

## 📄 License

This project is proprietary software.  
All rights reserved © 2026 Swati Sen.

---

## 🎯 Conclusion

TiffinCRM is a complete, scalable, and production-ready CRM solution built with modern technologies.

✔ Easy business management  
✔ Automated subscription handling  
✔ Smart delivery tracking  
✔ Revenue monitoring  
✔ Secure architecture  
✔ Scalable backend  

Built with ❤️ using Flutter, Node.js & MongoDB
