package com.foodflow.notification.event;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data @Builder @NoArgsConstructor @AllArgsConstructor
public class PaymentFailedEvent {
    private String eventId;
    private Long orderId;
    private Long userId;
    private Long paymentId;
    private BigDecimal amount;
    private String failureReason;
    private LocalDateTime timestamp;
}
