package com.foodflow.delivery.kafka;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.foodflow.delivery.event.OrderConfirmedEvent;
import com.foodflow.delivery.service.DeliveryService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.stereotype.Component;

@Slf4j
@Component
@RequiredArgsConstructor
public class DeliveryEventConsumer {

    private final DeliveryService deliveryService;
    private final ObjectMapper objectMapper;

    @KafkaListener(topics = "order.confirmed", groupId = "delivery-service-group")
    public void consumeOrderConfirmed(String payload) {
        try {
            OrderConfirmedEvent event = objectMapper.readValue(payload, OrderConfirmedEvent.class);
            log.info("Delivery Service received OrderConfirmedEvent for orderId: {}", event.getOrderId());
            deliveryService.processOrderConfirmed(event);
        } catch (Exception e) {
            log.error("Error processing OrderConfirmedEvent: {}", e.getMessage(), e);
        }
    }
}
