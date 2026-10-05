package com.foodflow.order.controller;

import com.foodflow.order.dto.CreateOrderRequest;
import com.foodflow.order.dto.OrderDto;
import com.foodflow.order.entity.OrderStatus;
import com.foodflow.order.service.OrderService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/orders")
@RequiredArgsConstructor
public class OrderController {

    private final OrderService orderService;

    private Long getUserId() {
        return (Long) org.springframework.security.core.context.SecurityContextHolder.getContext().getAuthentication().getPrincipal();
    }

    @PostMapping
    @org.springframework.security.access.prepost.PreAuthorize("hasRole('ROLE_CUSTOMER') or hasRole('ROLE_RESTAURANT_OWNER')")
    public ResponseEntity<OrderDto> createOrder(@Valid @RequestBody CreateOrderRequest request) {
        return new ResponseEntity<>(orderService.createOrder(getUserId(), request), HttpStatus.CREATED);
    }

    @GetMapping("/{id}")
    @org.springframework.security.access.prepost.PreAuthorize("hasRole('ROLE_CUSTOMER') or hasRole('ROLE_RESTAURANT_OWNER')")
    public ResponseEntity<OrderDto> getOrder(@PathVariable Long id) {
        return ResponseEntity.ok(orderService.getOrder(id, getUserId()));
    }

    @GetMapping
    @org.springframework.security.access.prepost.PreAuthorize("hasRole('ROLE_CUSTOMER') or hasRole('ROLE_RESTAURANT_OWNER')")
    public ResponseEntity<Page<OrderDto>> getUserOrders(@RequestParam(defaultValue = "0") int page,
                                                        @RequestParam(defaultValue = "10") int size) {
        return ResponseEntity.ok(orderService.getUserOrders(getUserId(), PageRequest.of(page, size)));
    }

    @PatchMapping("/{id}/status")
    @org.springframework.security.access.prepost.PreAuthorize("hasRole('ROLE_ADMIN') or hasRole('ROLE_RESTAURANT_OWNER')")
    public ResponseEntity<OrderDto> updateOrderStatus(@PathVariable Long id, @RequestParam OrderStatus status) {
        org.springframework.security.core.Authentication auth = org.springframework.security.core.context.SecurityContextHolder.getContext().getAuthentication();
        Long userId = (Long) auth.getPrincipal();
        boolean isAdmin = auth.getAuthorities().stream().anyMatch(a -> a.getAuthority().equals("ROLE_ADMIN"));
        return ResponseEntity.ok(orderService.updateOrderStatus(id, status, userId, isAdmin));
    }
}
