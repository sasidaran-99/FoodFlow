package com.foodflow.delivery.dto;

import com.foodflow.delivery.entity.PartnerStatus;
import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class DeliveryPartnerDto {
    private Long id;
    private String name;
    private PartnerStatus status;
}
