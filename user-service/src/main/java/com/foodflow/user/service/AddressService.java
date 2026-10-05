package com.foodflow.user.service;

import com.foodflow.user.dto.AddressDto;
import com.foodflow.user.entity.Address;
import com.foodflow.user.entity.User;
import com.foodflow.user.exception.ResourceNotFoundException;
import com.foodflow.user.repository.AddressRepository;
import com.foodflow.user.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class AddressService {

    private final AddressRepository addressRepository;
    private final UserRepository userRepository;

    public AddressDto addAddress(String userEmail, AddressDto addressDto) {
        User user = userRepository.findByEmail(userEmail)
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));

        Address address = Address.builder()
                .user(user)
                .street(addressDto.getStreet())
                .city(addressDto.getCity())
                .state(addressDto.getState())
                .zipCode(addressDto.getZipCode())
                .country(addressDto.getCountry())
                .build();

        address = addressRepository.save(address);

        return mapToDto(address);
    }

    public List<AddressDto> getUserAddresses(String userEmail) {
        User user = userRepository.findByEmail(userEmail)
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));

        return addressRepository.findByUserId(user.getId())
                .stream()
                .map(this::mapToDto)
                .collect(Collectors.toList());
    }

    public AddressDto updateAddress(Long addressId, String userEmail, AddressDto addressDto) {
        Address address = addressRepository.findById(addressId)
                .orElseThrow(() -> new ResourceNotFoundException("Address not found"));

        if (!address.getUser().getEmail().equals(userEmail)) {
            throw new ResourceNotFoundException("Address not found for this user");
        }

        address.setStreet(addressDto.getStreet());
        address.setCity(addressDto.getCity());
        address.setState(addressDto.getState());
        address.setZipCode(addressDto.getZipCode());
        address.setCountry(addressDto.getCountry());

        address = addressRepository.save(address);

        return mapToDto(address);
    }

    public void deleteAddress(Long addressId, String userEmail) {
        Address address = addressRepository.findById(addressId)
                .orElseThrow(() -> new ResourceNotFoundException("Address not found"));

        if (!address.getUser().getEmail().equals(userEmail)) {
            throw new ResourceNotFoundException("Address not found for this user");
        }

        addressRepository.delete(address);
    }

    private AddressDto mapToDto(Address address) {
        return AddressDto.builder()
                .id(address.getId())
                .street(address.getStreet())
                .city(address.getCity())
                .state(address.getState())
                .zipCode(address.getZipCode())
                .country(address.getCountry())
                .build();
    }
}
