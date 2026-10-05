package com.foodflow.order.event;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data @Builder @NoArgsConstructor @AllArgsConstructor
public class PaymentCompletedEvent {
    private String eventId;
    private Long orderId;
    private Long paymentId;
    private BigDecimal amount;
    private String status;
    private LocalDateTime timestamp;
}