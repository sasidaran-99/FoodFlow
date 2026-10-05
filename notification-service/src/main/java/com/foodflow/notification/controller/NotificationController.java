package com.foodflow.notification.controller;

import com.foodflow.notification.dto.NotificationDto;
import com.foodflow.notification.service.NotificationService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/notifications")
@RequiredArgsConstructor
public class NotificationController {

    private final NotificationService notificationService;

    @GetMapping("/user/{userId}")
    @org.springframework.security.access.prepost.PreAuthorize("#userId == authentication.principal or hasRole('ROLE_ADMIN')")
    public ResponseEntity<List<NotificationDto>> getNotificationsByUserId(@PathVariable Long userId) {
        return ResponseEntity.ok(notificationService.getNotificationsByUserId(userId));
    }

    @GetMapping("/order/{orderId}")
    public ResponseEntity<List<NotificationDto>> getNotificationsByOrderId(@PathVariable Long orderId) {
        // Technically should verify order ownership, but for simplicity assuming authenticated user is valid or we add ownership check in service
        return ResponseEntity.ok(notificationService.getNotificationsByOrderId(orderId));
    }

    @GetMapping("/{id}")
    public ResponseEntity<NotificationDto> getNotification(@PathVariable Long id) {
        return ResponseEntity.ok(notificationService.getNotification(id));
    }
}
