package co.edu.umb.foodies.backend.service;

import co.edu.umb.foodies.backend.dto.request.LoginRequest;
import co.edu.umb.foodies.backend.dto.request.RegisterRequest;
import co.edu.umb.foodies.backend.dto.response.AuthResponse;
import co.edu.umb.foodies.backend.dto.response.RegistrationResponse;
import co.edu.umb.foodies.backend.model.ClientSession;
import co.edu.umb.foodies.backend.model.User;
import co.edu.umb.foodies.backend.repository.ClientSessionRepository;
import co.edu.umb.foodies.backend.repository.EmployeeRepository;
import co.edu.umb.foodies.backend.repository.EmployeeSessionRepository;
import co.edu.umb.foodies.backend.repository.PasswordResetTokenRepository;
import co.edu.umb.foodies.backend.repository.UserRepository;
import co.edu.umb.foodies.backend.security.jwt.JwtUtil;
import jakarta.servlet.http.HttpServletRequest;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.server.ResponseStatusException;

import java.security.SecureRandom;
import java.util.Base64;
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

    @Mock private UserRepository users;
    @Mock private EmployeeRepository employees;
    @Mock private ClientSessionRepository clientSessions;
    @Mock private EmployeeSessionRepository employeeSessions;
    @Mock private PasswordResetTokenRepository resetTokens;
    @Mock private AccountIdentityRegistry identities;
    @Mock private PasswordEncoder passwordEncoder;
    @Mock private EmailVerificationService challenges;

    private User user;
    private JwtUtil jwtUtil;
    private AuthService service;

    @BeforeEach
    void setUp() {
        byte[] key = new byte[32];
        new SecureRandom().nextBytes(key);
        jwtUtil = new JwtUtil(Base64.getEncoder().encodeToString(key), EXPIRATION_MS);
        service = new AuthService(users, employees, clientSessions, employeeSessions,
                resetTokens, identities, passwordEncoder, jwtUtil, challenges);
        user = User.builder()
                .id(UUID.randomUUID().toString())
                .email(EMAIL)
                .username("sesiones")
                .fullName("Usuario de prueba")
                .role(User.Role.foodie)
                .password(ENCODED_PASSWORD)
                .isActive(true)
                .emailVerified(true)
                .build();
    }

    @Test
    void loginFlushesCompactTokenDigestAndReturnsMatchingExpiry() throws Exception {
        allowLogin();
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.addHeader("X-Platform", "mobile");

        AuthResponse response = service.login(loginRequest(), request);

        ArgumentCaptor<ClientSession> saved = ArgumentCaptor.forClass(ClientSession.class);
        verify(clientSessions).saveAndFlush(saved.capture());
        ClientSession session = saved.getValue();
        String jwt = response.getToken();
        var claims = jwtUtil.parse(jwt);

        assertThat(jwt.length()).isGreaterThan(191);
        assertThat(session.getSessionToken()).isEqualTo(jwtUtil.sessionTokenKey(jwt));
        assertThat(session.getUserId()).isEqualTo(user.getId());
        assertThat(session.getIsActive()).isTrue();
        assertThat(session.getPlatform()).isEqualTo(ClientSession.Platform.mobile);
        assertThat(session.getExpiresAt()).isEqualTo(claims.getExpiration().toInstant());
        assertThat(response.getTokenType()).isEqualTo("Bearer");
        assertThat(response.getExpiresInMs()).isPositive().isLessThanOrEqualTo(EXPIRATION_MS);
        assertThat(response.getUser().getId()).isEqualTo(user.getId());
        assertThat(response.getUser().getEmailVerified()).isTrue();
    }

    @Test
    void webPlatformIsRecordedAsDeclaredButDoesNotChangeAuthorizationRole() {
        allowLogin();
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.addHeader("X-Platform", "web");

        service.login(loginRequest(), request);

        ArgumentCaptor<ClientSession> saved = ArgumentCaptor.forClass(ClientSession.class);
        verify(clientSessions).saveAndFlush(saved.capture());
        assertThat(saved.getValue().getPlatform()).isEqualTo(ClientSession.Platform.web_restaurante);
    }

    @Test
    void loginPropagatesPersistenceFailureWithoutReturningToken() {
        allowLogin();
        var error = new DataIntegrityViolationException("session insert failed");
        when(clientSessions.saveAndFlush(any(ClientSession.class))).thenThrow(error);

        assertThatThrownBy(() -> service.login(loginRequest(), new MockHttpServletRequest()))
                .isSameAs(error);
    }

    @Test
    void unverifiedAccountCannotStartANormalSession() {
        user.setEmailVerified(false);
        allowLogin();

        assertThatThrownBy(() -> service.login(loginRequest(), new MockHttpServletRequest()))
                .isInstanceOfSatisfying(ResponseStatusException.class,
                        error -> assertThat(error.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN));
        verifyNoInteractions(clientSessions);
    }

    @Test
    void registrationPersistsAnUnverifiedAccountWithoutIssuingASession() {
        RegisterRequest request = new RegisterRequest();
        request.setEmail(EMAIL);
        request.setUsername("sesiones");
        request.setPassword(PASSWORD);
        request.setFullName("Usuario de prueba");
        request.setRole("restaurant_admin");

        when(users.existsByEmail(EMAIL)).thenReturn(false);
        when(employees.existsByEmail(EMAIL)).thenReturn(false);
        when(users.existsByUsername("sesiones")).thenReturn(false);
        when(employees.existsByUsername("sesiones")).thenReturn(false);
        when(passwordEncoder.encode(PASSWORD)).thenReturn(ENCODED_PASSWORD);
        when(users.saveAndFlush(any(User.class))).thenAnswer(invocation -> invocation.getArgument(0));
        when(challenges.issue(any(), any(), any(), any(), any()))
                .thenReturn(new EmailVerificationService.IssuedChallenge("challenge-id", 900_000));

        RegistrationResponse response = service.register(request, new MockHttpServletRequest());

        ArgumentCaptor<User> saved = ArgumentCaptor.forClass(User.class);
        verify(users).saveAndFlush(saved.capture());
        assertThat(saved.getValue().getRole()).isEqualTo(User.Role.foodie);
        assertThat(saved.getValue().getEmailVerified()).isFalse();
        assertThat(response.verificationRequired()).isTrue();
        assertThat(response.challengeId()).isEqualTo("challenge-id");
        assertThat(response.requestedRole()).isEqualTo("restaurant_admin");
        verify(identities).register("client", saved.getValue().getId(), EMAIL, "sesiones", "restaurant_admin");
        verifyNoInteractions(clientSessions, employeeSessions);
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
        when(clientSessions.findBySessionTokenAndIsActiveTrue(key)).thenReturn(Optional.of(session));

        service.logout(token);

        assertThat(session.getIsActive()).isFalse();
        verify(clientSessions).save(session);
    }

    @Test
    void resettingPasswordConsumesCodeAndRevokesOnlyThatAccountSessions() {
        when(users.findByEmail(EMAIL)).thenReturn(Optional.of(user));
        when(employees.findByEmail(EMAIL)).thenReturn(Optional.empty());
        when(challenges.consumePasswordResetChallenge(
                EMAIL, "123456", co.edu.umb.foodies.backend.model.PasswordResetToken.IdentityType.client))
                .thenReturn(true);
        when(passwordEncoder.encode("new-password-test")).thenReturn("new-hash");

        assertThat(service.resetPassword(EMAIL, "123456", "new-password-test")).isTrue();

        verify(users).save(user);
        verify(challenges).consumePasswordResetChallenge(
                EMAIL, "123456", co.edu.umb.foodies.backend.model.PasswordResetToken.IdentityType.client);
        verify(clientSessions).revokeActiveByUserId(user.getId());
        assertThat(user.getPassword()).isEqualTo("new-hash");
    }

    @Test
    void invalidResetCodeDoesNotUpdatePasswordOrRevokeSessions() {
        when(users.findByEmail(EMAIL)).thenReturn(Optional.of(user));
        when(employees.findByEmail(EMAIL)).thenReturn(Optional.empty());
        when(challenges.consumePasswordResetChallenge(
                EMAIL, "000000", co.edu.umb.foodies.backend.model.PasswordResetToken.IdentityType.client))
                .thenReturn(false);

        assertThat(service.resetPassword(EMAIL, "000000", "new-password-test")).isFalse();

        verify(users, org.mockito.Mockito.never()).save(any(User.class));
        verifyNoInteractions(clientSessions);
    }

    private void allowLogin() {
        when(users.findByEmail(EMAIL)).thenReturn(Optional.of(user));
        when(employees.findByEmail(EMAIL)).thenReturn(Optional.empty());
        when(passwordEncoder.matches(PASSWORD, ENCODED_PASSWORD)).thenReturn(true);
    }

    private LoginRequest loginRequest() {
        LoginRequest request = new LoginRequest();
        request.setEmail(EMAIL);
        request.setPassword(PASSWORD);
        return request;
    }
}
