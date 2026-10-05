# Delivery Service & Concurrency Control

## 1. Why is Delivery a Separate Microservice?
In a monolithic system, order placement, payment, and delivery assignment are entangled.
In a distributed microservices architecture, **Delivery Service** is independent because it has a fundamentally different bounded context. Its primary domain concepts (Delivery Partners, Geographic dispatch, Vehicle Tracking, Route Optimization) have no relation to Restaurant Menus or Payment Gateways.
Separating it allows the delivery team to deploy updates, scale infrastructure, and manage resources independently of the order ingestion pipeline.

## 2. Why Database-per-Service?
We provisioned an isolated PostgreSQL database (`delivery_db`). The Delivery Service cannot query `order_db` directly.
- **Why?** If the Delivery Service reached directly into `order_db`, any change to the Order database schema would break the Delivery Service (tight coupling).
- Instead, the Delivery Service maintains its own projection of the data it needs via Kafka events.

## 3. Kafka & Eventual Consistency
The `order-service` does not make a synchronous HTTP/REST call to `delivery-service`.
Instead, when an order is paid and confirmed, `order-service` publishes an `order.confirmed` event to Kafka.
The `delivery-service` asynchronously consumes this event and creates a Delivery record in the `ASSIGNMENT_PENDING` state.
- **Eventual Consistency**: There is a brief window where an Order is `CONFIRMED`, but the Delivery record doesn't exist yet. The system is "eventually consistent".
- **Failure Isolation**: If `delivery-service` is down, the user still successfully places the order! Kafka buffers the event until `delivery-service` recovers.

## 4. Idempotency
Because Kafka guarantees *at-least-once* delivery, the `order.confirmed` event might be delivered twice during network blips.
To prevent creating two duplicate deliveries for the same order, we use **Idempotent processing**. The `Delivery` entity stores the unique Kafka `eventId`. We added a `UNIQUE` constraint to the `eventId` column in PostgreSQL. The second delivery attempt throws a database error, which we catch and safely ignore.

## 5. Driver Assignment & Optimistic Locking
When assigning a delivery partner, two concurrent requests might try to assign the exact same `AVAILABLE` driver simultaneously.
To prevent this concurrency bug, we use **Optimistic Locking** (`@Version` in JPA).
- **How it works**: The `DeliveryPartner` entity has a `version` column. When Thread A and Thread B both fetch Driver John, they both see `version=1`.
- Thread A sets John to `BUSY` and saves. Hibernate executes: `UPDATE delivery_partners SET status='BUSY', version=2 WHERE id=1 AND version=1`. This succeeds.
- Thread B attempts to save. Hibernate executes: `UPDATE delivery_partners SET status='BUSY', version=2 WHERE id=1 AND version=1`. This **fails** because the version in the database is now 2. 
- Thread B receives an `ObjectOptimisticLockingFailureException`, preventing the double-assignment.

## 6. The Delivery State Machine
The lifecycle of a delivery is strictly guarded.
Valid transitions: `ASSIGNMENT_PENDING -> ASSIGNED -> PICKED_UP -> OUT_FOR_DELIVERY -> DELIVERED`
If an API request attempts to jump from `DELIVERED` back to `OUT_FOR_DELIVERY`, the State Machine explicitly rejects it, maintaining data integrity.
