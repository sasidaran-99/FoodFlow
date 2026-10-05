package com.foodflow.restaurant.service;

import com.foodflow.restaurant.dto.RestaurantDto;
import com.foodflow.restaurant.entity.Restaurant;
import com.foodflow.restaurant.exception.ResourceNotFoundException;
import com.foodflow.restaurant.repository.RestaurantRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.stereotype.Service;

import java.time.Duration;

@Slf4j
@Service
@RequiredArgsConstructor
public class RestaurantService {

    private final RestaurantRepository restaurantRepository;
    private final RedisTemplate<String, Object> redisTemplate;

    private static final String RESTAURANT_CACHE_PREFIX = "restaurant:";
    private static final Duration TTL = Duration.ofMinutes(10);

    public RestaurantDto createRestaurant(Long ownerId, RestaurantDto request) {
        Restaurant restaurant = Restaurant.builder()
                .ownerId(ownerId)
                .name(request.getName())
                .description(request.getDescription())
                .address(request.getAddress())
                .isOpen(true)
                .build();
        
        restaurant = restaurantRepository.save(restaurant);
        return mapToDto(restaurant);
    }

    public RestaurantDto updateRestaurant(Long id, Long ownerId, RestaurantDto request) {
        Restaurant restaurant = restaurantRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Restaurant not found"));
        if (!restaurant.getOwnerId().equals(ownerId)) {
            throw new org.springframework.security.access.AccessDeniedException("Access denied");
        }

        restaurant.setName(request.getName());
        restaurant.setDescription(request.getDescription());
        restaurant.setAddress(request.getAddress());
        
        restaurant = restaurantRepository.save(restaurant);
        RestaurantDto dto = mapToDto(restaurant);
        
        // Cache Invalidation (or Update)
        String key = RESTAURANT_CACHE_PREFIX + id;
        try {
            log.info("CACHE INVALIDATION/UPDATE for key: {}", key);
            redisTemplate.opsForValue().set(key, dto, TTL);
        } catch (Exception e) {
            log.error("Redis unavailable during cache invalidation for key: {}", key, e);
        }
        
        return dto;
    }

    public RestaurantDto getRestaurant(Long id) {
        String key = RESTAURANT_CACHE_PREFIX + id;
        
        // 1. Check Cache
        try {
            Object cached = redisTemplate.opsForValue().get(key);
            if (cached != null) {
                log.info("CACHE HIT for key: {}", key);
                return (RestaurantDto) cached;
            }
        } catch (Exception e) {
            log.error("Redis is unavailable, falling back to PostgreSQL for key: {}", key);
        }
        
        log.info("CACHE MISS for key: {}", key);
        
        // 2. Fetch from DB
        Restaurant restaurant = restaurantRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Restaurant not found"));
        RestaurantDto dto = mapToDto(restaurant);
        
        // 3. Update Cache
        try {
            redisTemplate.opsForValue().set(key, dto, TTL);
            log.info("Cached data in Redis for key: {}", key);
        } catch (Exception e) {
            log.error("Failed to update Redis cache for key: {}", key);
        }
        
        return dto;
    }

    public Page<RestaurantDto> getAllOpenRestaurants(Pageable pageable) {
        return restaurantRepository.findByIsOpenTrue(pageable).map(this::mapToDto);
    }

    public RestaurantDto toggleStatus(Long id, Long ownerId, boolean isOpen) {
        Restaurant restaurant = restaurantRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Restaurant not found"));
        if (!restaurant.getOwnerId().equals(ownerId)) {
            throw new org.springframework.security.access.AccessDeniedException("Access denied");
        }
        
        restaurant.setOpen(isOpen);
        restaurant = restaurantRepository.save(restaurant);
        RestaurantDto dto = mapToDto(restaurant);
        
        // Cache Invalidation
        String key = RESTAURANT_CACHE_PREFIX + id;
        try {
            log.info("CACHE INVALIDATION/UPDATE for key: {}", key);
            redisTemplate.opsForValue().set(key, dto, TTL);
        } catch (Exception e) {
            log.error("Redis unavailable during cache invalidation for key: {}", key);
        }
        
        return dto;
    }

    private RestaurantDto mapToDto(Restaurant restaurant) {
        return RestaurantDto.builder()
                .id(restaurant.getId())
                .ownerId(restaurant.getOwnerId())
                .name(restaurant.getName())
                .description(restaurant.getDescription())
                .address(restaurant.getAddress())
                .isOpen(restaurant.isOpen())
                .build();
    }
}
