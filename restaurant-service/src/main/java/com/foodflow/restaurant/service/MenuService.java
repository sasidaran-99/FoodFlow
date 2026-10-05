package com.foodflow.restaurant.service;

import com.foodflow.restaurant.dto.MenuItemDto;
import com.foodflow.restaurant.entity.MenuItem;
import com.foodflow.restaurant.entity.Restaurant;
import com.foodflow.restaurant.exception.ResourceNotFoundException;
import com.foodflow.restaurant.repository.MenuItemRepository;
import com.foodflow.restaurant.repository.RestaurantRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.util.List;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class MenuService {

    private final MenuItemRepository menuItemRepository;
    private final RestaurantRepository restaurantRepository;
    private final RedisTemplate<String, Object> redisTemplate;

    private static final String MENU_CACHE_PREFIX = "menu:";
    private static final Duration TTL = Duration.ofMinutes(10);

    public MenuItemDto addMenuItem(Long restaurantId, Long ownerId, MenuItemDto request) {
        Restaurant restaurant = restaurantRepository.findById(restaurantId).orElseThrow(() -> new ResourceNotFoundException("Restaurant not found"));
        if (!restaurant.getOwnerId().equals(ownerId)) {
            throw new org.springframework.security.access.AccessDeniedException("Access denied");
        }

        MenuItem item = MenuItem.builder()
                .restaurant(restaurant)
                .name(request.getName())
                .description(request.getDescription())
                .price(request.getPrice())
                .isAvailable(true)
                .build();
        
        item = menuItemRepository.save(item);
        invalidateMenuCache(restaurantId);
        return mapToDto(item);
    }

    public MenuItemDto updateMenuItem(Long restaurantId, Long itemId, Long ownerId, MenuItemDto request) {
        Restaurant restaurant = restaurantRepository.findById(restaurantId).orElseThrow(() -> new ResourceNotFoundException("Restaurant not found"));
        if (!restaurant.getOwnerId().equals(ownerId)) {
            throw new org.springframework.security.access.AccessDeniedException("Access denied");
        }

        MenuItem item = menuItemRepository.findByIdAndRestaurantId(itemId, restaurantId)
                .orElseThrow(() -> new ResourceNotFoundException("Menu item not found"));

        item.setName(request.getName());
        item.setDescription(request.getDescription());
        item.setPrice(request.getPrice());
        
        item = menuItemRepository.save(item);
        invalidateMenuCache(restaurantId);
        return mapToDto(item);
    }

    @SuppressWarnings("unchecked")
    public List<MenuItemDto> getMenu(Long restaurantId) {
        String key = MENU_CACHE_PREFIX + restaurantId;

        // 1. Check Cache
        try {
            Object cached = redisTemplate.opsForValue().get(key);
            if (cached != null) {
                log.info("CACHE HIT for key: {}", key);
                return (List<MenuItemDto>) cached;
            }
        } catch (Exception e) {
            log.error("Redis is unavailable, falling back to PostgreSQL for key: {}", key);
        }

        log.info("CACHE MISS for key: {}", key);

        // 2. Fetch from DB
        List<MenuItemDto> menu = menuItemRepository.findByRestaurantIdAndIsAvailableTrue(restaurantId)
                .stream()
                .map(this::mapToDto)
                .collect(Collectors.toList());

        // 3. Update Cache
        try {
            redisTemplate.opsForValue().set(key, menu, TTL);
            log.info("Cached data in Redis for key: {}", key);
        } catch (Exception e) {
            log.error("Failed to update Redis cache for key: {}", key);
        }

        return menu;
    }

    public void removeMenuItem(Long restaurantId, Long itemId, Long ownerId) {
        Restaurant restaurant = restaurantRepository.findById(restaurantId).orElseThrow(() -> new ResourceNotFoundException("Restaurant not found"));
        if (!restaurant.getOwnerId().equals(ownerId)) {
            throw new org.springframework.security.access.AccessDeniedException("Access denied");
        }

        MenuItem item = menuItemRepository.findByIdAndRestaurantId(itemId, restaurantId)
                .orElseThrow(() -> new ResourceNotFoundException("Menu item not found"));

        menuItemRepository.delete(item);
        invalidateMenuCache(restaurantId);
    }
    
    public MenuItemDto toggleAvailability(Long restaurantId, Long itemId, Long ownerId, boolean isAvailable) {
        Restaurant restaurant = restaurantRepository.findById(restaurantId).orElseThrow(() -> new ResourceNotFoundException("Restaurant not found"));
        if (!restaurant.getOwnerId().equals(ownerId)) {
            throw new org.springframework.security.access.AccessDeniedException("Access denied");
        }

        MenuItem item = menuItemRepository.findByIdAndRestaurantId(itemId, restaurantId)
                .orElseThrow(() -> new ResourceNotFoundException("Menu item not found"));

        item.setAvailable(isAvailable);
        item = menuItemRepository.save(item);
        invalidateMenuCache(restaurantId);
        return mapToDto(item);
    }

    private void invalidateMenuCache(Long restaurantId) {
        String key = MENU_CACHE_PREFIX + restaurantId;
        try {
            log.info("CACHE EVICTION for key: {}", key);
            redisTemplate.delete(key);
        } catch (Exception e) {
            log.error("Redis unavailable during cache eviction for key: {}", key);
        }
    }

    private MenuItemDto mapToDto(MenuItem item) {
        return MenuItemDto.builder()
                .id(item.getId())
                .restaurantId(item.getRestaurant().getId())
                .name(item.getName())
                .description(item.getDescription())
                .price(item.getPrice())
                .isAvailable(item.isAvailable())
                .build();
    }
}

