package com.foodflow.restaurant.controller;

import com.foodflow.restaurant.dto.RestaurantDto;
import com.foodflow.restaurant.service.RestaurantService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/restaurants")
@RequiredArgsConstructor
public class RestaurantController {

    private final RestaurantService restaurantService;

    private Long getOwnerId() {
        return (Long) org.springframework.security.core.context.SecurityContextHolder.getContext().getAuthentication().getPrincipal();
    }

    @PostMapping
    @org.springframework.security.access.prepost.PreAuthorize("hasRole('ROLE_RESTAURANT_OWNER')")
    public ResponseEntity<RestaurantDto> createRestaurant(@Valid @RequestBody RestaurantDto request) {
        return new ResponseEntity<>(restaurantService.createRestaurant(getOwnerId(), request), HttpStatus.CREATED);
    }

    @PutMapping("/{id}")
    @org.springframework.security.access.prepost.PreAuthorize("hasRole('ROLE_RESTAURANT_OWNER')")
    public ResponseEntity<RestaurantDto> updateRestaurant(@PathVariable Long id, @Valid @RequestBody RestaurantDto request) {
        return ResponseEntity.ok(restaurantService.updateRestaurant(id, getOwnerId(), request));
    }

    @GetMapping("/{id}")
    public ResponseEntity<RestaurantDto> getRestaurant(@PathVariable Long id) {
        return ResponseEntity.ok(restaurantService.getRestaurant(id));
    }

    @GetMapping
    public ResponseEntity<Page<RestaurantDto>> getRestaurants(@RequestParam(defaultValue = "0") int page,
                                                              @RequestParam(defaultValue = "10") int size) {
        return ResponseEntity.ok(restaurantService.getAllOpenRestaurants(PageRequest.of(page, size)));
    }

    @PatchMapping("/{id}/status")
    @org.springframework.security.access.prepost.PreAuthorize("hasRole('ROLE_RESTAURANT_OWNER')")
    public ResponseEntity<RestaurantDto> toggleStatus(@PathVariable Long id, @RequestParam boolean isOpen) {
        return ResponseEntity.ok(restaurantService.toggleStatus(id, getOwnerId(), isOpen));
    }
}
