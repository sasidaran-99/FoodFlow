package com.foodflow.payment.dto;

import com.foodflow.payment.entity.PaymentStatus;
import lombok.Builder;
import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data
@Builder
public class PaymentResponse {
    private Long id;
    private Long orderId;
    private Long userId;
    private BigDecimal amount;
    private PaymentStatus status;
    private String referenceNumber;
    private String idempotencyKey;
    private LocalDateTime createdAt;
}
