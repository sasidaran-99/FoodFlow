package com.foodflow.gateway.filter;

import lombok.extern.slf4j.Slf4j;
import org.springframework.cloud.gateway.filter.GatewayFilterChain;
import org.springframework.cloud.gateway.filter.GlobalFilter;
import org.springframework.core.Ordered;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ServerWebExchange;
import reactor.core.publisher.Mono;

@Slf4j
@Component
public class LoggingFilter implements GlobalFilter, Ordered {

    private static final String CORRELATION_ID_HEADER = "X-Correlation-Id";

    @Override
    public Mono<Void> filter(ServerWebExchange exchange, GatewayFilterChain chain) {
        String correlationId = exchange.getRequest().getHeaders().getFirst(CORRELATION_ID_HEADER);
        String method = exchange.getRequest().getMethod().name();
        String path = exchange.getRequest().getURI().getPath();

        log.info("Incoming request: [{}] {} {} - Routed to API Gateway", correlationId, method, path);

        return chain.filter(exchange).then(Mono.fromRunnable(() -> {
            var statusCode = exchange.getResponse().getStatusCode();
            log.info("Outgoing response: [{}] {} {} - Status: {}", correlationId, method, path, statusCode);
        }));
    }

    @Override
    public int getOrder() {
        return 0; // Execute right after CorrelationIdFilter
    }
}
