package co.edu.umb.foodies.backend.service;

import co.edu.umb.foodies.backend.dto.request.LoginRequest;
import co.edu.umb.foodies.backend.dto.request.RegisterRequest;
import co.edu.umb.foodies.backend.dto.response.AuthResponse;
import co.edu.umb.foodies.backend.model.AuthSession;
import co.edu.umb.foodies.backend.model.PasswordResetToken;
import co.edu.umb.foodies.backend.model.User;
import co.edu.umb.foodies.backend.repository.AuthSessionRepository;
import co.edu.umb.foodies.backend.repository.PasswordResetTokenRepository;
import co.edu.umb.foodies.backend.repository.UserRepository;
import co.edu.umb.foodies.backend.security.jwt.JwtUtil;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.server.ResponseStatusException;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.LocalDateTime;
import java.util.Base64;
import java.util.HexFormat;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class AuthServiceSessionTest {

    private static final long EXPIRATION_MS = 60_000;
    private static final String EMAIL = "sesiones@example.test";
    private static final String PASSWORD = "contraseña-de-prueba";
    private static final String ENCODED_PASSWORD = "hash-de-prueba";
    private static final String RESET_CODE = "123456";

    @Mock private UserRepository users;
    @Mock private AuthSessionRepository sessions;
    @Mock private PasswordResetTokenRepository resetTokens;
    @Mock private PasswordEncoder passwordEncoder;
    @Mock private JavaMailSender mailSender;

    private User user;
    private JwtUtil jwtUtil;
    private AuthService service;

    @BeforeEach
    void setUp() {
        byte[] key = new byte[32];
        new SecureRandom().nextBytes(key);
        jwtUtil = new JwtUtil(Base64.getEncoder().encodeToString(key), EXPIRATION_MS);
        service = new AuthService(users, sessions, resetTokens, passwordEncoder, jwtUtil, mailSender);
        user = User.builder()
                .id(UUID.randomUUID().toString())
                .email(EMAIL)
                .username("sesiones")
                .fullName("Usuario de prueba")
                .role(User.Role.foodie)
                .password(ENCODED_PASSWORD)
                .isActive(true)
                .build();
    }

    @Test
    void loginFlushesCompactTokenDigestAndReturnsMatchingExpiry() throws Exception {
        allowLogin();
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.addHeader("X-Platform", "mobile");

        AuthResponse response = service.login(loginRequest(), request);

        ArgumentCaptor<AuthSession> saved = ArgumentCaptor.forClass(AuthSession.class);
        verify(sessions).saveAndFlush(saved.capture());
        AuthSession session = saved.getValue();
        String jwt = response.getToken();
        var claims = jwtUtil.parse(jwt);
        String sha256 = HexFormat.of().formatHex(
                MessageDigest.getInstance("SHA-256").digest(jwt.getBytes(StandardCharsets.UTF_8)));

        assertThat(jwt.length()).isGreaterThan(191);
        assertThat(session.getSessionToken()).isEqualTo("v1:" + sha256);
        assertThat(session.getUserId()).isEqualTo(user.getId());
        assertThat(session.getIsActive()).isTrue();
        assertThat(session.getExpiresAt()).isEqualTo(claims.getExpiration().toInstant());
        assertThat(response.getTokenType()).isEqualTo("Bearer");
        assertThat(response.getExpiresInMs()).isPositive().isLessThanOrEqualTo(EXPIRATION_MS);
        assertThat(response.getUser().getId()).isEqualTo(user.getId());
    }

    @Test
    void loginPropagatesPersistenceFailure() {
        allowLogin();
        var error = new DataIntegrityViolationException("No se pudo persistir la sesión");
        when(sessions.saveAndFlush(any(AuthSession.class))).thenThrow(error);

        assertThatThrownBy(() -> service.login(loginRequest(), new MockHttpServletRequest()))
                .isSameAs(error);
    }

    @Test
    void registrationPropagatesPersistenceFailure() {
        RegisterRequest request = new RegisterRequest();
        request.setEmail(EMAIL);
        request.setUsername("sesiones");
        request.setPassword(PASSWORD);

        when(passwordEncoder.encode(PASSWORD)).thenReturn(ENCODED_PASSWORD);
        when(users.save(any(User.class))).thenAnswer(invocation -> {
            User registered = invocation.getArgument(0);
            registered.prePersist();
            return registered;
        });
        var error = new DataIntegrityViolationException("No se pudo persistir la sesión");
        when(sessions.saveAndFlush(any(AuthSession.class))).thenThrow(error);

        assertThatThrownBy(() -> service.register(request, new MockHttpServletRequest()))
                .isSameAs(error);
    }

    @Test
    void logoutRevokesSessionFoundByDigest() {
        String token = jwtUtil.issueToken(user.getId(), EMAIL, user.getRole().name()).token();
        String key = jwtUtil.sessionTokenKey(token);
        AuthSession session = AuthSession.builder()
                .userId(user.getId())
                .sessionToken(key)
                .isActive(true)
                .build();
        when(sessions.findBySessionTokenAndIsActiveTrue(key)).thenReturn(Optional.of(session));

        service.logout(token);

        assertThat(session.getIsActive()).isFalse();
        verify(sessions).save(session);
    }

    @Test
    void resettingPasswordRevokesAllSessionsForThatAccount() {
        PasswordResetToken code = resetToken(LocalDateTime.now().plusMinutes(1));
        when(resetTokens.findByEmailAndCode(EMAIL, RESET_CODE)).thenReturn(Optional.of(code));
        when(users.findByEmailForUpdate(EMAIL)).thenReturn(Optional.of(user));
        String newPassword = "nueva-contraseña-de-prueba";
        String newHash = "nuevo-hash-de-prueba";
        when(passwordEncoder.encode(newPassword)).thenReturn(newHash);

        service.resetPassword(EMAIL, RESET_CODE, newPassword);

        verify(users).save(user);
        verify(resetTokens).delete(code);
        verify(sessions).revokeAllByUserId(user.getId());
        assertThat(user.getPassword()).isEqualTo(newHash);
    }

    @Test
    void expiredResetCodeDoesNotRevokeSessionsOrUpdateUser() {
        PasswordResetToken code = resetToken(LocalDateTime.now().minusMinutes(1));
        when(resetTokens.findByEmailAndCode(EMAIL, RESET_CODE)).thenReturn(Optional.of(code));

        assertThatThrownBy(() -> service.resetPassword(EMAIL, RESET_CODE, PASSWORD))
                .isInstanceOfSatisfying(ResponseStatusException.class,
                        error -> assertThat(error.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST));

        verifyNoInteractions(sessions, users, passwordEncoder);
    }

    private void allowLogin() {
        when(users.findByEmailForUpdate(EMAIL)).thenReturn(Optional.of(user));
        when(passwordEncoder.matches(PASSWORD, ENCODED_PASSWORD)).thenReturn(true);
    }

    private LoginRequest loginRequest() {
        LoginRequest request = new LoginRequest();
        request.setEmail(EMAIL);
        request.setPassword(PASSWORD);
        return request;
    }

    private PasswordResetToken resetToken(LocalDateTime expiresAt) {
        return PasswordResetToken.builder()
                .email(EMAIL)
                .code(RESET_CODE)
                .expiresAt(expiresAt)
                .build();
    }
}
