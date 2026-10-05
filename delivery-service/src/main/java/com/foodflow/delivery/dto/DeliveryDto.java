package com.foodflow.delivery.dto;

import com.foodflow.delivery.entity.DeliveryStatus;
import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class DeliveryDto {
    private Long id;
    private Long orderId;
    private Long restaurantId;
    private Long deliveryPartnerId;
    private DeliveryStatus status;
}
