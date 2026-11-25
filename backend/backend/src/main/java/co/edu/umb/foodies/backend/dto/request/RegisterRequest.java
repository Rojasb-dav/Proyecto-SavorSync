package co.edu.umb.foodies.backend.dto.request;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class RegisterRequest {

    @NotBlank
    @Email
    @Size(max = 191)
    private String email;

    @NotBlank
    @Size(min = 3, max = 50)
    private String username;

    @NotBlank
    @Size(min = 8, max = 100)
    private String password;

    @Size(max = 100)
    private String fullName;

    @Size(max = 50)
    private String role;
}
