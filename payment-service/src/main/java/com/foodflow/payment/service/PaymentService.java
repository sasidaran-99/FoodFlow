package com.foodflow.payment.service;

import com.foodflow.payment.dto.PaymentRequest;
import com.foodflow.payment.dto.PaymentResponse;
import com.foodflow.payment.entity.Payment;
import com.foodflow.payment.entity.PaymentStatus;
import com.foodflow.payment.event.PaymentCompletedEvent;
import com.foodflow.payment.event.PaymentFailedEvent;
import com.foodflow.payment.exception.ResourceNotFoundException;
import com.foodflow.payment.repository.PaymentRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.Optional;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class PaymentService {

    private final PaymentRepository paymentRepository;
    private final PaymentEventPublisher eventPublisher;

    @Transactional
    public PaymentResponse processPayment(PaymentRequest request, String idempotencyKey, Long userId) {
        
        Optional<Payment> existingPayment = paymentRepository.findByIdempotencyKey(idempotencyKey);
        if (existingPayment.isPresent()) {
            log.info("Idempotency match found for key: {}", idempotencyKey);
            publishEventForPayment(existingPayment.get());
            return mapToDto(existingPayment.get());
        }

        PaymentStatus status = PaymentStatus.SUCCESS;
        if (request.getAmount().compareTo(new BigDecimal("5000")) > 0) {
            status = PaymentStatus.FAILED;
        }

        Payment payment = Payment.builder()
                .orderId(request.getOrderId())
                .userId(userId)
                .amount(request.getAmount())
                .status(status)
                .idempotencyKey(idempotencyKey)
                .referenceNumber("PAY-" + UUID.randomUUID().toString().substring(0, 8).toUpperCase())
                .build();

        try {
            Payment savedPayment = paymentRepository.saveAndFlush(payment);
            publishEventForPayment(savedPayment);
            return mapToDto(savedPayment);
        } catch (DataIntegrityViolationException e) {
            log.warn("Concurrent payment attempt detected for idempotency key: {}", idempotencyKey);
            Payment concurrentPayment = paymentRepository.findByIdempotencyKey(idempotencyKey)
                    .orElseThrow(() -> new RuntimeException("Failed to fetch concurrent payment record"));
            publishEventForPayment(concurrentPayment);
            return mapToDto(concurrentPayment);
        }
    }

    @Transactional
    public PaymentResponse processPayment(PaymentRequest request, String idempotencyKey) {
        return processPayment(request, idempotencyKey, null);
    }

    private void publishEventForPayment(Payment payment) {
        if (payment.getStatus() == PaymentStatus.SUCCESS) {
            eventPublisher.publishPaymentCompleted(PaymentCompletedEvent.builder()
                    .eventId(UUID.randomUUID().toString())
                    .orderId(payment.getOrderId())
                    .userId(payment.getUserId())
                    .paymentId(payment.getId())
                    .amount(payment.getAmount())
                    .status("SUCCESS")
                    .timestamp(LocalDateTime.now())
                    .build());
        } else {
            eventPublisher.publishPaymentFailed(PaymentFailedEvent.builder()
                    .eventId(UUID.randomUUID().toString())
                    .orderId(payment.getOrderId())
                    .userId(payment.getUserId())
                    .paymentId(payment.getId())
                    .amount(payment.getAmount())
                    .failureReason("Declined due to mock rules or limit")
                    .timestamp(LocalDateTime.now())
                    .build());
        }
    }

    public PaymentResponse getPaymentByOrderId(Long orderId, Long authenticatedUserId, boolean isAdmin) {
        Payment payment = paymentRepository.findFirstByOrderIdOrderByCreatedAtDesc(orderId)
                .orElseThrow(() -> new ResourceNotFoundException("Payment not found for order ID: " + orderId));
        if (!isAdmin && payment.getUserId() != null && !payment.getUserId().equals(authenticatedUserId)) {
            log.warn("Unauthorized payment lookup: caller {} does not own order {}", authenticatedUserId, orderId);
            throw new org.springframework.security.access.AccessDeniedException("Access denied: You do not own this order's payment");
        }
        return mapToDto(payment);
    }

    public PaymentResponse getPaymentByOrderId(Long orderId) {
        return getPaymentByOrderId(orderId, null, true);
    }

    public PaymentResponse getPayment(Long id, Long authenticatedUserId, boolean isAdmin) {
        Payment payment = paymentRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Payment not found with ID: " + id));
        if (!isAdmin && payment.getUserId() != null && !payment.getUserId().equals(authenticatedUserId)) {
            log.warn("Unauthorized payment lookup: caller {} does not own payment {}", authenticatedUserId, id);
            throw new org.springframework.security.access.AccessDeniedException("Access denied: You do not own this payment");
        }
        return mapToDto(payment);
    }

    public PaymentResponse getPayment(Long id) {
        return getPayment(id, null, true);
    }

    private PaymentResponse mapToDto(Payment payment) {
        return PaymentResponse.builder()
                .id(payment.getId())
                .orderId(payment.getOrderId())
                .userId(payment.getUserId())
                .amount(payment.getAmount())
                .status(payment.getStatus())
                .referenceNumber(payment.getReferenceNumber())
                .idempotencyKey(payment.getIdempotencyKey())
                .createdAt(payment.getCreatedAt())
                .build();
    }
}
