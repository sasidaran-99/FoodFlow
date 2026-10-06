package com.foodflow.delivery.service;

import com.foodflow.delivery.dto.DeliveryDto;
import com.foodflow.delivery.entity.Delivery;
import com.foodflow.delivery.entity.DeliveryPartner;
import com.foodflow.delivery.entity.DeliveryStatus;
import com.foodflow.delivery.entity.PartnerStatus;
import com.foodflow.delivery.event.OrderConfirmedEvent;
import com.foodflow.delivery.kafka.DeliveryEventPublisher;
import com.foodflow.delivery.repository.DeliveryPartnerRepository;
import com.foodflow.delivery.repository.DeliveryRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.orm.ObjectOptimisticLockingFailureException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.foodflow.delivery.exception.ResourceNotFoundException;
import java.util.Optional;

@Slf4j
@Service
@RequiredArgsConstructor
public class DeliveryService {

    private final DeliveryRepository deliveryRepository;
    private final DeliveryPartnerRepository deliveryPartnerRepository;
    private final DeliveryEventPublisher deliveryEventPublisher;

    @Transactional
    public void processOrderConfirmed(OrderConfirmedEvent event) {
        if (deliveryRepository.existsByEventId(event.getEventId())) {
            log.info("Duplicate OrderConfirmedEvent detected. Event ID: {}", event.getEventId());
            return;
        }

        Delivery delivery = Delivery.builder()
                .orderId(event.getOrderId())
                .restaurantId(event.getRestaurantId())
                .status(DeliveryStatus.ASSIGNMENT_PENDING)
                .eventId(event.getEventId())
                .build();

        try {
            deliveryRepository.save(delivery);
            log.info("Created delivery record for orderId: {}", event.getOrderId());
        } catch (DataIntegrityViolationException e) {
            log.info("Duplicate event detected by database constraint: {}", event.getEventId());
        }
    }

    @Transactional
    public DeliveryDto assignPartner(Long deliveryId) {
        Delivery delivery = deliveryRepository.findById(deliveryId)
                .orElseThrow(() -> new ResourceNotFoundException("Delivery not found with ID: " + deliveryId));

        if (delivery.getStatus() != DeliveryStatus.ASSIGNMENT_PENDING) {
            throw new IllegalStateException("Delivery is not in ASSIGNMENT_PENDING state");
        }

        // Find an available partner
        Optional<DeliveryPartner> partnerOpt = deliveryPartnerRepository.findFirstByStatus(PartnerStatus.AVAILABLE);
        
        if (partnerOpt.isEmpty()) {
            throw new RuntimeException("No delivery partners available right now");
        }

        DeliveryPartner partner = partnerOpt.get();
        partner.setStatus(PartnerStatus.BUSY);
        
        try {
            deliveryPartnerRepository.save(partner);
            
            delivery.setDeliveryPartnerId(partner.getId());
            delivery.setStatus(DeliveryStatus.ASSIGNED);
            deliveryRepository.save(delivery);
            
            deliveryEventPublisher.publishDeliveryEvent(delivery.getId(), delivery.getOrderId(), "assigned");
            
            log.info("Assigned partner {} to delivery {}", partner.getId(), deliveryId);
            return mapToDto(delivery);
        } catch (ObjectOptimisticLockingFailureException e) {
            log.error("Concurrent assignment detected for partner {}", partner.getId());
            throw new RuntimeException("Partner was assigned by another request. Please try again.");
        }
    }

    @Transactional
    public DeliveryDto updateStatus(Long deliveryId, String newStatusStr) {
        Delivery delivery = deliveryRepository.findById(deliveryId)
                .orElseThrow(() -> new ResourceNotFoundException("Delivery not found with ID: " + deliveryId));

        DeliveryStatus newStatus;
        try {
            newStatus = DeliveryStatus.valueOf(newStatusStr.toUpperCase());
        } catch (IllegalArgumentException e) {
            throw new IllegalArgumentException("Invalid status: " + newStatusStr);
        }

        if (delivery.getStatus() == newStatus) {
            log.info("Delivery {} is already in status {}. No transition performed (safe no-op).", deliveryId, newStatus);
            return mapToDto(delivery);
        }

        validateStateTransition(delivery.getStatus(), newStatus);

        delivery.setStatus(newStatus);
        
        if (newStatus == DeliveryStatus.DELIVERED || newStatus == DeliveryStatus.CANCELLED) {
            if (delivery.getDeliveryPartnerId() != null) {
                DeliveryPartner partner = deliveryPartnerRepository.findById(delivery.getDeliveryPartnerId())
                        .orElseThrow(() -> new ResourceNotFoundException("Partner not found with ID: " + delivery.getDeliveryPartnerId()));
                partner.setStatus(PartnerStatus.AVAILABLE);
                deliveryPartnerRepository.save(partner);
            }
        }
        
        deliveryRepository.save(delivery);
        deliveryEventPublisher.publishDeliveryEvent(delivery.getId(), delivery.getOrderId(), newStatus.name());
        
        return mapToDto(delivery);
    }

    private void validateStateTransition(DeliveryStatus current, DeliveryStatus next) {
        if (current == DeliveryStatus.DELIVERED || current == DeliveryStatus.CANCELLED) {
            throw new IllegalStateException("Delivery is in terminal state: " + current);
        }
        
        boolean valid = false;
        switch (current) {
            case ASSIGNMENT_PENDING:
                valid = next == DeliveryStatus.ASSIGNED || next == DeliveryStatus.CANCELLED;
                break;
            case ASSIGNED:
                valid = next == DeliveryStatus.PICKED_UP || next == DeliveryStatus.CANCELLED;
                break;
            case PICKED_UP:
                valid = next == DeliveryStatus.OUT_FOR_DELIVERY;
                break;
            case OUT_FOR_DELIVERY:
                valid = next == DeliveryStatus.DELIVERED;
                break;
            default:
                break;
        }

        if (!valid) {
            throw new IllegalStateException("Invalid state transition from " + current + " to " + next);
        }
    }

    public DeliveryDto getDelivery(Long id) {
        return deliveryRepository.findById(id).map(this::mapToDto)
                .orElseThrow(() -> new ResourceNotFoundException("Delivery not found with ID: " + id));
    }
    
    public DeliveryDto getDeliveryByOrderId(Long orderId) {
        return deliveryRepository.findByOrderId(orderId).map(this::mapToDto)
                .orElseThrow(() -> new ResourceNotFoundException("No delivery found for Order #" + orderId));
    }
    
    public DeliveryPartner createPartner(String name) {
        DeliveryPartner partner = DeliveryPartner.builder()
                .name(name)
                .status(PartnerStatus.AVAILABLE)
                .build();
        return deliveryPartnerRepository.save(partner);
    }

    private DeliveryDto mapToDto(Delivery delivery) {
        return DeliveryDto.builder()
                .id(delivery.getId())
                .orderId(delivery.getOrderId())
                .restaurantId(delivery.getRestaurantId())
                .deliveryPartnerId(delivery.getDeliveryPartnerId())
                .status(delivery.getStatus())
                .build();
    }
}
