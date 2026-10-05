package com.foodflow.notification.repository;

import com.foodflow.notification.entity.Notification;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface NotificationRepository extends JpaRepository<Notification, Long> {
    List<Notification> findByUserIdOrderByCreatedAtDesc(Long userId);
    List<Notification> findByOrderIdOrderByCreatedAtDesc(Long orderId);
    boolean existsByEventId(String eventId);
}
