package com.foodflow.order.event;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data @Builder @NoArgsConstructor @AllArgsConstructor
public class PaymentRequestedEvent {
    private String eventId;
    private Long orderId;
    private Long userId;
    private BigDecimal amount;
    private String idempotencyKey;
    private LocalDateTime timestamp;
}