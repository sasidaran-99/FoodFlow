package com.foodflow.user.controller;

import com.foodflow.user.dto.AddressDto;
import com.foodflow.user.service.AddressService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/users/addresses")
@RequiredArgsConstructor
public class AddressController {

    private final AddressService addressService;

    @PostMapping
    public ResponseEntity<AddressDto> addAddress(Authentication authentication, @Valid @RequestBody AddressDto addressDto) {
        String email = authentication.getName();
        return new ResponseEntity<>(addressService.addAddress(email, addressDto), HttpStatus.CREATED);
    }

    @GetMapping
    public ResponseEntity<List<AddressDto>> getAddresses(Authentication authentication) {
        String email = authentication.getName();
        return ResponseEntity.ok(addressService.getUserAddresses(email));
    }

    @PutMapping("/{id}")
    public ResponseEntity<AddressDto> updateAddress(Authentication authentication,
                                                    @PathVariable Long id,
                                                    @Valid @RequestBody AddressDto addressDto) {
        String email = authentication.getName();
        return ResponseEntity.ok(addressService.updateAddress(id, email, addressDto));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteAddress(Authentication authentication, @PathVariable Long id) {
        String email = authentication.getName();
        addressService.deleteAddress(id, email);
        return ResponseEntity.noContent().build();
    }
}
