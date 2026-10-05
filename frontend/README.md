# FoodFlow Frontend Application

A clean, responsive, production-ready web frontend for the **FoodFlow Distributed Food-Ordering System**, built with **React 18**, **TypeScript**, **Vite**, **React Router v6**, and **Axios**.

The application is styled with a traditional, clean, light-mode user interface (similar to standard food ordering platforms like Swiggy and Zomato) designed for robust academic evaluations and real-world microservice demonstrations.

---

## 🌟 Key Architecture Principles

1. **Single Entry Point via API Gateway (`http://localhost:8080`)**:
   - The frontend communicates **exclusively** through the Spring Cloud API Gateway.
   - It never accesses internal microservice ports (`8081`–`8086`) directly.
   - Global CORS is handled seamlessly at the gateway level.

2. **Real Distributed Backend (Zero Mocking)**:
   - All data displayed in the application is retrieved live from the Spring Boot microservices, PostgreSQL databases, Redis caching layers, and Kafka event brokers.
   - Order submission triggers real asynchronous Kafka event pipelines (`ORDER_CREATED` &rarr; `payment-service` &rarr; `PAYMENT_SUCCESS` &rarr; `order-service` &rarr; `CONFIRMED` &rarr; `delivery-service` &rarr; `notification-service`).

3. **Role-Based Access Control (RBAC)**:
   - Four distinct user roles supported: `CUSTOMER`, `RESTAURANT_OWNER`, `DELIVERY_PARTNER`, and `ADMIN`.
   - Role-guarded routes with friendly unauthorized fallbacks.
   - Context-aware navigation bar adapting instantly to the active role.

4. **Clean, Distraction-Free Visual Design**:
   - Inter typography, high-contrast readable text, subtle gray borders, standard cards, and intuitive buttons.
   - Free of gimmickry: no neon colors, glassmorphism, 3D elements, or artificial dashboards.

---

## 🚀 Quick Start Guide

### Prerequisites
- **Node.js**: v18.0.0 or higher
- **npm**: v9.0.0 or higher
- **FoodFlow Backend**: API Gateway and backing microservices running (see root project documentation)

### 1. Installation
Navigate into the `frontend` folder and install dependencies:
```bash
cd frontend
npm install
```

### 2. Development Server
Start the Vite development server:
```bash
npm run dev
```
The application will launch at:
👉 **`http://localhost:3000`**

### 3. Production Build
Verify TypeScript types and build optimized static assets:
```bash
npm run build
```
Production assets are generated in `frontend/dist/`.

---

## 🧭 Application Routes & User Journeys

| URL Route | Role Required | Purpose |
|---|---|---|
| `/` or `/restaurants` | Public | Explore restaurant catalog with live search and open/closed filters. |
| `/restaurants/:id` | Authenticated | View restaurant menu, item descriptions, prices, and add dishes to cart. |
| `/cart` | Public / Customer | Review cart items, modify quantities, view subtotal, and proceed to checkout. |
| `/checkout` | `CUSTOMER` | Review delivery address, order breakdown, and submit order. |
| `/orders` | `CUSTOMER`, `OWNER`, `ADMIN` | View order history with real-time status badges and timestamps. |
| `/orders/:id` | `CUSTOMER`, `OWNER`, `ADMIN` | Detailed live tracking timeline, Kafka payment receipt, driver info, and event notifications. |
| `/notifications` | Authenticated | Live Kafka event notifications feed for the current user. |
| `/profile` | Authenticated | View user profile details and manage delivery addresses. |
| `/owner/restaurants` | `RESTAURANT_OWNER`, `ADMIN` | Manage owned restaurant venues and toggle open/closed operational status. |
| `/owner/restaurants/:id/menu` | `RESTAURANT_OWNER`, `ADMIN` | Add new dishes, set pricing, toggle item availability in real time, or delete items. |
| `/delivery` | `DELIVERY_PARTNER`, `ADMIN` | Driver operations console: look up orders, claim deliveries, and advance stages (`PICKED_UP` &rarr; `OUT_FOR_DELIVERY` &rarr; `DELIVERED`). |
| `/admin` | `ADMIN` | Fleet management: register new delivery partners and monitor system operations. |
| `/login` | Public | Sign in to existing account with email & password. |
| `/register` | Public | Create a new account with immediate role selection. |

---

## 🔄 End-to-End Demonstration Walkthrough

Follow this step-by-step path to demonstrate the entire distributed architecture in action:

### Step 1: Register a Customer Account
1. Open `http://localhost:3000/register`.
2. Fill in your name, email (e.g. `alice@example.com`), password, phone, and select **Customer** as the role.
3. Submit to automatically sign in with your JWT token.

### Step 2: Browse & Add to Cart
1. Navigate to **Restaurants** (`/`).
2. Select any active restaurant (e.g., *Test Order Restaurant* or *Kafka Test Restaurant*).
3. Browse the menu items and click **Add to Cart**.
4. Adjust item quantities using the `+` / `-` controls.

### Step 3: Checkout & Order Creation
1. Click **Cart** &rarr; **Proceed to Checkout**.
2. Confirm your delivery information and click **Place Order**.
3. You will immediately be redirected to the **Live Order Tracking** page (`/orders/:id`).

### Step 4: Watch Kafka Asynchronous Processing
1. Observe the **Live Order Status Progression** bar:
   - Initial state: `Payment Pending`
   - Within 1–2 seconds, the order automatically transitions to `Confirmed` as Kafka processes the payment in the background.
2. Scroll down to inspect:
   - **Payment Verification**: Confirmed payment record ID, timestamp, and unique gateway transaction reference number.
   - **Delivery Status**: Initialized delivery record with `ASSIGNMENT_PENDING` status.
   - **Order Event Notifications**: Live Kafka notification logged (`ORDER_CONFIRMED`).

### Step 5: Deliver the Order as a Delivery Partner
1. Log out or open an incognito window.
2. Sign up or log in as a **Delivery Partner** (`/register` with role `Delivery Partner`).
3. Navigate to **Delivery Dashboard** (`/delivery`).
4. Enter the Order ID from Step 3 (or click one from the recent orders list) and click **Look Up Delivery**.
5. Click **✋ Accept & Assign to Me** &rarr; Status becomes `ASSIGNED`.
6. Click **📦 Confirm Food Picked Up** &rarr; Status becomes `PICKED_UP`.
7. Click **🛵 Start Ride (Out for Delivery)** &rarr; Status becomes `OUT_FOR_DELIVERY`.
8. Click **✅ Complete Delivery (Delivered)** &rarr; Status becomes `DELIVERED`.
9. Switch back to the Customer view on `/orders/:id`: the progress timeline updates live to `Delivered`!

---

## 🛠️ Project Structure

```
frontend/
├── public/                 # Static assets & icons
├── src/
│   ├── api/                # Typed API client services
│   │   ├── client.ts       # Axios instance with JWT interceptors
│   │   ├── authApi.ts      # Authentication (register/login)
│   │   ├── restaurantApi.ts# Restaurant and menu management
│   │   ├── orderApi.ts     # Order placement and tracking
│   │   ├── paymentApi.ts   # Payment query service
│   │   ├── notificationApi.ts # Kafka notification feeds
│   │   ├── deliveryApi.ts  # Delivery lifecycle operations
│   │   └── userApi.ts      # Profile and saved addresses
│   ├── components/         # Reusable UI components
│   │   ├── Navbar.tsx      # Role-aware sticky header
│   │   ├── Footer.tsx      # Standard footer
│   │   ├── ProtectedRoute.tsx # RBAC route guard
│   │   ├── LoadingSpinner.tsx # Clean loading feedback
│   │   └── ErrorMessage.tsx   # Friendly error alerts with retry
│   ├── context/            # React Context state management
│   │   ├── AuthContext.tsx # User session, JWT token, and role checks
│   │   └── CartContext.tsx # Shopping cart with single-restaurant enforcement
│   ├── pages/              # Top-level page views
│   │   ├── LoginPage.tsx
│   │   ├── RegisterPage.tsx
│   │   ├── RestaurantsPage.tsx
│   │   ├── RestaurantDetailPage.tsx
│   │   ├── CartPage.tsx
│   │   ├── CheckoutPage.tsx
│   │   ├── OrdersPage.tsx
│   │   ├── OrderDetailPage.tsx
│   │   ├── NotificationsPage.tsx
│   │   ├── ProfilePage.tsx
│   │   ├── OwnerDashboardPage.tsx
│   │   ├── ManageMenuPage.tsx
│   │   ├── DeliveryDashboardPage.tsx
│   │   └── AdminDashboardPage.tsx
│   ├── types/              # Comprehensive TypeScript interfaces
│   │   └── index.ts        # Backend DTO schemas & enums
│   ├── App.tsx             # Route definitions and provider wrapping
│   ├── main.tsx            # React 18 createRoot bootstrap
│   └── index.css           # Clean, responsive CSS stylesheet
├── index.html              # HTML entrypoint
├── package.json            # Dependencies & build scripts
├── tsconfig.json           # TypeScript configuration
└── vite.config.ts          # Vite configuration (port 3000)
```

---

## 🔒 Security & Token Handling

- **JWT Storage**: Upon successful login or registration, the JWT token and user profile are saved in `localStorage`.
- **Request Interceptor**: Every outbound Axios request checks for `foodflow_token` and automatically injects `Authorization: Bearer <token>`.
- **Response Interceptor**:
  - `401 Unauthorized`: Automatically purges stale credentials and redirects the user to `/login?expired=true`.
  - `403 Forbidden`: Displays clear role permission alerts without crashing the UI.
  - `429 Too Many Requests`: Alerts user to Redis rate limiting constraints.
- **Single Restaurant Policy**: The shopping cart automatically prompts the user if they attempt to add items from a different restaurant, preserving relational order boundaries.

---

## 🔧 Troubleshooting

| Issue | Cause | Solution |
|---|---|---|
| `Network Error` or `Connection Refused` | API Gateway (:8080) is not running | Ensure API Gateway is running on `http://localhost:8080`. |
| `403 Forbidden` on browsing restaurants | User not signed in | Create an account or log in. In FoodFlow Phase 9A security, catalog queries require valid JWT authentication. |
| Port 3000 already in use | Another process is occupying port 3000 | Kill the competing process or adjust the port in `vite.config.ts` and `package.json`. |
| Order stuck in `PAYMENT_PENDING` | Kafka or payment-service is down | Check Docker Kafka container (:9092) and payment-service (:8084). |
