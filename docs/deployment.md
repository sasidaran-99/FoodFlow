# Deployment

## Docker
Every microservice is containerized using Docker. This ensures consistency across development, testing, and production environments.

## Docker Compose
For local development, we use Docker Compose to spin up the entire ecosystem with a single command:
```bash
docker-compose up -d
```
This starts:
- PostgreSQL databases
- Redis
- Kafka & Zookeeper
- All Spring Boot Microservices
- React Frontend

## Production (Future)
In production, these containers would be orchestrated using Kubernetes.
