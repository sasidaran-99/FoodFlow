# Concurrency & Idempotency in FoodFlow

Handling concurrent requests safely and preventing duplicate operations are foundational requirements of distributed backend architectures. FoodFlow implements concurrency control and idempotency using standard, interview-defensible patterns.

---

## 1. Optimistic Locking on Driver Dispatch (`delivery-service`)

### The Problem
During peak hours, multiple order fulfillment requests may attempt to dispatch the same `AVAILABLE` delivery partner simultaneously. A naive `read -> update` flow without locking would result in double-booking the driver for two different orders.

### The Solution: JPA `@Version`
In `delivery-service`, the `DeliveryPartner` entity includes a version column managed by Hibernate:

```java
@Entity
@Table(name = "delivery_partners")
public class DeliveryPartner {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Enumerated(EnumType.STRING)
    private PartnerStatus status; // AVAILABLE, BUSY, OFFLINE

    @Version
    private Long version;
}
```

### Execution Flow
```
Driver Status: AVAILABLE (version: 1)
      │
      ├─── Request A: Reads driver (version 1)
      │    Request B: Reads driver (version 1)
      │
      ├─── Request A executes:
      │    UPDATE delivery_partners SET status='BUSY', version=2 
      │    WHERE id=10 AND version=1;
      │    ==> 1 ROW UPDATED (SUCCESS)
      │
      └─── Request B executes:
           UPDATE delivery_partners SET status='BUSY', version=2 
           WHERE id=10 AND version=1;
           ==> 0 ROWS UPDATED (CONFLICT DETECTED)
           ==> Throws ObjectOptimisticLockingFailureException
           ==> Request B safely aborts assignment and rolls back
```

> [!IMPORTANT]
> Optimistic locking is implemented on **`DeliveryPartner`** in `delivery-service`. FoodFlow does **not** implement menu item stock or inventory count locking.

---

## 2. PostgreSQL-Backed Payment Idempotency (`payment-service`)

### The Problem
Network timeouts or double-clicks can cause a client to send the same payment request twice. In a payment processing system, duplicate requests must never result in duplicate charges.

### The Solution: Database Constraint + Exception Trapping
FoodFlow implements idempotency entirely within PostgreSQL (`payment_db`):

1. **Client Submission:** The client submits a unique token in the request header:
   `Idempotency-Key: pay-key-12345`
2. **Schema Constraint:** The `payments` table defines a strict `UNIQUE` constraint on the `idempotency_key` column.
3. **Application Verification:**
   - **Step 1:** `paymentService` checks if `paymentRepository.findByIdempotencyKey(idempotencyKey)` exists. If found, it returns the existing payment response without re-processing.
   - **Step 2 (Race Condition Defense):** If two concurrent requests with the identical key bypass the initial read simultaneously, the database unique constraint blocks the second insert and raises a `DataIntegrityViolationException`.
   - **Step 3:** The service catches `DataIntegrityViolationException`, fetches the concurrently saved record, and returns the existing payment DTO.

```java
try {
    Payment savedPayment = paymentRepository.saveAndFlush(payment);
    publishEventForPayment(savedPayment);
    return mapToDto(savedPayment);
} catch (DataIntegrityViolationException e) {
    log.warn("Concurrent payment attempt detected for idempotency key: {}", idempotencyKey);
    Payment concurrentPayment = paymentRepository.findByIdempotencyKey(idempotencyKey)
            .orElseThrow(() -> new RuntimeException("Failed to fetch concurrent payment record"));
    return mapToDto(concurrentPayment);
}
```

---

## 3. Kafka Consumer Event Idempotency

Kafka provides **at-least-once** delivery guarantees. Network reconnects or broker rebalances may deliver the same event more than once.

- **`delivery-service`:** Verifies if a delivery already exists for `event.getEventId()` before creating a record; catches `DataIntegrityViolationException` on unique constraint.
- **`notification-service`:** Deduplicates incoming alerts using a `UNIQUE` constraint on `event_id` in the `notifications` table.
- **`order-service`:** Records processed event IDs in the `processed_events` table before applying state updates.
