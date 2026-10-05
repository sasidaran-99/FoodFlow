package com.foodflow.payment.controller;

import com.foodflow.payment.dto.PaymentRequest;
import com.foodflow.payment.dto.PaymentResponse;
import com.foodflow.payment.service.PaymentService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/payments")
@RequiredArgsConstructor
public class PaymentController {

    private final PaymentService paymentService;

    private Long getUserId(org.springframework.security.core.Authentication auth) {
        return (Long) auth.getPrincipal();
    }

    private boolean checkIsAdmin(org.springframework.security.core.Authentication auth) {
        return auth.getAuthorities().stream().anyMatch(a -> a.getAuthority().equals("ROLE_ADMIN"));
    }

    @PostMapping
    @org.springframework.security.access.prepost.PreAuthorize("hasRole('ROLE_CUSTOMER')")
    public ResponseEntity<PaymentResponse> processPayment(
            @RequestHeader("Idempotency-Key") String idempotencyKey,
            @Valid @RequestBody PaymentRequest request) {
        org.springframework.security.core.Authentication auth = org.springframework.security.core.context.SecurityContextHolder.getContext().getAuthentication();
        Long userId = getUserId(auth);
        PaymentResponse response = paymentService.processPayment(request, idempotencyKey, userId);
        return ResponseEntity.ok(response);
    }

    @GetMapping("/{id}")
    @org.springframework.security.access.prepost.PreAuthorize("hasRole('ROLE_CUSTOMER') or hasRole('ROLE_ADMIN')")
    public ResponseEntity<PaymentResponse> getPayment(@PathVariable Long id) {
        org.springframework.security.core.Authentication auth = org.springframework.security.core.context.SecurityContextHolder.getContext().getAuthentication();
        return ResponseEntity.ok(paymentService.getPayment(id, getUserId(auth), checkIsAdmin(auth)));
    }

    @GetMapping("/order/{orderId}")
    @org.springframework.security.access.prepost.PreAuthorize("hasRole('ROLE_CUSTOMER') or hasRole('ROLE_ADMIN')")
    public ResponseEntity<PaymentResponse> getPaymentByOrder(@PathVariable Long orderId) {
        org.springframework.security.core.Authentication auth = org.springframework.security.core.context.SecurityContextHolder.getContext().getAuthentication();
        return ResponseEntity.ok(paymentService.getPaymentByOrderId(orderId, getUserId(auth), checkIsAdmin(auth)));
    }
}
