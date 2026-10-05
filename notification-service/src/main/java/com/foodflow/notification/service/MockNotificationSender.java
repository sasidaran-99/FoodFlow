package com.foodflow.notification.service;

import com.foodflow.notification.entity.Notification;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

@Slf4j
@Service
public class MockNotificationSender {

    public void send(Notification notification) {
        // Simulate sending email / SMS / Push
        log.info("--------------------------------------------------");
        log.info("MOCK NOTIFICATION SENDER");
        log.info("To User: {}", (notification.getUserId() != null ? notification.getUserId() : "Unknown"));
        log.info("Order ID: {}", notification.getOrderId());
        log.info("Type: {}", notification.getType());
        log.info("Message: {}", notification.getMessage());
        log.info("--------------------------------------------------");
    }
}
