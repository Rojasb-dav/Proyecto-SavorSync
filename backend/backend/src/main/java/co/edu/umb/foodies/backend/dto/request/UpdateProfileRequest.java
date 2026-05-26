package co.edu.umb.foodies.backend.dto.request;

import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class UpdateProfileRequest {

    @Size(max = 150)
    private String fullName;

    @Size(max = 1000)
    private String bio;

    @Size(max = 30)
    private String phone;

    @Size(max = 60)
    private String username;
}
