package com.foodflow.order.service;

import com.foodflow.order.event.PaymentRequestedEvent;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Component;

@Slf4j
@Component
@RequiredArgsConstructor
public class OrderEventPublisher {

    private final KafkaTemplate<String, Object> kafkaTemplate;

    public void publishPaymentRequested(PaymentRequestedEvent event) {
        log.info("Publishing PaymentRequestedEvent for orderId: {}", event.getOrderId());
        kafkaTemplate.send("payment.requested", String.valueOf(event.getOrderId()), event);
    }

    public void publishOrderConfirmed(Long orderId, Long restaurantId) {
        com.foodflow.order.event.OrderConfirmedEvent event = com.foodflow.order.event.OrderConfirmedEvent.builder()
                .eventId(java.util.UUID.randomUUID().toString())
                .orderId(orderId)
                .restaurantId(restaurantId)
                .timestamp(java.time.LocalDateTime.now())
                .build();
        log.info("Publishing OrderConfirmedEvent for orderId: {}", orderId);
        kafkaTemplate.send("order.confirmed", String.valueOf(orderId), event);
    }
}
