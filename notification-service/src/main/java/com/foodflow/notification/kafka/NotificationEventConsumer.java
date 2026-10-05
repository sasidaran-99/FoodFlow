package com.foodflow.notification.kafka;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.foodflow.notification.event.PaymentCompletedEvent;
import com.foodflow.notification.event.PaymentFailedEvent;
import com.foodflow.notification.service.NotificationService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.stereotype.Component;

@Slf4j
@Component
@RequiredArgsConstructor
public class NotificationEventConsumer {

    private final NotificationService notificationService;
    private final ObjectMapper objectMapper;

    @KafkaListener(topics = "payment.completed", groupId = "notification-service-group")
    public void consumePaymentCompleted(String payload) {
        try {
            PaymentCompletedEvent event = objectMapper.readValue(payload, PaymentCompletedEvent.class);
            log.info("Notification Service received PaymentCompletedEvent for orderId: {}", event.getOrderId());
            notificationService.processPaymentCompleted(event);
        } catch (Exception e) {
            log.error("Error processing PaymentCompletedEvent in Notification Service: {}", e.getMessage(), e);
        }
    }

    @KafkaListener(topics = "payment.failed", groupId = "notification-service-group")
    public void consumePaymentFailed(String payload) {
        try {
            PaymentFailedEvent event = objectMapper.readValue(payload, PaymentFailedEvent.class);
            log.info("Notification Service received PaymentFailedEvent for orderId: {}", event.getOrderId());
            notificationService.processPaymentFailed(event);
        } catch (Exception e) {
            log.error("Error processing PaymentFailedEvent in Notification Service: {}", e.getMessage(), e);
        }
    }
}
