package com.foodflow.notification.dto;

import com.foodflow.notification.entity.NotificationStatus;
import com.foodflow.notification.entity.NotificationType;
import lombok.Builder;
import lombok.Data;

import java.time.LocalDateTime;

@Data
@Builder
public class NotificationDto {
    private Long id;
    private Long userId;
    private Long orderId;
    private NotificationType type;
    private String message;
    private NotificationStatus status;
    private LocalDateTime createdAt;
    private String eventId;
}
