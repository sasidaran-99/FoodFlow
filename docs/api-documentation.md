# FoodFlow API Documentation

All external REST requests are routed through the API Gateway on port `8080`. Downstream services independently validate Bearer JWT tokens and enforce role-based access control.

> [!NOTE]
> All endpoints use the `/api/...` prefix (not `/api/v1/...`).

---

## 1. User Service (`/api/auth`, `/api/users`)

### `POST /api/auth/register`
- **Auth:** Public
- **Request:**
  ```json
  {
    "name": "Alice Smith",
    "email": "alice@foodflow.com",
    "password": "Password123!",
    "phone": "1234567890",
    "role": "CUSTOMER"
  }
  ```
  *(Roles: `CUSTOMER`, `RESTAURANT_OWNER`, `DELIVERY_PARTNER`, `ADMIN`)*
- **Response (201 Created):**
  ```json
  {
    "token": "eyJhbGciOiJIUzI1Ni...",
    "user": { "id": 1, "name": "Alice Smith", "email": "alice@foodflow.com", "role": "CUSTOMER" }
  }
  ```

### `POST /api/auth/login`
- **Auth:** Public *(Rate limited via Redis in API Gateway)*
- **Request:**
  ```json
  { "email": "alice@foodflow.com", "password": "Password123!" }
  ```
- **Response (200 OK):** AuthResponse containing JWT token.

### `GET /api/users/me`
- **Auth:** Bearer JWT (Any authenticated user)
- **Response (200 OK):** User profile DTO.

### `POST /api/users/addresses`
- **Auth:** Bearer JWT (Any authenticated user)
- **Request:** AddressDto (`street`, `city`, `state`, `zipCode`, `country`)
- **Response (201 Created):** AddressDto with generated `id`.

---

## 2. Restaurant Service (`/api/restaurants`)

### `POST /api/restaurants`
- **Auth:** Bearer JWT (`ROLE_RESTAURANT_OWNER`)
- **Request:**
  ```json
  { "name": "Pasta Palace", "description": "Italian classics", "address": "123 Main St" }
  ```
- **Response (201 Created):** `RestaurantDto` including assigned `ownerId`.

### `GET /api/restaurants/{id}`
- **Auth:** Bearer JWT (Any authenticated user)
- **Response (200 OK):** `RestaurantDto` (cached in Redis with 10-minute TTL).

### `PUT /api/restaurants/{id}`
- **Auth:** Bearer JWT (`ROLE_RESTAURANT_OWNER` matching `ownerId`)
- **Response:** `200 OK` on success, `403 Forbidden` if caller does not own the restaurant.

### `PATCH /api/restaurants/{id}/status?isOpen=true`
- **Auth:** Bearer JWT (`ROLE_RESTAURANT_OWNER` matching `ownerId`)
- **Response:** `200 OK` on success, `403 Forbidden` if caller does not own the restaurant.

### `POST /api/restaurants/{restaurantId}/menu`
- **Auth:** Bearer JWT (`ROLE_RESTAURANT_OWNER` matching `ownerId`)
- **Request:**
  ```json
  { "name": "Spaghetti Carbonara", "description": "Guanciale and pecorino", "price": 18.50, "available": true }
  ```
- **Response (201 Created):** `MenuItemDto`.

### `GET /api/restaurants/{restaurantId}/menu`
- **Auth:** Bearer JWT (Any authenticated user)
- **Response (200 OK):** List of `MenuItemDto`.

---

## 3. Order Service (`/api/orders`)

### `POST /api/orders`
- **Auth:** Bearer JWT (`ROLE_CUSTOMER`, `ROLE_RESTAURANT_OWNER`)
- **Request:**
  ```json
  {
    "restaurantId": 1,
    "items": [
      { "menuItemId": 10, "quantity": 2 }
    ]
  }
  ```
- **Response (201 Created):** `OrderDto` (prices snapshot from Restaurant Service).

### `GET /api/orders/{id}`
- **Auth:** Bearer JWT (`ROLE_CUSTOMER`, `ROLE_RESTAURANT_OWNER`)
- **Response:** `200 OK` if caller placed order; `403 Forbidden` if order belongs to another customer.

### `GET /api/orders?page=0&size=10`
- **Auth:** Bearer JWT (Returns paginated orders placed by authenticated caller).

### `PATCH /api/orders/{id}/status?status=RESTAURANT_ACCEPTED`
- **Auth:** Bearer JWT (`ROLE_ADMIN` or `ROLE_RESTAURANT_OWNER` owning the order's restaurant)
- **Response:** `200 OK` on valid state transition; `403 Forbidden` if restaurant ownership check fails; `400 Bad Request` if invalid state transition.

---

## 4. Payment Service (`/api/payments`)

### `POST /api/payments`
- **Auth:** Bearer JWT (`ROLE_CUSTOMER`)
- **Header:** `Idempotency-Key: <unique-token>` *(Mandatory)*
- **Request:**
  ```json
  { "orderId": 101, "amount": 37.00 }
  ```
- **Response (200 OK):** `PaymentResponse` (Idempotent: duplicate key returns original payment record).

### `GET /api/payments/order/{orderId}`
- **Auth:** Bearer JWT (`ROLE_CUSTOMER` owning the order, or `ROLE_ADMIN`)
- **Response:** `200 OK` on success, `403 Forbidden` if caller does not own the order.

---

## 5. Notification Service (`/api/notifications`)

### `GET /api/notifications/user/{userId}`
- **Auth:** Bearer JWT (`userId == authentication.principal` or `ROLE_ADMIN`)
- **Response (200 OK):** List of `NotificationDto` for caller; `403 Forbidden` if requesting another user's notifications.

---

## 6. Delivery Service (`/api/deliveries`)

### `POST /api/deliveries/{id}/assign`
- **Auth:** Bearer JWT (`ROLE_DELIVERY_PARTNER`)
- **Response (200 OK):** Dispatches next available partner with JPA `@Version` optimistic locking.

### `PATCH /api/deliveries/{id}/status?status=PICKED_UP`
- **Auth:** Bearer JWT (`ROLE_DELIVERY_PARTNER`, `ROLE_ADMIN`)
- **Response (200 OK):** Validates and updates delivery state machine.
