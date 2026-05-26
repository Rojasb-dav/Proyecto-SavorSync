package co.edu.umb.foodies.backend.dto.request;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class RegisterRequest {

    @NotBlank
    @Email
    private String email;

    @NotBlank
    @Size(min = 3, max = 60)
    private String username;

    @NotBlank
    @Size(min = 6, max = 100)
    private String password;

    @Size(max = 150)
    private String fullName;

    private String role; // optional: foodie | restaurant_admin | moderator
}
