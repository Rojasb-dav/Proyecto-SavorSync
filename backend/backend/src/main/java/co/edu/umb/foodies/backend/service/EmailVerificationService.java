package co.edu.umb.foodies.backend.service;

import co.edu.umb.foodies.backend.model.PasswordResetToken;
import co.edu.umb.foodies.backend.repository.PasswordResetTokenRepository;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.LocalDateTime;
import java.util.HexFormat;
import java.util.Locale;
import java.util.Optional;
import java.util.UUID;

@Service
public class EmailVerificationService {

    private static final int CODE_TTL_MINUTES = 15;
    private static final int MAX_ATTEMPTS = 5;
    private static final SecureRandom RANDOM = new SecureRandom();

    private final PasswordResetTokenRepository challenges;
    private final PasswordEncoder encoder;
    private final AuthRateLimitService rateLimits;
    private final ApplicationEventPublisher events;

    public EmailVerificationService(PasswordResetTokenRepository challenges,
                                    PasswordEncoder encoder,
                                    AuthRateLimitService rateLimits,
                                    ApplicationEventPublisher events) {
        this.challenges = challenges;
        this.encoder = encoder;
        this.rateLimits = rateLimits;
        this.events = events;
    }

    @Transactional
    public IssuedChallenge issue(String identityId, String email,
                                 PasswordResetToken.IdentityType identityType,
                                 PasswordResetToken.Purpose purpose, String source) {
        return issue(identityId, email, identityType, purpose, source, false);
    }

    @Transactional
    public IssuedChallenge issue(String identityId, String email,
                                 PasswordResetToken.IdentityType identityType,
                                 PasswordResetToken.Purpose purpose, String source,
                                 boolean rateLimitAlreadyRecorded) {
        String normalizedEmail = normalizeEmail(email);
        if (identityId == null || normalizedEmail.isBlank()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Identidad inválida.");
        }
        if (!rateLimitAlreadyRecorded && !checkRequestLimit(normalizedEmail, source)) {
            throw new ResponseStatusException(HttpStatus.TOO_MANY_REQUESTS,
                    "Demasiadas solicitudes. Espera antes de intentar nuevamente.");
        }

        challenges.consumeActiveForIdentity(identityId, identityType, purpose);
        String code = String.format(Locale.ROOT, "%06d", RANDOM.nextInt(1_000_000));
        LocalDateTime expiresAt = LocalDateTime.now().plusMinutes(CODE_TTL_MINUTES);
        PasswordResetToken challenge = challenges.saveAndFlush(PasswordResetToken.builder()
                .id(UUID.randomUUID().toString())
                .identityId(identityId)
                .identityType(identityType)
                .purpose(purpose)
                .email(normalizedEmail)
                .code(encoder.encode(code))
                .expiresAt(expiresAt)
                .failedAttempts(0)
                .build());

        String kind = purpose == PasswordResetToken.Purpose.EMAIL_VERIFICATION
                ? "verificación de correo" : "recuperación de contraseña";
        events.publishEvent(new SecurityEmailEvent(
                normalizedEmail,
                purpose == PasswordResetToken.Purpose.EMAIL_VERIFICATION
                        ? "Código de verificación SavorSync"
                        : "Código para recuperar tu contraseña en SavorSync",
                "Tu código de " + kind + " es: " + code
                        + "\nIdentificador de desafío: " + challenge.getId()
                        + "\nVence en 15 minutos. Si no solicitaste esto, ignora este correo."
        ));
        return new IssuedChallenge(challenge.getId(), CODE_TTL_MINUTES * 60_000L);
    }

    public boolean checkRequestLimit(String email, String source) {
        String normalized = normalizeEmail(email);
        if (normalized.isBlank()) return false;
        return rateLimits.record(
                bucketKey("identity", normalized),
                bucketKey("source", source == null ? "unknown" : source)
        );
    }

    @Transactional
    public Optional<PasswordResetToken> verify(String challengeId, String code,
                                               PasswordResetToken.Purpose purpose) {
        if (challengeId == null || challengeId.isBlank()) return Optional.empty();
        PasswordResetToken challenge = challenges.findByIdForUpdate(challengeId).orElse(null);
        if (challenge == null || challenge.getPurpose() != purpose
                || challenge.getConsumedAt() != null
                || challenge.getExpiresAt() == null
                || !challenge.getExpiresAt().isAfter(LocalDateTime.now())
                || challenge.getFailedAttempts() >= MAX_ATTEMPTS) {
            return Optional.empty();
        }

        if (code == null || !code.matches("[0-9]{6}")
                || !encoder.matches(code, challenge.getCode())) {
            challenge.setFailedAttempts(challenge.getFailedAttempts() + 1);
            if (challenge.getFailedAttempts() >= MAX_ATTEMPTS) {
                challenge.setConsumedAt(LocalDateTime.now());
            }
            challenges.save(challenge);
            return Optional.empty();
        }

        challenge.setConsumedAt(LocalDateTime.now());
        challenges.save(challenge);
        return Optional.of(challenge);
    }

    @Transactional
    public boolean consumePasswordResetChallenge(String identityId, String email, String code,
                                                 PasswordResetToken.IdentityType identityType) {
        LocalDateTime now = LocalDateTime.now();
        PasswordResetToken candidate = challenges.findActiveForUpdate(
                        identityId, identityType.name(), PasswordResetToken.Purpose.PASSWORD_RESET.name())
                .filter(c -> normalizeEmail(email).equals(c.getEmail()))
                .filter(c -> c.getExpiresAt().isAfter(now) && c.getFailedAttempts() < MAX_ATTEMPTS)
                .orElse(null);
        if (candidate == null) return false;
        if (code == null || !code.matches("[0-9]{6}") || !encoder.matches(code, candidate.getCode())) {
            candidate.setFailedAttempts(candidate.getFailedAttempts() + 1);
            if (candidate.getFailedAttempts() >= MAX_ATTEMPTS) candidate.setConsumedAt(now);
            challenges.save(candidate);
            return false;
        }
        candidate.setConsumedAt(now);
        challenges.save(candidate);
        return true;
    }

    private static String normalizeEmail(String email) {
        return email == null ? "" : email.trim().toLowerCase(Locale.ROOT);
    }

    private static String bucketKey(String namespace, String value) {
        try {
            byte[] digest = MessageDigest.getInstance("SHA-256")
                    .digest((namespace + String.valueOf((char) 0) + value)
                            .getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(digest);
        } catch (java.security.NoSuchAlgorithmException exception) {
            throw new IllegalStateException("SHA-256 unavailable", exception);
        }
    }

    public record IssuedChallenge(String challengeId, long expiresInMs) {}
}
