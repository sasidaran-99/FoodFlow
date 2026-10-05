package com.foodflow.order.service;

import com.foodflow.order.event.PaymentCompletedEvent;
import com.foodflow.order.event.PaymentFailedEvent;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.stereotype.Component;

@Slf4j
@Component
@RequiredArgsConstructor
public class PaymentEventConsumer {

    private final OrderService orderService;
    private final com.fasterxml.jackson.databind.ObjectMapper objectMapper;

    @KafkaListener(topics = "payment.completed", groupId = "order-service-payment-group")
    public void consumePaymentCompleted(String payload) {
        try {
            PaymentCompletedEvent event = objectMapper.readValue(payload, PaymentCompletedEvent.class);
            log.info("Received PaymentCompletedEvent for orderId: {}", event.getOrderId());
            orderService.handlePaymentCompleted(event);
        } catch (Exception e) {
            log.error("Error processing PaymentCompletedEvent: {}", e.getMessage());
        }
    }

    @KafkaListener(topics = "payment.failed", groupId = "order-service-payment-group")
    public void consumePaymentFailed(String payload) {
        try {
            PaymentFailedEvent event = objectMapper.readValue(payload, PaymentFailedEvent.class);
            log.info("Received PaymentFailedEvent for orderId: {}", event.getOrderId());
            orderService.handlePaymentFailed(event);
        } catch (Exception e) {
            log.error("Error processing PaymentFailedEvent: {}", e.getMessage());
        }
    }
}
