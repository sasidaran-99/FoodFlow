# Notification Service & Kafka Fan-Out

## 1. Why is Notification a Separate Microservice?
In a monolithic application, creating an order, processing a payment, and sending a notification might all happen in a single massive codebase. 
In a microservices architecture, we separate **Notification Service** to adhere to the Single Responsibility Principle. 
- **Separation of Concerns:** Formatting emails, integrating with Twilio (SMS), or interacting with Apple Push Notification Service (APNs) has nothing to do with food ordering or payments. 
- **Independent Scaling:** Sending emails over the internet is slow. We don't want a bottleneck in the notification service to consume threads in the `order-service` or `payment-service`.

## 2. Why Kafka Instead of REST?
If `order-service` called `notification-service` via REST (HTTP):
1. **Tight Coupling:** The `order-service` would need to know the IP/URL of the notification service.
2. **Synchronous Blocking:** If the email server is slow, the REST call blocks, slowing down the user's order placement.
3. **Cascading Failures:** If `notification-service` goes down, the `order-service` HTTP request fails, potentially causing the entire order to rollback!
By using **Kafka**, we completely decouple the systems. `payment-service` just announces "Payment Completed!" and forgets about it. The `notification-service` listens and processes it at its own pace.

## 3. Kafka Fan-Out and Consumer Groups
**Kafka Fan-Out** is the ability to deliver the exact same event/message to multiple independent consumers.
- The `payment-service` produces a single `payment.completed` event to Kafka.
- **Consumer Group 1 (`order-service-payment-group`)**: Listens to update the order status in `order_db`.
- **Consumer Group 2 (`notification-service-group`)**: Listens to trigger a customer email/SMS and saves to `notification_db`.

Because they use *different* Consumer Group IDs, Kafka maintains separate offset trackers for them. They independently receive their own copy of the event without stealing messages from each other.

```mermaid
flowchart TD
    P[Payment Service] -->|payment.completed| K(Kafka Topic)
    K -->|Copy 1| O[Order Service (order-group)]
    K -->|Copy 2| N[Notification Service (notification-group)]
    O --> DB1[(order_db)]
    N --> DB2[(notification_db)]
```

## 4. Failure Isolation & Eventual Consistency
**What happens if Notification Service is down?**
Absolutely nothing breaks for the user! 
If `notification-service` crashes, the `order-service` is unaffected. The user's order still transitions to `CONFIRMED`. Kafka simply holds onto the notification event. When `notification-service` restarts, its consumer group resumes from its last committed offset and consumes the backlog. This demonstrates **Failure Isolation** and **Eventual Consistency**.

## 5. Duplicate Events & Idempotency
Kafka guarantees *at-least-once* delivery, meaning network glitches can cause the same `payment.completed` event to be delivered twice.
If we didn't handle this, the customer would get spammed with two identical "Order Confirmed" emails.
**Solution:** We added a `UNIQUE` database constraint on `eventId` in the `notification_db`.
When processing, if the `eventId` already exists, we catch the constraint violation and gracefully ignore it (Idempotent Consumer). We deliberately chose PostgreSQL over Redis for this to minimize infrastructure dependencies while satisfying the requirement perfectly.

## 6. Future Expansion
Currently, the `MockNotificationSender` simply logs the message to the console. In the future, this service is naturally positioned to integrate with Amazon SES, SendGrid, or Twilio by just implementing the sender interface, without touching any other microservice.
