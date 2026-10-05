package com.foodflow.delivery.controller;

import com.foodflow.delivery.dto.DeliveryDto;
import com.foodflow.delivery.entity.DeliveryPartner;
import com.foodflow.delivery.service.DeliveryService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/deliveries")
@RequiredArgsConstructor
public class DeliveryController {

    private final DeliveryService deliveryService;

    @GetMapping("/{id}")
    public ResponseEntity<DeliveryDto> getDelivery(@PathVariable Long id) {
        return ResponseEntity.ok(deliveryService.getDelivery(id));
    }

    @GetMapping("/order/{orderId}")
    public ResponseEntity<DeliveryDto> getDeliveryByOrderId(@PathVariable Long orderId) {
        return ResponseEntity.ok(deliveryService.getDeliveryByOrderId(orderId));
    }

    @PostMapping("/{id}/assign")
    @org.springframework.security.access.prepost.PreAuthorize("hasRole('ROLE_DELIVERY_PARTNER')")
    public ResponseEntity<?> assignPartner(@PathVariable Long id) {
        try {
            return ResponseEntity.ok(deliveryService.assignPartner(id));
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(e.getMessage());
        }
    }

    @PatchMapping("/{id}/status")
    @org.springframework.security.access.prepost.PreAuthorize("hasRole('ROLE_DELIVERY_PARTNER') or hasRole('ROLE_ADMIN')")
    public ResponseEntity<?> updateStatus(@PathVariable Long id, @RequestParam String status) {
        try {
            return ResponseEntity.ok(deliveryService.updateStatus(id, status));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(e.getMessage());
        }
    }
    
    // For testing purposes
    @PostMapping("/partners")
    @org.springframework.security.access.prepost.PreAuthorize("hasRole('ROLE_ADMIN')")
    public ResponseEntity<DeliveryPartner> createPartner(@RequestParam String name) {
        return ResponseEntity.ok(deliveryService.createPartner(name));
    }
}
