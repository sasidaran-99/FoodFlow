package com.foodflow.delivery.kafka;

import com.foodflow.delivery.event.DeliveryEvent;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Component;

import java.time.LocalDateTime;
import java.util.UUID;

@Slf4j
@Component
@RequiredArgsConstructor
public class DeliveryEventPublisher {

    private final KafkaTemplate<String, Object> kafkaTemplate;

    public void publishDeliveryEvent(Long deliveryId, Long orderId, String status) {
        DeliveryEvent event = DeliveryEvent.builder()
                .eventId(UUID.randomUUID().toString())
                .deliveryId(deliveryId)
                .orderId(orderId)
                .status(status)
                .timestamp(LocalDateTime.now())
                .build();

        String topic = "delivery." + status.toLowerCase(); // delivery.assigned, delivery.picked_up, etc.

        try {
            kafkaTemplate.send(topic, event);
            log.info("Published {} event for deliveryId: {}", topic, deliveryId);
        } catch (Exception e) {
            log.error("Failed to publish {} event for deliveryId: {}", topic, deliveryId, e);
        }
    }
}
