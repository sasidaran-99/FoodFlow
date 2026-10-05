# Redis Caching & Cache-Aside Pattern

## 1. Why Redis?
In a read-heavy system like a food delivery platform, users constantly fetch restaurant details and menus. Querying the PostgreSQL database for every read creates heavy I/O load, slow response times, and scaling bottlenecks. 
**Redis**, an in-memory key-value data store, solves this by caching frequently accessed data in RAM, offering sub-millisecond response times.

## 2. The Cache-Aside Pattern
We implemented the **Cache-Aside** (or lazy-loading) pattern for the `restaurant-service`. In this pattern, the application code is responsible for managing the cache:

1. **Read Request**: The application first asks Redis.
2. **Cache HIT**: If the data is found, it is returned immediately. (Bypasses PostgreSQL entirely).
3. **Cache MISS**: If the data is missing, the application queries PostgreSQL, stores the result in Redis, and returns the response.

## 3. Cache Keys
We use a structured, consistent naming convention to prevent key collisions:
- **`restaurant:{id}`**: Stores the `RestaurantDto` for a specific restaurant.
- **`menu:{restaurantId}`**: Stores a `List<MenuItemDto>` representing the active menu for a restaurant.

## 4. Time-To-Live (TTL)
**What it is:** A TTL is an expiration timer set on cached data. After the TTL expires (e.g., 10 minutes), Redis automatically deletes the key.
**Why it's useful:** It acts as a safety net against stale data and prevents unbounded memory growth. If we forget to explicitly invalidate a cache, the TTL ensures it eventually refreshes from the database.

## 5. Cache Invalidation
**The Problem:** If a restaurant owner updates a menu item price from ₹500 to ₹600 in PostgreSQL, the Redis cache will still serve the stale ₹500 value until the TTL expires.
**The Solution:** Explicit Cache Invalidation.
When a `CREATE`, `UPDATE`, or `DELETE` operation occurs (e.g., `updateMenuItem`), our service intercepts the write, persists the new data in PostgreSQL, and explicitly deletes or overwrites the `menu:{restaurantId}` key in Redis. The next read will trigger a Cache MISS and pull the fresh ₹600 value.

## 6. Serialization (Caching DTOs vs JPA Entities)
We serialize and cache **DTOs** (Data Transfer Objects), not **JPA Entities**.
**Why?**
- JPA entities are tied to the Hibernate Session. Caching them directly can cause `LazyInitializationException` or transactional proxy issues when deserialized.
- DTOs contain exactly what the client needs, avoiding exposing sensitive database fields (like passwords or internal IDs) in the cache layer.

## 7. Redis Failure Behavior (Resiliency)
Redis is a *cache*, not the *source of truth*. If the Redis instance crashes or becomes unavailable, the system **must not** fail. 
We explicitly wrapped the `redisTemplate.opsForValue().get(...)` calls in a `try-catch` block. If Redis throws a connection error, the service catches it, logs a warning, and seamlessly falls back to querying PostgreSQL. This ensures high availability (HA).

## 8. Idempotency vs Caching
While Redis is an excellent caching layer, it can also be used as a high-speed distributed lock for idempotency. 
Currently, our `payment-service` handles idempotency using a strict PostgreSQL `UNIQUE` constraint. This works well for our scale, but at a massive scale, hitting the database for every duplicate idempotency key is expensive. In the future, we could store idempotency keys in Redis with a short TTL to reject duplicates in-memory before they ever hit the database.

## 9. Trade-offs
- **Pros:** Massively improved read performance, reduced database load.
- **Cons:** Added architectural complexity, potential for stale data (eventual consistency), additional infrastructure to manage.
- **Cache Stampede (Thundering Herd):** If a highly requested key (like a popular restaurant) expires or is invalidated, 100 concurrent requests might all experience a Cache MISS simultaneously and hammer the database. While not addressed in this phase, standard solutions include distributed locks (only one thread fetches from DB) or probabilistic early expiration.
