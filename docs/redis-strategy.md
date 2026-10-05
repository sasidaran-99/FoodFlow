# FoodFlow Redis Strategy

Redis is utilized in FoodFlow strictly for read caching in `restaurant-service` and request rate limiting in `api-gateway`. 

> [!IMPORTANT]
> FoodFlow does **not** implement a Redis shopping cart, nor does it use Redis for payment idempotency (which is handled directly by PostgreSQL unique constraints).

---

## 1. Restaurant & Menu Cache-Aside Pattern

In `restaurant-service`, menus are frequently read but updated infrequently. To reduce database load on `restaurant_db`, queries use the **Cache-Aside** pattern.

### Read Flow
```
Client Request
      │
      ▼
Check Redis Cache ("restaurant:{id}")
      ├─── [CACHE HIT] ──► Return cached RestaurantDto immediately
      │
      └─── [CACHE MISS]
              │
              ▼
      Query PostgreSQL (`restaurant_db`)
              │
              ▼
      Store DTO in Redis with TTL (10 minutes)
              │
              ▼
      Return RestaurantDto to Client
```

### Cache Invalidation on Mutation
When a restaurant owner updates a restaurant (`PUT /api/restaurants/{id}`) or toggles operational status (`PATCH /api/restaurants/{id}/status`), the cache entry is immediately updated with the new DTO and reset with the 10-minute TTL to maintain consistency.

### Redis Failure Fallback (Resilience)
If Redis crashes or encounters network connectivity issues, `restaurant-service` gracefully catches `Exception`, logs an error, and falls back directly to PostgreSQL:

```java
try {
    Object cached = redisTemplate.opsForValue().get(key);
    if (cached != null) {
        log.info("CACHE HIT for key: {}", key);
        return (RestaurantDto) cached;
    }
} catch (Exception e) {
    log.error("Redis is unavailable, falling back to PostgreSQL for key: {}", key);
}
// Direct database read occurs if Redis fails
Restaurant restaurant = restaurantRepository.findById(id)...
```

---

## 2. API Gateway Rate Limiting

The API Gateway (`api-gateway`) uses Redis as the reactive backend for Spring Cloud Gateway's `RequestRateLimiter`:
- **Target Endpoint:** `POST /api/auth/login`
- **Algorithm:** Token Bucket
- **Key Resolver:** Client Remote IP Address (`ipKeyResolver`)
- **Replenish Rate:** 5 requests per second
- **Burst Capacity:** 10 requests

If a client exceeds this threshold, the gateway immediately rejects the request with **HTTP 429 Too Many Requests**, protecting `user-service` from brute-force authentication attacks.
