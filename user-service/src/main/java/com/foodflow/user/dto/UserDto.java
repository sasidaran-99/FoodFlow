package com.foodflow.user.dto;

import com.foodflow.user.entity.Role;
import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class UserDto {
    private Long id;
    private String name;
    private String email;
    private String phone;
    private Role role;
}
