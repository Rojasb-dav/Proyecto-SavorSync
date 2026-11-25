package co.edu.umb.foodies.backend.service;

import co.edu.umb.foodies.backend.dto.request.LoginRequest;
import co.edu.umb.foodies.backend.dto.request.RegisterRequest;
import co.edu.umb.foodies.backend.dto.response.AuthResponse;
import co.edu.umb.foodies.backend.model.ClientSession;
import co.edu.umb.foodies.backend.model.PasswordResetToken;
import co.edu.umb.foodies.backend.model.User;
import co.edu.umb.foodies.backend.repository.ClientSessionRepository;
import co.edu.umb.foodies.backend.repository.EmployeeRepository;
import co.edu.umb.foodies.backend.repository.EmployeeSessionRepository;
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
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.mockito.Mockito.anyString;
import static org.mockito.Mockito.never;

@ExtendWith(MockitoExtension.class)
class AuthServiceSessionTest {

    private static final long EXPIRATION_MS = 60_000;
    private static final String EMAIL = "sesiones@example.test";
    private static final String PASSWORD = "contraseña-de-prueba";
    private static final String ENCODED_PASSWORD = "hash-de-prueba";
    private static final String RESET_CODE = "123456";

    @Mock private UserRepository users;
    @Mock private EmployeeRepository employeeRepository;
    @Mock private ClientSessionRepository clientSessionRepository;
    @Mock private EmployeeSessionRepository employeeSessionRepository;
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
        service = new AuthService(users, employeeRepository, clientSessionRepository, employeeSessionRepository, resetTokens, passwordEncoder, jwtUtil, mailSender);
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

        ArgumentCaptor<ClientSession> saved = ArgumentCaptor.forClass(ClientSession.class);
        verify(clientSessionRepository).saveAndFlush(saved.capture());
        ClientSession session = saved.getValue();
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
        when(clientSessionRepository.saveAndFlush(any(ClientSession.class))).thenThrow(error);

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
        when(clientSessionRepository.saveAndFlush(any(ClientSession.class))).thenThrow(error);

        assertThatThrownBy(() -> service.register(request, new MockHttpServletRequest()))
                .isSameAs(error);
    }

    @Test
    void logoutRevokesSessionFoundByDigest() {
        String token = jwtUtil.issueToken(user.getId(), EMAIL, user.getRole().name()).token();
        String key = jwtUtil.sessionTokenKey(token);
        ClientSession session = ClientSession.builder()
                .userId(user.getId())
                .sessionToken(key)
                .isActive(true)
                .build();
        when(clientSessionRepository.findBySessionTokenAndIsActiveTrue(key)).thenReturn(Optional.of(session));

        service.logout(token);

        assertThat(session.getIsActive()).isFalse();
        verify(clientSessionRepository).save(session);
    }

    @Test
    void resettingPasswordRevokesAllSessionsForThatAccount() {
        PasswordResetToken code = resetToken(LocalDateTime.now().plusMinutes(1));
        when(resetTokens.findAll()).thenReturn(List.of(code));
        when(passwordEncoder.matches(RESET_CODE, code.getCode())).thenReturn(true);
        when(users.findByEmail(EMAIL)).thenReturn(Optional.of(user));
        String newPassword = "nueva-contraseña-de-prueba";
        String newHash = "nuevo-hash-de-prueba";
        when(passwordEncoder.encode(newPassword)).thenReturn(newHash);

        ClientSession s1 = ClientSession.builder().userId(user.getId()).isActive(true).build();
        when(clientSessionRepository.findAll()).thenReturn(List.of(s1));

        service.resetPassword(EMAIL, RESET_CODE, newPassword);

        verify(users).save(user);
        verify(resetTokens).delete(code);
        verify(clientSessionRepository).save(s1);
        assertThat(s1.getIsActive()).isFalse();
        assertThat(user.getPassword()).isEqualTo(newHash);
    }

    @Test
    void expiredResetCodeDoesNotRevokeSessionsOrUpdateUser() {
        PasswordResetToken code = resetToken(LocalDateTime.now().minusMinutes(1));
        when(resetTokens.findAll()).thenReturn(List.of(code));
        when(passwordEncoder.matches(RESET_CODE, code.getCode())).thenReturn(true);

        assertThatThrownBy(() -> service.resetPassword(EMAIL, RESET_CODE, PASSWORD))
                .isInstanceOfSatisfying(ResponseStatusException.class,
                        error -> assertThat(error.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST));

        verifyNoInteractions(clientSessionRepository, users);
    }

    private void allowLogin() {
        when(users.findByEmail(EMAIL)).thenReturn(Optional.of(user));
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