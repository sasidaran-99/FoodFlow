package com.foodflow.order.dto;

import lombok.Data;

import java.math.BigDecimal;

@Data
public class MenuItemSnapshot {
    private Long id;
    private Long restaurantId;
    private String name;
    private String description;
    private BigDecimal price;
    private boolean isAvailable;
}
