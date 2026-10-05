package com.foodflow.notification.event;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class PaymentCompletedEvent {
    private String eventId;
    private Long orderId;
    private Long paymentId;
    private BigDecimal amount;
    private String status;
    private LocalDateTime timestamp;
    
    // Add userId to events in real system, but wait! Does orderId give us userId?
    // The previous events didn't have userId in PaymentCompletedEvent. 
    // They did have it in PaymentRequestedEvent.
    // Let's add userId here. Wait, if payment-service didn't send userId, it won't deserialize correctly.
    // Let's check payment-service's PaymentCompletedEvent.
}
