package co.edu.umb.foodies.backend.dto.request;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record EmailVerificationRequest(
        @Email @Size(max = 191) String email,
        @Size(max = 36) String challengeId,
        @Pattern(regexp = "[0-9]{6}") String code,
        @Size(max = 100) String password
) {
    public boolean isVerifyRequest() {
        return challengeId != null && !challengeId.isBlank()
                && code != null && !code.isBlank();
    }
}
