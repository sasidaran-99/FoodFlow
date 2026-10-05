package com.foodflow.order.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class RestaurantSnapshot {
    private Long id;
    private Long ownerId;
    private String name;
    private boolean isOpen;
}
