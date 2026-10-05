# FoodFlow Security Architecture

FoodFlow implements a **decentralized, stateless security architecture** combining JWT authentication with Spring Security Role-Based Access Control (RBAC) and explicit resource ownership verification.

---

## 1. Authentication Flow

```
Client (User/SPA)
      │
      ├─── 1. POST /api/auth/login { email, password }
      ▼
API Gateway (:8080)
      │
      ├─── 2. Route to User Service (:8081)
      ▼
User Service (:8081)
      │
      ├─── 3. Verify credentials via BCryptPasswordEncoder
      ├─── 4. Generate signed HMAC-SHA256 JWT
      ▼
Client receives JWT: { token: "eyJhbGciOiJIUzI1Ni..." }
```

---

## 2. JWT Structure & Claims

Tokens issued by `user-service` contain the following claims:

| Claim Key | Value | Description |
| :--- | :--- | :--- |
| `sub` | `String` (e.g. `alice@foodflow.com`) | User's unique login email |
| `userId` | `Long` (e.g. `12`) | User's unique primary key in `user_db` |
| `role` | `String` (e.g. `ROLE_CUSTOMER`) | Spring Security granted authority |
| `iat` | `Timestamp` | Token issuance time |
| `exp` | `Timestamp` | Expiration time (default 24 hours / 86400000ms) |

---

## 3. Decentralized Token Validation Flow

```
Client Request with Header: "Authorization: Bearer <token>"
      │
      ▼
API Gateway (:8080)
      │
      ├─── Transparently preserves and forwards Authorization header
      ▼
Downstream Service (e.g., Order Service :8083)
      │
      ▼
JwtAuthenticationFilter (Local Verification)
      ├─── 1. Parse JWT using shared ${JWT_SECRET}
      ├─── 2. Validate cryptographic HMAC-SHA256 signature
      ├─── 3. Validate expiration timestamp
      ├─── 4. Extract "userId" and "role" claims
      ├─── 5. Populate SecurityContextHolder with UsernamePasswordAuthenticationToken:
      │       - Principal: userId (Long)
      │       - Authorities: [SimpleGrantedAuthority(role)]
      ▼
Spring Security Method Security (@PreAuthorize)
      ├─── Authorized role? ──► Execute Controller / Service Method
      └─── Unauthorized? ──► Return HTTP 403 Forbidden
```

---

## 4. Role-Based Access Control (RBAC)

Spring Security `@EnableMethodSecurity` enforces strict role boundaries:
- **`ROLE_CUSTOMER`**: Order placement, order history viewing, payment processing.
- **`ROLE_RESTAURANT_OWNER`**: Restaurant profile creation/updates, menu item additions/deletions, operational status toggles, order status updates for owned restaurants.
- **`ROLE_DELIVERY_PARTNER`**: Delivery assignment acceptance, delivery progress status transitions.
- **`ROLE_ADMIN`**: Full administrative management across partners, orders, and restaurants.

---

## 5. Resource Ownership (HTTP 403 Forbidden)

Having a valid token and role is insufficient to modify arbitrary resources. Services enforce resource ownership in their business logic:
- **Restaurants & Menus:** `RestaurantService` and `MenuService` verify that `restaurant.getOwnerId().equals(callerUserId)`. If an owner tries to alter another owner's restaurant or menu, an `AccessDeniedException` is thrown (**HTTP 403**).
- **Orders:** `OrderService` verifies that `order.getUserId().equals(callerUserId)` on order lookups (**HTTP 403**). When updating order status, `OrderService` verifies the caller owns the order's restaurant via a snapshot call to `restaurant-service` (**HTTP 403**).
- **Payments:** `PaymentService` verifies that `payment.getUserId().equals(callerUserId)` on payment lookups (**HTTP 403**).
- **Notifications:** `NotificationController` enforces `@PreAuthorize("#userId == authentication.principal or hasRole('ROLE_ADMIN')")` (**HTTP 403**).

---

## 6. HTTP Status Code Contract

- **`401 Unauthorized`**: Returned when the `Authorization` header is missing, the JWT signature is invalid, the token has expired, or the token payload has been tampered with.
- **`403 Forbidden`**: Returned when the caller is authenticated, but either lacks the required role or does not own the specific target resource.

---

## 7. Configuration Security

Secret keys and database credentials are fully externalized via environment variables:
- `JWT_SECRET`: Base64-encoded HMAC-SHA256 secret (minimum 256 bits).
- `DB_PASSWORD`: PostgreSQL database password.

No secrets are hardcoded in application properties or committed to source control.
