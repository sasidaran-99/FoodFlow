package com.foodflow.order.dto;

import lombok.Builder;
import lombok.Data;

import java.math.BigDecimal;

@Data
@Builder
public class OrderItemDto {
    private Long id;
    private Long menuItemId;
    private String name;
    private BigDecimal price;
    private Integer quantity;
}
