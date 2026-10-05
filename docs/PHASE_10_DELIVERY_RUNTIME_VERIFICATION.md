# Phase 10 — Delivery Service Runtime Verification Report

**Environment**: Local Runtime (Windows / PowerShell / Java 17 / Docker Desktop)  
**Date**: October 4, 2026  
**Service Verified**: `delivery-service` (:8086)  
**Verification Scope**: Delivery Service Only (API Gateway intentionally not started)  

---

## Executive Summary

Phase 10 local runtime verification of `delivery-service` (:8086) has been completed successfully with 100% test pass rate. The service operates completely decoupled as part of FoodFlow's event-driven architecture. It consumes `order.confirmed` events via its dedicated Kafka consumer group (`delivery-service-group`), initializes delivery records in PostgreSQL `delivery_db`, manages drivers via an authenticated API, enforces state machine invariants, and protects driver assignments against race conditions using JPA `@Version` optimistic locking.

---

## 1. Delivery Service Startup
- **Port**: `8086`
- **JVM Arguments**: `-Duser.timezone=UTC`
- **Actuator Health Endpoint**: `GET http://localhost:8086/actuator/health`
- **Runtime Response**:
  ```json
  {
    "status": "UP"
  }
  ```
- **Process Status**: Actively listening on TCP port `8086`.

---

## 2. PostgreSQL Connection
- **Datasource URL**: `jdbc:postgresql://localhost:5433/delivery_db?options=-c timezone=UTC`
- **Database User**: `foodflow`
- **Password Configuration**: `${DB_PASSWORD:password}` (dynamically resolved)
- **Connection Pool**: HikariCP initialized connection pool (`HikariPool-1`) and acquired connection `org.postgresql.jdbc.PgConnection`.
- **Dialect**: Hibernate Community Dialect `PostgreSQLDialect` with Hibernate ORM 6.5.3.Final.

---

## 3. Database-per-Service Verification (`delivery_db`)
- `delivery-service` accesses **only** `delivery_db`. It does not connect to or query `user_db`, `restaurant_db`, `order_db`, `payment_db`, or `notification_db`.
- **Tables Present in `delivery_db`**:
  1. `deliveries`:
     - `id` (bigint, PK)
     - `order_id` (bigint, NOT NULL)
     - `restaurant_id` (bigint, NOT NULL)
     - `delivery_partner_id` (bigint, NULLABLE)
     - `status` (varchar 255, CHECK constraint: `ASSIGNMENT_PENDING`, `ASSIGNED`, `PICKED_UP`, `OUT_FOR_DELIVERY`, `DELIVERED`, `CANCELLED`)
     - `event_id` (varchar 255, UNIQUE constraint `ukij9rocl995r1blxt0cxayw0t6`)
     - `version` (bigint, JPA `@Version`)
     - `created_at`, `updated_at` (timestamp with timezone UTC)
  2. `delivery_partners`:
     - `id` (bigint, PK)
     - `name` (varchar 255, NOT NULL)
     - `status` (varchar 255, CHECK constraint: `AVAILABLE`, `BUSY`, `OFFLINE`)
     - `version` (bigint, JPA `@Version` optimistic locking)

---

## 4. Kafka Connection
- **Bootstrap Servers**: `localhost:9092`
- **Cluster ID**: `iF0MpKl1SlGcu-bH2yvuhw`
- **Group Coordinator**: Discovered coordinator `localhost:9092` (id: 2147483646).

---

## 5. Kafka Consumer Group
- **Consumer Group ID**: `delivery-service-group`
- **Partition Assignment**: `[order.confirmed-0]`
- **Offset Reset Policy**: `earliest`
- **Consumer Client ID**: `consumer-delivery-service-group-1`

---

## 6. JWT Verification
- **JWT Secret**: Environment-based `${JWT_SECRET}`.
- **Filter**: `JwtAuthenticationFilter` intercepts requests, decodes Base64 HMAC SHA secret key, validates signature and expiration, extracts `userId` and `role`, and populates `SecurityContextHolder`.
- **Stateless**: Operates completely decentralized without synchronous RPC calls to `user-service`.

---

## 7. RBAC Verification
The security model was tested across multiple user roles registered via `user-service`:
- **CUSTOMER** (`deliv_cust`):
  - `POST /api/deliveries/1/assign` &rarr; **403 Forbidden** (Requires `ROLE_DELIVERY_PARTNER`)
  - `POST /api/deliveries/partners` &rarr; **403 Forbidden** (Requires `ROLE_ADMIN`)
- **RESTAURANT_OWNER** (`deliv_owner`):
  - `POST /api/deliveries/1/assign` &rarr; **403 Forbidden** (Requires `ROLE_DELIVERY_PARTNER`)
- **DELIVERY_PARTNER** (`deliv_partner`):
  - `POST /api/deliveries/{id}/assign` &rarr; **200 OK** (Permitted)
  - `PATCH /api/deliveries/{id}/status` &rarr; **200 OK** (Permitted)
- **ADMIN** (`deliv_admin`):
  - `POST /api/deliveries/partners?name=...` &rarr; **200 OK** (Permitted)
  - `PATCH /api/deliveries/{id}/status` &rarr; **200 OK** (Permitted)
- **Hardcoded Identity Check**: Zero instances of `1L` bypass or hardcoded user IDs found.

---

## 8. `order.confirmed` Event Consumption
- Legitimate end-to-end order flow executed:
  `Customer` &rarr; `order-service` &rarr; `payment.requested` &rarr; `payment-service` &rarr; `payment.completed` &rarr; `order-service` &rarr; `CONFIRMED` &rarr; `order.confirmed` &rarr; `delivery-service`.
- `delivery-service` received event:
  ```
  INFO ... c.f.d.kafka.DeliveryEventConsumer : Delivery Service received OrderConfirmedEvent for orderId: 20
  ```

---

## 9. Delivery Creation
- Upon receiving `OrderConfirmedEvent` for Order 20:
  - Database record created in `delivery_db.deliveries`:
    - **ID**: `7`
    - **Order ID**: `20`
    - **Restaurant ID**: `14`
    - **Delivery Partner ID**: `null`
    - **Status**: `ASSIGNMENT_PENDING`
    - **Version**: `0`
    - **Event ID**: `1c27b8c8-b6b4-4b51-b291-2308eab5732f`
- Verified via REST API `GET /api/deliveries/order/20` &rarr; returned delivery with status `ASSIGNMENT_PENDING`.

---

## 10. Driver Creation
- Admin invoked `POST /api/deliveries/partners?name=ExpressDriver_...`
- Response & Database Verification:
  - **ID**: `2`
  - **Name**: `ExpressDriver_...`
  - **Status**: `AVAILABLE`
  - **Version**: `0`
- Persisted in `delivery_db.delivery_partners` without manual SQL insertion.

---

## 11. Driver Assignment
- Delivery Partner invoked `POST /api/deliveries/7/assign`.
- Results:
  - Delivery ID 7 transitioned from `ASSIGNMENT_PENDING` &rarr; `ASSIGNED`.
  - `delivery_partner_id` populated with driver ID `2`.
  - Delivery Partner ID 2 status updated from `AVAILABLE` &rarr; `BUSY`.
  - Delivery Partner entity version incremented to `1`.
  - `delivery-service` published `delivery.events` Kafka event (`status: assigned`).

---

## 12. State Machine Verification
Tested sequential forward transitions on Delivery 7:
1. `ASSIGNMENT_PENDING` &rarr; `ASSIGNED` (`POST /api/deliveries/7/assign`) &rarr; **200 OK**
2. `ASSIGNED` &rarr; `PICKED_UP` (`PATCH /api/deliveries/7/status?status=PICKED_UP`) &rarr; **200 OK**
3. `PICKED_UP` &rarr; `OUT_FOR_DELIVERY` (`PATCH /api/deliveries/7/status?status=OUT_FOR_DELIVERY`) &rarr; **200 OK**
4. `OUT_FOR_DELIVERY` &rarr; `DELIVERED` (`PATCH /api/deliveries/7/status?status=DELIVERED`) &rarr; **200 OK**
- At each step, HTTP response and PostgreSQL database row reflected the correct status.

---

## 13. Invalid State Transition Tests
1. **From Terminal State (`DELIVERED`)**:
   - `DELIVERED` &rarr; `OUT_FOR_DELIVERY` &rarr; **400 Bad Request** (`"Delivery is in terminal state: DELIVERED"`)
   - `DELIVERED` &rarr; `PICKED_UP` &rarr; **400 Bad Request** (`"Delivery is in terminal state: DELIVERED"`)
2. **From Non-Terminal State (`ASSIGNMENT_PENDING`)**:
   - `ASSIGNMENT_PENDING` &rarr; `OUT_FOR_DELIVERY` (skipping `ASSIGNED` & `PICKED_UP`) &rarr; **400 Bad Request** (`"Invalid state transition from ASSIGNMENT_PENDING to OUT_FOR_DELIVERY"`)
   - `ASSIGNMENT_PENDING` &rarr; `DELIVERED` &rarr; **400 Bad Request** (`"Invalid state transition from ASSIGNMENT_PENDING to DELIVERED"`)

---

## 14. Terminal State Behavior
- Once status reached `DELIVERED`:
  - `delivery-service` automatically looked up the assigned driver (ID 2) and restored status to `AVAILABLE`.
  - Database row verified in PostgreSQL: `status = AVAILABLE`, `version = 2`.
  - Terminal state cannot be modified further.

---

## 15. Optimistic Locking / Concurrency Test
- **Setup**:
  - Exactly **1** driver was set to `AVAILABLE`: `SoloContender` (ID: 3, version: 0).
  - Two unassigned deliveries were created in `ASSIGNMENT_PENDING` status: Delivery 8 and Delivery 9.
- **Action**:
  - Two concurrent asynchronous requests fired simultaneously to assign a driver:
    - Thread 1: `POST /api/deliveries/8/assign`
    - Thread 2: `POST /api/deliveries/9/assign`
- **Observed Runtime Behavior**:
  - **Thread 1 (Delivery 8)**: `SUCCESS:3` (Assigned driver 3, version incremented from 0 to 1).
  - **Thread 2 (Delivery 9)**: `FAILED:400: Bad Request` (Rejected due to concurrent modification / driver already busy).
- **Database Verification**:
  - PostgreSQL query: `SELECT count(*) FROM deliveries WHERE delivery_partner_id = 3;` returned exactly **1**.
  - Driver 3 was assigned **only** to Delivery 8.
  - Delivery 9 remained in `ASSIGNMENT_PENDING` without double-booking.
  - Concurrency safety verified via JPA `@Version` optimistic locking without global synchronizations.

---

## 16. Kafka Idempotency Test
- Replayed identical `OrderConfirmedEvent` with existing `eventId: 1c27b8c8-b6b4-4b51-b291-2308eab5732f` to topic `order.confirmed`.
- **Pre-check**: Exactly 1 delivery with that `event_id`.
- **Post-check**: Exactly 1 delivery with that `event_id`.
- Duplicate event was recognized and safely ignored (`existsByEventId` and unique database constraint).

---

## 17. Kafka Fan-Out Verification
- Kafka consumer groups operating simultaneously:
  - `order-service-payment-group` (listens to payment events)
  - `notification-service-group` (listens to payment events)
  - `delivery-service-group` (listens to `order.confirmed`)
- `order-service` and `delivery-service` maintain independent partition offsets on Kafka broker `localhost:9092`. Neither service dropped or stole events.

---

## 18. Failure / Resilience Check (Stop & Recovery Test)
- **Objective**: Verify that `order-service` does not synchronously depend on `delivery-service` and that Kafka retains events for delivery upon recovery.
- **Execution**:
  1. `delivery-service` was stopped completely (process killed, port 8086 closed).
  2. Customer placed Order 23 via `order-service`. Payment completed and `order-service` confirmed the order (`CONFIRMED`).
  3. Confirmed that `order-service` executed with **200 OK** and did not fail or block, proving complete architectural decoupling.
  4. Verified `delivery_db`: deliveries count for Order 23 was **0**.
  5. `delivery-service` was restarted on port 8086.
  6. Upon startup, `delivery-service-group` re-joined the consumer group, read uncommitted offset from Kafka partition `order.confirmed-0`, and logged:
     ```
     INFO ... c.f.d.kafka.DeliveryEventConsumer : Delivery Service received OrderConfirmedEvent for orderId: 23
     INFO ... c.f.delivery.service.DeliveryService : Created delivery record for orderId: 23
     ```
  7. Verified `delivery_db`: Delivery ID 10 created for Order 23 in status `ASSIGNMENT_PENDING`.

---

## 19. API Security Tests
| Test | Credentials | Target Endpoint | Result |
| :--- | :--- | :--- | :--- |
| **Missing Header** | None | `GET /api/deliveries/1` | **403 Forbidden** |
| **Tampered Token** | Bad HMAC signature | `GET /api/deliveries/1` | **403 Forbidden** |
| **Wrong Role** | CUSTOMER token | `POST /api/deliveries/1/assign` | **403 Forbidden** |
| **Wrong Role** | RESTAURANT_OWNER token | `POST /api/deliveries/1/assign` | **403 Forbidden** |
| **Wrong Role** | CUSTOMER token | `POST /api/deliveries/partners` | **403 Forbidden** |
| **Valid Role** | DELIVERY_PARTNER token | `POST /api/deliveries/{id}/assign` | **200 OK** |
| **Valid Role** | ADMIN token | `POST /api/deliveries/partners` | **200 OK** |

---

## 20. Compilation Result
- Clean compilation executed across the complete Maven reactor:
  ```
  [INFO] Reactor Summary for FoodFlow 1.0.0-SNAPSHOT:
  [INFO] FoodFlow ........................................... SUCCESS [  0.307 s]
  [INFO] user-service ....................................... SUCCESS [  8.833 s]
  [INFO] restaurant-service ................................. SUCCESS [  5.168 s]
  [INFO] order-service ...................................... SUCCESS [  5.616 s]
  [INFO] payment-service .................................... SUCCESS [  3.020 s]
  [INFO] delivery-service ................................... SUCCESS [  3.379 s]
  [INFO] notification-service ............................... SUCCESS [  3.135 s]
  [INFO] api-gateway ........................................ SUCCESS [  2.582 s]
  [INFO] ------------------------------------------------------------------------
  [INFO] BUILD SUCCESS
  [INFO] Total time:  32.915 s
  ```

---

## 21. Files Changed
1. `delivery-service/pom.xml`: Added `spring-boot-starter-actuator`.
2. `delivery-service/src/main/resources/application.yml`: Configured `localhost:5433` and default password fallback `${DB_PASSWORD:password}`.
3. `delivery-service/src/main/java/com/foodflow/delivery/exception/GlobalExceptionHandler.java`: Added `@ExceptionHandler(AccessDeniedException.class)` returning HTTP 403 Forbidden.
4. `verify-delivery-service.ps1`: Automation verification script.

---

## 22. Remaining Issues
- **None** in `delivery-service`.

---

## Current Service Inventory
| Service | Port | Lifecycle State | Health Endpoint |
| :--- | :--- | :--- | :--- |
| **user-service** | `8081` | RUNNING | `{"status":"UP"}` |
| **restaurant-service** | `8082` | RUNNING | `{"status":"UP"}` |
| **order-service** | `8083` | RUNNING | `{"status":"UP"}` |
| **payment-service** | `8084` | RUNNING | `{"status":"UP"}` |
| **notification-service** | `8085` | RUNNING | `{"status":"UP"}` |
| **delivery-service** | `8086` | RUNNING | `{"status":"UP"}` |
| **api-gateway** | `8080` | **NOT STARTED** | (Preserved per instructions) |
