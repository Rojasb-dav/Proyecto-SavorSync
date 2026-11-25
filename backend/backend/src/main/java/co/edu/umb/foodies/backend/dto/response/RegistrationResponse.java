package co.edu.umb.foodies.backend.dto.response;

public record RegistrationResponse(
        boolean verificationRequired,
        String challengeId,
        long expiresInMs,
        String requestedRole
) {}
