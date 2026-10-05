package com.foodflow.payment.service;

import com.foodflow.payment.event.PaymentCompletedEvent;
import com.foodflow.payment.event.PaymentFailedEvent;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Component;

@Slf4j
@Component
@RequiredArgsConstructor
public class PaymentEventPublisher {

    private final KafkaTemplate<String, Object> kafkaTemplate;

    public void publishPaymentCompleted(PaymentCompletedEvent event) {
        log.info("Publishing PaymentCompletedEvent for orderId: {}", event.getOrderId());
        kafkaTemplate.send("payment.completed", String.valueOf(event.getOrderId()), event);
    }

    public void publishPaymentFailed(PaymentFailedEvent event) {
        log.info("Publishing PaymentFailedEvent for orderId: {}", event.getOrderId());
        kafkaTemplate.send("payment.failed", String.valueOf(event.getOrderId()), event);
    }
}
