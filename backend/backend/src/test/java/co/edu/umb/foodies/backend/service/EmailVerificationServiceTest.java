package co.edu.umb.foodies.backend.service;

import co.edu.umb.foodies.backend.model.PasswordResetToken;
import co.edu.umb.foodies.backend.repository.PasswordResetTokenRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.time.LocalDateTime;
import java.util.Optional;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class EmailVerificationServiceTest {

    @Mock private PasswordResetTokenRepository challenges;
    @Mock private PasswordEncoder encoder;
    @Mock private AuthRateLimitService rateLimits;
    @Mock private ApplicationEventPublisher events;

    private EmailVerificationService service;

    @BeforeEach
    void setUp() {
        service = new EmailVerificationService(challenges, encoder, rateLimits, events);
    }

    @Test
    void issuesSixDigitHashedPurposeBoundChallengeWithoutReturningTheCode() {
        when(rateLimits.record(anyString(), anyString())).thenReturn(true);
        when(encoder.encode(anyString())).thenReturn("bcrypt-hash");
        when(challenges.saveAndFlush(any(PasswordResetToken.class)))
                .thenAnswer(invocation -> invocation.getArgument(0));

        EmailVerificationService.IssuedChallenge issued = service.issue(
                "client-id",
                " User@Example.test ",
                PasswordResetToken.IdentityType.client,
                PasswordResetToken.Purpose.EMAIL_VERIFICATION,
                "127.0.0.1");

        ArgumentCaptor<PasswordResetToken> saved = ArgumentCaptor.forClass(PasswordResetToken.class);
        verify(challenges).saveAndFlush(saved.capture());
        ArgumentCaptor<Object> eventCaptor = ArgumentCaptor.forClass(Object.class);
        verify(events).publishEvent(eventCaptor.capture());

        PasswordResetToken challenge = saved.getValue();
        SecurityEmailEvent event = (SecurityEmailEvent) eventCaptor.getValue();
        Matcher code = Pattern.compile("(?<![0-9])[0-9]{6}(?![0-9])").matcher(event.text());
        assertThat(code.find()).isTrue();
        assertThat(challenge.getCode()).isEqualTo("bcrypt-hash");
        assertThat(challenge.getEmail()).isEqualTo("user@example.test");
        assertThat(challenge.getIdentityId()).isEqualTo("client-id");
        assertThat(challenge.getIdentityType()).isEqualTo(PasswordResetToken.IdentityType.client);
        assertThat(challenge.getPurpose()).isEqualTo(PasswordResetToken.Purpose.EMAIL_VERIFICATION);
        assertThat(challenge.getFailedAttempts()).isZero();
        assertThat(challenge.getExpiresAt()).isAfter(LocalDateTime.now().plusMinutes(14));
        assertThat(issued.challengeId()).isEqualTo(challenge.getId());
        assertThat(issued.expiresInMs()).isEqualTo(900_000);
    }

    @Test
    void successfulVerificationConsumesChallengeAndCannotBeReused() {
        PasswordResetToken challenge = challenge();
        when(challenges.findByIdForUpdate("challenge-id")).thenReturn(Optional.of(challenge));
        when(encoder.matches("123456", "bcrypt-hash")).thenReturn(true);

        assertThat(service.verify("challenge-id", "123456",
                PasswordResetToken.Purpose.EMAIL_VERIFICATION)).contains(challenge);
        assertThat(challenge.getConsumedAt()).isNotNull();
        assertThat(service.verify("challenge-id", "123456",
                PasswordResetToken.Purpose.EMAIL_VERIFICATION)).isEmpty();
    }

    @Test
    void challengePurposeMustMatchTheRequestedOperation() {
        PasswordResetToken challenge = challenge();
        when(challenges.findByIdForUpdate("challenge-id")).thenReturn(Optional.of(challenge));

        assertThat(service.verify("challenge-id", "123456",
                PasswordResetToken.Purpose.PASSWORD_RESET)).isEmpty();
        verify(challenges, never()).save(any(PasswordResetToken.class));
        verifyNoInteractions(encoder);
    }

    @Test
    void wrongCodeIncrementsPersistentAttemptCount() {
        PasswordResetToken challenge = challenge();
        when(challenges.findByIdForUpdate("challenge-id")).thenReturn(Optional.of(challenge));
        when(encoder.matches("000000", "bcrypt-hash")).thenReturn(false);

        assertThat(service.verify("challenge-id", "000000",
                PasswordResetToken.Purpose.EMAIL_VERIFICATION)).isEmpty();

        assertThat(challenge.getFailedAttempts()).isEqualTo(1);
        verify(challenges).save(challenge);
    }

    @Test
    void expiredChallengeCannotBeConsumedOrCountedAsAnAttempt() {
        PasswordResetToken challenge = challenge();
        challenge.setExpiresAt(LocalDateTime.now().minusSeconds(1));
        when(challenges.findByIdForUpdate("challenge-id")).thenReturn(Optional.of(challenge));

        assertThat(service.verify("challenge-id", "123456",
                PasswordResetToken.Purpose.EMAIL_VERIFICATION)).isEmpty();
        assertThat(challenge.getFailedAttempts()).isZero();
        verify(challenges, never()).save(any(PasswordResetToken.class));
    }

    private PasswordResetToken challenge() {
        return PasswordResetToken.builder()
                .id("challenge-id")
                .identityId("client-id")
                .identityType(PasswordResetToken.IdentityType.client)
                .purpose(PasswordResetToken.Purpose.EMAIL_VERIFICATION)
                .email("user@example.test")
                .code("bcrypt-hash")
                .expiresAt(LocalDateTime.now().plusMinutes(15))
                .failedAttempts(0)
                .build();
    }
}
