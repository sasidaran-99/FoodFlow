package com.foodflow.notification.service;

import com.foodflow.notification.dto.NotificationDto;
import com.foodflow.notification.entity.Notification;
import com.foodflow.notification.entity.NotificationStatus;
import com.foodflow.notification.entity.NotificationType;
import com.foodflow.notification.event.PaymentCompletedEvent;
import com.foodflow.notification.event.PaymentFailedEvent;
import com.foodflow.notification.repository.NotificationRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class NotificationService {

    private final NotificationRepository notificationRepository;
    private final MockNotificationSender mockNotificationSender;

    @Transactional
    public void processPaymentCompleted(PaymentCompletedEvent event) {
        if (notificationRepository.existsByEventId(event.getEventId())) {
            log.info("Duplicate PaymentCompletedEvent detected. Event ID: {}", event.getEventId());
            return; // Idempotency
        }

        Notification notification = Notification.builder()
                .orderId(event.getOrderId())
                .type(NotificationType.ORDER_CONFIRMED)
                .message("Payment successful for order #" + event.getOrderId() + ". Amount: " + event.getAmount())
                .status(NotificationStatus.PENDING)
                .eventId(event.getEventId())
                .build();

        try {
            notification = notificationRepository.save(notification);
            
            // Mock sending
            mockNotificationSender.send(notification);
            
            notification.setStatus(NotificationStatus.SENT);
            notificationRepository.save(notification);
        } catch (DataIntegrityViolationException e) {
            log.info("Duplicate event detected by database constraint: {}", event.getEventId());
        } catch (Exception e) {
            notification.setStatus(NotificationStatus.FAILED);
            notificationRepository.save(notification);
            log.error("Failed to send notification for event: {}", event.getEventId());
        }
    }

    @Transactional
    public void processPaymentFailed(PaymentFailedEvent event) {
        if (notificationRepository.existsByEventId(event.getEventId())) {
            log.info("Duplicate PaymentFailedEvent detected. Event ID: {}", event.getEventId());
            return;
        }

        Notification notification = Notification.builder()
                .orderId(event.getOrderId())
                .type(NotificationType.PAYMENT_FAILED)
                .message("Payment failed for order #" + event.getOrderId() + ". Reason: " + event.getFailureReason())
                .status(NotificationStatus.PENDING)
                .eventId(event.getEventId())
                .build();

        try {
            notification = notificationRepository.save(notification);
            
            // Mock sending
            mockNotificationSender.send(notification);
            
            notification.setStatus(NotificationStatus.SENT);
            notificationRepository.save(notification);
        } catch (DataIntegrityViolationException e) {
            log.info("Duplicate event detected by database constraint: {}", event.getEventId());
        } catch (Exception e) {
            notification.setStatus(NotificationStatus.FAILED);
            notificationRepository.save(notification);
            log.error("Failed to send notification for event: {}", event.getEventId());
        }
    }

    public List<NotificationDto> getNotificationsByUserId(Long userId) {
        return notificationRepository.findByUserIdOrderByCreatedAtDesc(userId)
                .stream().map(this::mapToDto).collect(Collectors.toList());
    }

    public List<NotificationDto> getNotificationsByOrderId(Long orderId) {
        return notificationRepository.findByOrderIdOrderByCreatedAtDesc(orderId)
                .stream().map(this::mapToDto).collect(Collectors.toList());
    }
    
    public NotificationDto getNotification(Long id) {
        Notification notification = notificationRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Notification not found"));
        return mapToDto(notification);
    }

    private NotificationDto mapToDto(Notification notification) {
        return NotificationDto.builder()
                .id(notification.getId())
                .userId(notification.getUserId())
                .orderId(notification.getOrderId())
                .type(notification.getType())
                .message(notification.getMessage())
                .status(notification.getStatus())
                .createdAt(notification.getCreatedAt())
                .eventId(notification.getEventId())
                .build();
    }
}
