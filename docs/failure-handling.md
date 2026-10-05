# Failure Handling & Fault Tolerance

In a distributed microservice environment, network partitions, temporary service crashes, and database contention are inevitable. FoodFlow employs concrete, implemented resilience patterns to mitigate failures.

---

## 1. Concrete Resilience Mechanisms in FoodFlow

| Failure Scenario | Mitigation Implemented | Actual Code / Config Behavior |
| :--- | :--- | :--- |
| **Redis Outage / Unavailability** | **Cache-Aside Fallback** | `restaurant-service` catches Redis connection exceptions in a `try-catch` block and automatically falls back to direct PostgreSQL queries. |
| **Gateway Request Flooding** | **Redis Token Bucket Rate Limiting** | `api-gateway` enforces rate limits on `POST /api/auth/login` (5 req/sec, burst 10) returning `429 Too Many Requests`. |
| **Downstream Latency / Hanging Calls** | **HTTP Gateway Timeouts** | Gateway configures `connect-timeout: 2000` (2s) and `response-timeout: 5s` to terminate hanging downstream requests quickly. |
| **Duplicate Payment Submissions** | **PostgreSQL Unique Constraint** | Duplicate `Idempotency-Key` headers trigger a database unique violation, caught as `DataIntegrityViolationException` to safely return existing payment results. |
| **Concurrent Driver Assignment Collisions** | **JPA `@Version` Optimistic Locking** | Simultaneous driver dispatches raise `ObjectOptimisticLockingFailureException`, rolling back conflicting transactions and preventing double-booking. |
| **Duplicate Kafka Event Delivery** | **Event Deduplication (At-Least-Once)** | `delivery_db` and `notification_db` enforce `UNIQUE` constraints on `event_id`. Duplicate events are skipped safely. |
| **Microservice Crash** | **Database & Event Isolation** | If `delivery-service` or `notification-service` crashes, `order-service` continues processing orders. Kafka buffers events until consumers recover. |

---

## 2. What Is NOT Implemented (Honest Architecture)

To maintain clarity and defensibility during technical interviews:
- **Resilience4j:** FoodFlow does **not** currently use the Resilience4j library or circuit breaker annotations.
- **Dead-Letter Topics (DLT):** Kafka consumer factories do **not** configure automatic Dead-Letter Topic redirection. Consumer exceptions are caught and logged.
- **Distributed Two-Phase Commit:** FoodFlow deliberately avoids 2PC in favor of asynchronous Saga Choreography.
