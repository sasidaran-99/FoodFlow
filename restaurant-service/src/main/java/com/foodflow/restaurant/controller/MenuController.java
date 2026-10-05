package com.foodflow.restaurant.controller;

import com.foodflow.restaurant.dto.MenuItemDto;
import com.foodflow.restaurant.service.MenuService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/restaurants/{restaurantId}/menu")
@RequiredArgsConstructor
public class MenuController {

    private final MenuService menuService;

    private Long getOwnerId() {
        return (Long) org.springframework.security.core.context.SecurityContextHolder.getContext().getAuthentication().getPrincipal();
    }

    @PostMapping
    @org.springframework.security.access.prepost.PreAuthorize("hasRole('ROLE_RESTAURANT_OWNER')")
    public ResponseEntity<MenuItemDto> addMenuItem(@PathVariable Long restaurantId, @Valid @RequestBody MenuItemDto request) {
        return new ResponseEntity<>(menuService.addMenuItem(restaurantId, getOwnerId(), request), HttpStatus.CREATED);
    }

    @GetMapping
    public ResponseEntity<List<MenuItemDto>> getMenu(@PathVariable Long restaurantId) {
        return ResponseEntity.ok(menuService.getMenu(restaurantId));
    }

    @PutMapping("/{itemId}")
    @org.springframework.security.access.prepost.PreAuthorize("hasRole('ROLE_RESTAURANT_OWNER')")
    public ResponseEntity<MenuItemDto> updateMenuItem(@PathVariable Long restaurantId,
                                                      @PathVariable Long itemId,
                                                      @Valid @RequestBody MenuItemDto request) {
        return ResponseEntity.ok(menuService.updateMenuItem(restaurantId, itemId, getOwnerId(), request));
    }

    @DeleteMapping("/{itemId}")
    @org.springframework.security.access.prepost.PreAuthorize("hasRole('ROLE_RESTAURANT_OWNER')")
    public ResponseEntity<Void> removeMenuItem(@PathVariable Long restaurantId, @PathVariable Long itemId) {
        menuService.removeMenuItem(restaurantId, itemId, getOwnerId());
        return ResponseEntity.noContent().build();
    }

    @PatchMapping("/{itemId}/status")
    @org.springframework.security.access.prepost.PreAuthorize("hasRole('ROLE_RESTAURANT_OWNER')")
    public ResponseEntity<MenuItemDto> toggleAvailability(@PathVariable Long restaurantId,
                                                          @PathVariable Long itemId,
                                                          @RequestParam boolean isAvailable) {
        return ResponseEntity.ok(menuService.toggleAvailability(restaurantId, itemId, getOwnerId(), isAvailable));
    }
}
