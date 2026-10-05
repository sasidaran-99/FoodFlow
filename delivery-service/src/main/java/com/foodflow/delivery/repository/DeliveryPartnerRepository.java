package com.foodflow.delivery.repository;

import com.foodflow.delivery.entity.DeliveryPartner;
import com.foodflow.delivery.entity.PartnerStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface DeliveryPartnerRepository extends JpaRepository<DeliveryPartner, Long> {
    Optional<DeliveryPartner> findFirstByStatus(PartnerStatus status);
}
