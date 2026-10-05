package com.foodflow.order.service;

import com.foodflow.order.dto.*;
import com.foodflow.order.entity.Order;
import com.foodflow.order.entity.OrderItem;
import com.foodflow.order.entity.OrderStatus;
import com.foodflow.order.entity.ProcessedEvent;
import com.foodflow.order.event.PaymentCompletedEvent;
import com.foodflow.order.event.PaymentFailedEvent;
import com.foodflow.order.event.PaymentRequestedEvent;
import com.foodflow.order.exception.InvalidOrderStateException;
import com.foodflow.order.exception.ResourceNotFoundException;
import com.foodflow.order.repository.OrderRepository;
import com.foodflow.order.repository.ProcessedEventRepository;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.core.ParameterizedTypeReference;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class OrderService {

    private final OrderRepository orderRepository;
    private final ProcessedEventRepository processedEventRepository;
    private final RestTemplate restTemplate;
    private final OrderEventPublisher eventPublisher;

    @Transactional
    public OrderDto createOrder(Long userId, CreateOrderRequest request) {
        String token = extractJwtToken();
        HttpHeaders headers = new HttpHeaders();
        if (token != null) {
            headers.set("Authorization", "Bearer " + token);
        }
        HttpEntity<Void> entity = new HttpEntity<>(headers);
        
        String url = "http://127.0.0.1:8082/api/restaurants/" + request.getRestaurantId() + "/menu";
        
        ResponseEntity<List<MenuItemSnapshot>> response = restTemplate.exchange(
                url, HttpMethod.GET, entity, new ParameterizedTypeReference<List<MenuItemSnapshot>>() {}
        );

        List<MenuItemSnapshot> menuItems = response.getBody();
        if (menuItems == null || menuItems.isEmpty()) {
            throw new ResourceNotFoundException("Restaurant menu not found or empty");
        }

        Order order = Order.builder()
                .userId(userId)
                .restaurantId(request.getRestaurantId())
                .status(OrderStatus.CREATED)
                .totalAmount(BigDecimal.ZERO)
                .build();

        BigDecimal totalAmount = BigDecimal.ZERO;
        for (OrderItemRequest itemRequest : request.getItems()) {
            MenuItemSnapshot snapshot = menuItems.stream()
                    .filter(mi -> mi.getId().equals(itemRequest.getMenuItemId()))
                    .findFirst()
                    .orElseThrow(() -> new ResourceNotFoundException("Menu item not found"));

            if (!snapshot.isAvailable()) {
                throw new InvalidOrderStateException("Menu item unavailable");
            }

            OrderItem orderItem = OrderItem.builder()
                    .menuItemId(snapshot.getId())
                    .name(snapshot.getName())
                    .price(snapshot.getPrice())
                    .quantity(itemRequest.getQuantity())
                    .build();

            order.addItem(orderItem);
            totalAmount = totalAmount.add(snapshot.getPrice().multiply(BigDecimal.valueOf(itemRequest.getQuantity())));
        }

        order.setTotalAmount(totalAmount);
        
        // Transition to PAYMENT_PENDING before dispatching
        order.setStatus(OrderStatus.PAYMENT_PENDING);
        Order savedOrder = orderRepository.save(order);

        // Publish event to Kafka
        PaymentRequestedEvent event = PaymentRequestedEvent.builder()
                .eventId(UUID.randomUUID().toString())
                .orderId(savedOrder.getId())
                .userId(userId)
                .amount(savedOrder.getTotalAmount())
                .idempotencyKey(UUID.randomUUID().toString())
                .timestamp(LocalDateTime.now())
                .build();
        
        eventPublisher.publishPaymentRequested(event);

        return mapToDto(savedOrder);
    }

    @Transactional
    public void handlePaymentCompleted(PaymentCompletedEvent event) {
        if (processedEventRepository.existsById(event.getEventId())) {
            log.info("Event {} already processed. Skipping.", event.getEventId());
            return;
        }

        Order order = orderRepository.findById(event.getOrderId())
                .orElseThrow(() -> new ResourceNotFoundException("Order not found"));
        
        if (order.getStatus() == OrderStatus.PAYMENT_PENDING) {
            order.setStatus(OrderStatus.CONFIRMED);
            orderRepository.save(order);
            log.info("Order {} confirmed successfully.", order.getId());
            
            eventPublisher.publishOrderConfirmed(order.getId(), order.getRestaurantId());
        }

        processedEventRepository.save(new ProcessedEvent(event.getEventId(), LocalDateTime.now()));
    }

    @Transactional
    public void handlePaymentFailed(PaymentFailedEvent event) {
        if (processedEventRepository.existsById(event.getEventId())) {
            log.info("Event {} already processed. Skipping.", event.getEventId());
            return;
        }

        Order order = orderRepository.findById(event.getOrderId())
                .orElseThrow(() -> new ResourceNotFoundException("Order not found"));
        
        if (order.getStatus() == OrderStatus.PAYMENT_PENDING) {
            order.setStatus(OrderStatus.PAYMENT_FAILED);
            orderRepository.save(order);
            log.info("Order {} payment failed.", order.getId());
        }

        processedEventRepository.save(new ProcessedEvent(event.getEventId(), LocalDateTime.now()));
    }

    public OrderDto getOrder(Long orderId, Long userId) {
        Order order = orderRepository.findById(orderId)
                .orElseThrow(() -> new ResourceNotFoundException("Order not found"));
        if (!order.getUserId().equals(userId)) {
            throw new org.springframework.security.access.AccessDeniedException("Access denied");
        }
        return mapToDto(order);
    }

    public Page<OrderDto> getUserOrders(Long userId, Pageable pageable) {
        return orderRepository.findByUserId(userId, pageable).map(this::mapToDto);
    }

    @Transactional
    public OrderDto updateOrderStatus(Long orderId, OrderStatus newStatus, Long callerUserId, boolean isAdmin) {
        Order order = orderRepository.findById(orderId)
                .orElseThrow(() -> new ResourceNotFoundException("Order not found"));

        if (!isAdmin) {
            String token = extractJwtToken();
            HttpHeaders headers = new HttpHeaders();
            if (token != null) {
                headers.set("Authorization", "Bearer " + token);
            }
            HttpEntity<Void> entity = new HttpEntity<>(headers);
            String url = "http://127.0.0.1:8082/api/restaurants/" + order.getRestaurantId();
            try {
                ResponseEntity<RestaurantSnapshot> response = restTemplate.exchange(
                        url, HttpMethod.GET, entity, RestaurantSnapshot.class
                );
                RestaurantSnapshot restaurant = response.getBody();
                if (restaurant == null || restaurant.getOwnerId() == null || !restaurant.getOwnerId().equals(callerUserId)) {
                    log.warn("Ownership verification failed: caller {} does not own restaurant {}", callerUserId, order.getRestaurantId());
                    throw new org.springframework.security.access.AccessDeniedException("Access denied: You do not own this restaurant");
                }
            } catch (org.springframework.security.access.AccessDeniedException e) {
                throw e;
            } catch (Exception e) {
                log.error("Failed to verify restaurant ownership with restaurant-service: {}", e.getMessage());
                throw new org.springframework.security.access.AccessDeniedException("Access denied: Unable to verify restaurant ownership");
            }
        }

        validateStateTransition(order.getStatus(), newStatus);
        order.setStatus(newStatus);
        return mapToDto(orderRepository.save(order));
    }

    @Transactional
    public OrderDto updateOrderStatus(Long orderId, OrderStatus newStatus) {
        return updateOrderStatus(orderId, newStatus, null, true);
    }

    private void validateStateTransition(OrderStatus current, OrderStatus next) {
        boolean isValid = switch (current) {
            case CREATED -> next == OrderStatus.PAYMENT_PENDING || next == OrderStatus.CANCELLED;
            case PAYMENT_PENDING -> next == OrderStatus.CONFIRMED || next == OrderStatus.PAYMENT_FAILED || next == OrderStatus.CANCELLED;
            case CONFIRMED -> next == OrderStatus.RESTAURANT_ACCEPTED || next == OrderStatus.CANCELLED;
            case RESTAURANT_ACCEPTED -> next == OrderStatus.PREPARING || next == OrderStatus.CANCELLED || next == OrderStatus.REJECTED;
            case PREPARING -> next == OrderStatus.READY_FOR_PICKUP;
            case READY_FOR_PICKUP -> next == OrderStatus.OUT_FOR_DELIVERY;
            case OUT_FOR_DELIVERY -> next == OrderStatus.DELIVERED;
            case DELIVERED, PAYMENT_FAILED, REJECTED, CANCELLED -> false;
        };

        if (!isValid) {
            throw new InvalidOrderStateException(String.format("Invalid transition from %s to %s", current, next));
        }
    }

    private String extractJwtToken() {
        ServletRequestAttributes attributes = (ServletRequestAttributes) RequestContextHolder.getRequestAttributes();
        if (attributes != null) {
            HttpServletRequest request = attributes.getRequest();
            String authHeader = request.getHeader("Authorization");
            if (authHeader != null && authHeader.startsWith("Bearer ")) {
                return authHeader.substring(7);
            }
        }
        return null;
    }

    private OrderDto mapToDto(Order order) {
        return OrderDto.builder()
                .id(order.getId())
                .userId(order.getUserId())
                .restaurantId(order.getRestaurantId())
                .status(order.getStatus())
                .totalAmount(order.getTotalAmount())
                .createdAt(order.getCreatedAt())
                .updatedAt(order.getUpdatedAt())
                .items(order.getItems().stream().map(item -> OrderItemDto.builder()
                        .id(item.getId())
                        .menuItemId(item.getMenuItemId())
                        .name(item.getName())
                        .price(item.getPrice())
                        .quantity(item.getQuantity())
                        .build()).collect(Collectors.toList()))
                .build();
    }
}
