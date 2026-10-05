package com.foodflow.restaurant.repository;

import com.foodflow.restaurant.entity.Restaurant;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface RestaurantRepository extends JpaRepository<Restaurant, Long> {
    Page<Restaurant> findByIsOpenTrue(Pageable pageable);
    List<Restaurant> findByOwnerId(Long ownerId);
    Optional<Restaurant> findByIdAndOwnerId(Long id, Long ownerId);
}
