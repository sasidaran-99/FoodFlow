# FoodFlow Database Design

FoodFlow adheres strictly to the **Database-per-Service** microservices pattern. Each service connects to its own dedicated logical PostgreSQL database schema on port `5433`. Direct cross-database joins and foreign keys between services are strictly prohibited.

---

## 1. User Database (`user_db`)

### `users`
| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | BIGINT | PRIMARY KEY, AUTO_INCREMENT | Unique user identifier |
| `name` | VARCHAR(255) | NOT NULL | User's full name |
| `email` | VARCHAR(255) | NOT NULL, UNIQUE | User login email |
| `password` | VARCHAR(255) | NOT NULL | BCrypt hashed password |
| `phone` | VARCHAR(50) | NOT NULL | Contact telephone number |
| `role` | VARCHAR(50) | NOT NULL | `CUSTOMER`, `RESTAURANT_OWNER`, `DELIVERY_PARTNER`, `ADMIN` |
| `created_at`| TIMESTAMP | NOT NULL | Account creation timestamp |
| `updated_at`| TIMESTAMP | NOT NULL | Account modification timestamp |

### `addresses`
| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | BIGINT | PRIMARY KEY, AUTO_INCREMENT | Unique address identifier |
| `user_id` | BIGINT | NOT NULL, FK -> `users(id)` | Associated user |
| `street` | VARCHAR(255) | NOT NULL | Street line |
| `city` | VARCHAR(100) | NOT NULL | City name |
| `state` | VARCHAR(100) | NOT NULL | State / Province |
| `zip_code` | VARCHAR(20) | NOT NULL | Postal code |
| `country` | VARCHAR(100) | NOT NULL | Country name |

---

## 2. Restaurant Database (`restaurant_db`)

### `restaurants`
| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | BIGINT | PRIMARY KEY, AUTO_INCREMENT | Unique restaurant identifier |
| `owner_id` | BIGINT | NOT NULL | Reference to User Service `userId` |
| `name` | VARCHAR(255) | NOT NULL | Restaurant name |
| `description`| VARCHAR(255) | NOT NULL | Restaurant description |
| `address` | VARCHAR(255) | NOT NULL | Physical restaurant location |
| `is_open` | BOOLEAN | NOT NULL | Operational status |
| `created_at`| TIMESTAMP | NOT NULL | Onboarding timestamp |
| `updated_at`| TIMESTAMP | NOT NULL | Last update timestamp |

### `menu_items`
| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | BIGINT | PRIMARY KEY, AUTO_INCREMENT | Unique item identifier |
| `restaurant_id`| BIGINT | NOT NULL, FK -> `restaurants(id)` | Parent restaurant |
| `name` | VARCHAR(255) | NOT NULL | Item name |
| `description`| VARCHAR(255) | NOT NULL | Item ingredients / description |
| `price` | NUMERIC(10,2)| NOT NULL | Item price in currency |
| `is_available`| BOOLEAN | NOT NULL | Ordering availability flag |

---

## 3. Order Database (`order_db`)

### `orders`
| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | BIGINT | PRIMARY KEY, AUTO_INCREMENT | Unique order identifier |
| `user_id` | BIGINT | NOT NULL | Reference to User Service `userId` |
| `restaurant_id`| BIGINT | NOT NULL | Reference to Restaurant Service `id` |
| `status` | VARCHAR(50) | NOT NULL | State machine enum (see below) |
| `total_amount` | NUMERIC(10,2)| NOT NULL | Snapshot order sum total |
| `created_at` | TIMESTAMP | NOT NULL | Order timestamp |
| `updated_at` | TIMESTAMP | NOT NULL | Transition timestamp |

**`OrderStatus` Enum States:**
- `CREATED`, `PAYMENT_PENDING`, `CONFIRMED`, `RESTAURANT_ACCEPTED`, `PREPARING`, `READY_FOR_PICKUP`, `OUT_FOR_DELIVERY`, `DELIVERED`, `CANCELLED`, `REJECTED`, `PAYMENT_FAILED`

### `order_items`
| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | BIGINT | PRIMARY KEY, AUTO_INCREMENT | Unique order line identifier |
| `order_id` | BIGINT | NOT NULL, FK -> `orders(id)` | Parent order |
| `menu_item_id` | BIGINT | NOT NULL | Snapshot of menu item ID |
| `item_name` | VARCHAR(255) | NOT NULL | Snapshot of item title |
| `quantity` | INT | NOT NULL | Units purchased |
| `price` | NUMERIC(10,2)| NOT NULL | Snapshot unit price at purchase |

### `processed_events`
| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `event_id` | VARCHAR(255) | PRIMARY KEY | Kafka event ID for deduplication |
| `processed_at`| TIMESTAMP | NOT NULL | Processing timestamp |

---

## 4. Payment Database (`payment_db`)

### `payments`
| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | BIGINT | PRIMARY KEY, AUTO_INCREMENT | Unique payment record ID |
| `order_id` | BIGINT | NOT NULL | Reference to Order Service `orderId` |
| `user_id` | BIGINT | NULLABLE | Authenticated caller's `userId` |
| `amount` | NUMERIC(10,2)| NOT NULL | Payment transaction sum |
| `status` | VARCHAR(50) | NOT NULL | `SUCCESS`, `FAILED` |
| `idempotency_key`| VARCHAR(255) | NOT NULL, UNIQUE | Client / caller idempotency token |
| `reference_number`| VARCHAR(255) | NOT NULL | Gateway transaction reference |
| `created_at` | TIMESTAMP | NOT NULL | Payment timestamp |
| `updated_at` | TIMESTAMP | NOT NULL | Completion timestamp |

---

## 5. Notification Database (`notification_db`)

### `notifications`
| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | BIGINT | PRIMARY KEY, AUTO_INCREMENT | Unique notification identifier |
| `user_id` | BIGINT | NOT NULL | Recipient user ID |
| `order_id` | BIGINT | NOT NULL | Subject order ID |
| `type` | VARCHAR(50) | NOT NULL | `ORDER_CONFIRMED`, `PAYMENT_FAILED`, `ORDER_CANCELLED` |
| `message` | TEXT | NOT NULL | Human-readable alert payload |
| `status` | VARCHAR(50) | NOT NULL | `PENDING`, `SENT`, `FAILED` |
| `event_id` | VARCHAR(255) | NOT NULL, UNIQUE | Kafka deduplication key |
| `created_at`| TIMESTAMP | NOT NULL | Alert creation timestamp |

---

## 6. Delivery Database (`delivery_db`)

### `deliveries`
| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | BIGINT | PRIMARY KEY, AUTO_INCREMENT | Unique delivery task identifier |
| `order_id` | BIGINT | NOT NULL | Subject order ID |
| `restaurant_id`| BIGINT | NOT NULL | Pickup location identifier |
| `partner_id` | BIGINT | NULLABLE | Assigned driver ID |
| `status` | VARCHAR(50) | NOT NULL | `ASSIGNMENT_PENDING`, `ASSIGNED`, `PICKED_UP`, `OUT_FOR_DELIVERY`, `DELIVERED`, `CANCELLED` |
| `event_id` | VARCHAR(255) | NOT NULL, UNIQUE | Kafka deduplication key |
| `created_at` | TIMESTAMP | NOT NULL | Creation timestamp |
| `updated_at` | TIMESTAMP | NOT NULL | State transition timestamp |

### `delivery_partners`
| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | BIGINT | PRIMARY KEY, AUTO_INCREMENT | Unique partner identifier |
| `name` | VARCHAR(255) | NOT NULL | Driver name |
| `status` | VARCHAR(50) | NOT NULL | `AVAILABLE`, `BUSY`, `OFFLINE` |
| `version` | BIGINT | NOT NULL | **JPA `@Version` for Optimistic Locking** |

> [!NOTE]
> `delivery-service` does **not** store or query PostGIS or GPS coordinates. Driver assignment is modeled cleanly via partner availability statuses and optimistic version increments.
