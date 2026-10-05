package com.foodflow.payment.service;

import com.foodflow.payment.dto.PaymentRequest;
import com.foodflow.payment.event.PaymentRequestedEvent;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.stereotype.Component;

@Slf4j
@Component
@RequiredArgsConstructor
public class OrderEventConsumer {

    private final PaymentService paymentService;
    private final com.fasterxml.jackson.databind.ObjectMapper objectMapper;

    @KafkaListener(topics = "payment.requested", groupId = "payment-service-request-group")
    public void consumePaymentRequested(String payload) {
        try {
            PaymentRequestedEvent event = objectMapper.readValue(payload, PaymentRequestedEvent.class);
            log.info("Received PaymentRequestedEvent for orderId: {}, idempotencyKey: {}", event.getOrderId(), event.getIdempotencyKey());
            
            PaymentRequest request = new PaymentRequest();
            request.setOrderId(event.getOrderId());
            request.setAmount(event.getAmount());
            
            String idempotencyKey = event.getIdempotencyKey() != null ? event.getIdempotencyKey() : event.getEventId();
            paymentService.processPayment(request, idempotencyKey, event.getUserId());
        } catch (Exception e) {
            log.error("Error processing payment request from Kafka: {}", e.getMessage());
        }
    }
}
