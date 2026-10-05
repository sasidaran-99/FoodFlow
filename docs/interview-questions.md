# FoodFlow Technical Interview Guide

This guide provides accurate, interview-defensible answers explaining the architectural decisions, trade-offs, and design patterns implemented in FoodFlow.

---

### Q1: Why did you choose a microservices architecture over a monolith?
**Answer:**
FoodFlow models distinct business domains with completely different operational and scaling profiles:
- The **Order Service** experiences sharp spikes during lunch and dinner meal times and needs to scale horizontally without redeploying the catalog.
- The **Restaurant Service** is read-heavy and benefits from dedicated Redis cache-aside layers.
- The **Delivery Service** requires isolated transaction management and optimistic concurrency locking for driver dispatch.
- Decoupling these domains with independent PostgreSQL schemas (Database-per-Service) prevents database-level lock contention and eliminates single points of failure.

---

### Q2: How does your system achieve payment idempotency?
**Answer:**
Payment idempotency is implemented directly within PostgreSQL (`payment_db`):
1. The client provides an `Idempotency-Key` header with their payment request.
2. The `payments` table enforces a `UNIQUE` constraint on `idempotency_key`.
3. Before charging, `payment-service` checks if a payment already exists for that key. If found, it returns the existing result immediately without re-processing.
4. To handle high-concurrency race conditions where two duplicate requests arrive simultaneously and bypass the read check, the database rejects the second insert with a unique constraint violation. The application traps `DataIntegrityViolationException`, fetches the concurrently saved record, and returns the original response.

---

### Q3: How is Redis used in the architecture, and how do you handle Redis failures?
**Answer:**
Redis is used for:
1. **Cache-Aside Pattern** in `restaurant-service` for frequently accessed menus and restaurant profiles with a 10-minute TTL. On cache misses, data is fetched from PostgreSQL and written to Redis. Mutations automatically update or invalidate the cache entry.
2. **Token Bucket Rate Limiting** in the API Gateway to prevent brute-force attacks on the `/api/auth/login` endpoint.

**Failure Handling:**
Redis is treated as an ephemeral optimization, not a source of truth. In `restaurant-service`, all Redis reads and writes are wrapped in `try-catch` blocks. If Redis goes down, the service logs a warning and transparently falls back to direct PostgreSQL queries, ensuring zero downtime for customers browsing menus.

---

### Q4: How do you handle race conditions during delivery driver assignment?
**Answer:**
We use **Optimistic Concurrency Control** via JPA `@Version` on the `DeliveryPartner` entity in `delivery-service`.
When multiple orders try to dispatch the same `AVAILABLE` driver simultaneously:
- Both transactions read the driver at version `N`.
- The first transaction to commit issues an `UPDATE delivery_partners SET status='BUSY', version=N+1 WHERE id=? AND version=N`.
- The second transaction detects that zero rows were updated because the version has advanced, raising an `ObjectOptimisticLockingFailureException`.
- The second transaction aborts and safely rolls back, preventing double-booking.

---

### Q5: How do you handle distributed transactions and asynchronous workflows?
**Answer:**
We avoid synchronous HTTP chains and heavy two-phase commit (2PC) protocols in favor of an **Asynchronous Choreography Saga** using Apache Kafka:
1. `order-service` stores the order in `order_db` with status `PAYMENT_PENDING` and publishes a `payment.requested` event.
2. `payment-service` consumes this event, processes the transaction, and publishes `payment.completed` or `payment.failed`.
3. Both `order-service` and `notification-service` listen to these payment outcomes in separate consumer groups (demonstrating **Kafka Fan-out**).
4. Upon `payment.completed`, `order-service` transitions the order to `CONFIRMED` and publishes `order.confirmed`.
5. `delivery-service` consumes `order.confirmed` and creates a pending delivery task.

Every consumer implements event deduplication based on `eventId` to handle Kafka's at-least-once delivery guarantees safely.

---

### Q6: How does authentication and authorization work across microservices?
**Answer:**
We use a **decentralized, stateless JWT architecture**:
1. `user-service` authenticates credentials using BCrypt and issues an HMAC-SHA256 JWT containing `userId` and `role` claims.
2. The API Gateway forwards the `Authorization: Bearer <token>` header transparently to downstream services without calling `user-service`.
3. Each microservice uses a local `JwtAuthenticationFilter` to cryptographically verify the token signature and expiration, populating Spring Security's `SecurityContextHolder`.
4. Endpoints enforce Role-Based Access Control via `@PreAuthorize`.
5. Service layers explicitly verify **resource ownership** (e.g., verifying that a restaurant owner only modifies restaurants they own) and reject cross-tenant access with **HTTP 403 Forbidden**.
