# API Gateway & Edge Architecture

## 1. Why do we need an API Gateway?
In a microservices architecture without a gateway, the frontend client would need to know the IP address, port, and URL of every single microservice (`8081`, `8082`, etc.). This causes:
- **Tight Coupling:** Frontend breaks if backend IPs/ports change.
- **Security Risks:** All internal microservices are exposed directly to the public internet.
- **Complexity:** The frontend must manage CORS, rate limiting, and timeouts for 6 different services.

The **API Gateway** solves this by acting as a single entry point (Reverse Proxy). The client only talks to the Gateway (`:8080`), and the Gateway routes the request to the appropriate internal service.

## 2. API Gateway vs Load Balancer vs Service Discovery
- **Load Balancer (e.g., AWS ALB, NGINX):** Distributes network traffic across multiple servers blindly based on algorithms like Round Robin.
- **Service Discovery (e.g., Eureka, Consul):** A registry that keeps track of dynamic internal IPs (e.g., if we scale `order-service` to 5 instances, where are they?).
- **API Gateway (e.g., Spring Cloud Gateway):** Understands Layer 7 (HTTP) protocols. It inspects the URL path (`/api/orders`) and actively routes it. It also handles cross-cutting concerns like Authentication, Rate Limiting, and Request Transformation.

*Note: In a production system, the API Gateway often talks to Service Discovery to figure out where to route traffic. For this local project phase, we hardcoded URLs for simplicity.*

## 3. JWT Forwarding and Authorization Boundaries
Does the Gateway validate JWTs? 
In this architecture, **No.** The gateway simply routes the request and forwards the `Authorization: Bearer <JWT>` header to downstream services.
- **Why?** If the Gateway enforced authorization, it would need to know all business logic (e.g., "Is this user a Restaurant Owner? Does this user own *this specific* restaurant?"). That violates the Single Responsibility Principle. 
- **Pattern:** The Gateway manages *routing* and *edge security* (Rate Limiting, CORS). Downstream services (`user-service`, `order-service`) maintain their own JWT validation filters and role-based access control.

## 4. Correlation IDs
In a distributed system, a single user request might span 4 microservices. If an error occurs, finding the related logs across 4 different servers is a nightmare.
- **Solution:** We implemented a `CorrelationIdFilter`. When a request hits the Gateway, it generates a unique UUID (`X-Correlation-Id`).
- This ID is passed in the HTTP headers to all downstream services.
- The downstream services extract this ID and include it in their logging contexts (MDC).
- Now, you can search Kibana/Splunk for `abc-123` and see the exact lifecycle of the request across the Gateway, Order Service, Kafka, and Delivery Service.

## 5. Rate Limiting
Public endpoints (like `/api/auth/login`) are vulnerable to brute-force attacks. 
We implemented a **Redis-backed Token Bucket Rate Limiter** on the login route.
- If a user/IP sends > 10 requests rapidly, the Gateway instantly returns `429 Too Many Requests`.
- **Why Redis?** Because if we have 3 instances of the API Gateway running, they need a centralized, fast, shared memory store to track IP request counts accurately.

## 6. Timeouts & Failure Handling
- **Gateway Timeouts:** We configured a global response timeout of `5s`. If `order-service` hangs indefinitely due to a database deadlock, the Gateway will cut the connection and return a `504 Gateway Timeout` to the client instead of tying up frontend resources.
- **Unavailable Services:** If `restaurant-service` crashes, the Gateway fails to route and returns a `503 Service Unavailable`.
- **Kafka:** We do **NOT** route Kafka traffic through the Gateway. Kafka is strictly internal async infrastructure.

## 7. Trade-offs
- **Pros:** Simplifies client logic, centralizes cross-cutting concerns, hides internal network architecture.
- **Cons:** Introduces a Single Point of Failure (SPOF) and an extra network hop (slightly higher latency). The Gateway itself must be highly available.
