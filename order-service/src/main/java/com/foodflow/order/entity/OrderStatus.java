package com.foodflow.order.entity;

public enum OrderStatus {
    CREATED,
    PAYMENT_PENDING,
    CONFIRMED,
    RESTAURANT_ACCEPTED,
    PREPARING,
    READY_FOR_PICKUP,
    OUT_FOR_DELIVERY,
    DELIVERED,
    PAYMENT_FAILED,
    REJECTED,
    CANCELLED
}
