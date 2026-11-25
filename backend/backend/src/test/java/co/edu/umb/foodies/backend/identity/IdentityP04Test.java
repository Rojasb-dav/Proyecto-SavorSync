package co.edu.umb.foodies.backend.identity;

import co.edu.umb.foodies.backend.dto.request.RegisterRequest;
import co.edu.umb.foodies.backend.dto.request.UpdateProfileRequest;
import co.edu.umb.foodies.backend.model.User;
import co.edu.umb.foodies.backend.repository.ClientSessionRepository;
import co.edu.umb.foodies.backend.repository.EmployeeRepository;
import co.edu.umb.foodies.backend.repository.EmployeeSessionRepository;
import co.edu.umb.foodies.backend.repository.PasswordResetTokenRepository;
import co.edu.umb.foodies.backend.repository.UserRepository;
import co.edu.umb.foodies.backend.security.jwt.JwtUtil;
import co.edu.umb.foodies.backend.service.AccountIdentityRegistry;
import co.edu.umb.foodies.backend.service.AuthService;
import co.edu.umb.foodies.backend.service.EmailVerificationService;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.server.ResponseStatusException;

import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;
import static org.mockito.Mockito.verifyNoInteractions;

class IdentityP04Test {

    private final ObjectMapper objectMapper = new ObjectMapper();

    @Test
    void profileUpdateIgnoresClientSuppliedEmailVerification() throws Exception {
        UpdateProfileRequest request = objectMapper.readValue(
                "{\"emailVerified\":true,\"bio\":\"Updated\"}", UpdateProfileRequest.class);

        assertEquals("Updated", request.getBio());
        assertFalse(objectMapper.valueToTree(request).has("emailVerified"));
    }

    @Test
    void publicRegistrationRejectsPrivilegedRoleInsteadOfTrustingTheRequest() throws Exception {
        RegisterRequest request = objectMapper.readValue("""
                {"email":"foodie@example.test","username":"foodie1","password":"secret-1",
                 "fullName":"Foodie","role":"admin_sistema"}
                """, RegisterRequest.class);
        AuthService service = authService(
                mock(UserRepository.class),
                mock(EmployeeRepository.class),
                mock(ClientSessionRepository.class),
                mock(EmployeeSessionRepository.class),
                mock(PasswordResetTokenRepository.class),
                mock(AccountIdentityRegistry.class),
                mock(PasswordEncoder.class),
                mock(EmailVerificationService.class));

        assertThrows(ResponseStatusException.class,
                () -> service.register(request, null));
    }

    @Test
    void restaurantAdminSelectionRegistersFoodieAndWaitsForVerification() throws Exception {
        RegisterRequest request = objectMapper.readValue("""
                {"email":"foodie@example.test","username":"foodie1","password":"secret-1",
                 "fullName":"Foodie","role":"restaurant_admin"}
                """, RegisterRequest.class);

        UserRepository users = mock(UserRepository.class);
        EmployeeRepository employees = mock(EmployeeRepository.class);
        AccountIdentityRegistry identities = mock(AccountIdentityRegistry.class);
        PasswordEncoder passwords = mock(PasswordEncoder.class);
        EmailVerificationService challenges = mock(EmailVerificationService.class);
        ClientSessionRepository sessions = mock(ClientSessionRepository.class);
        when(users.existsByEmail("foodie@example.test")).thenReturn(false);
        when(employees.existsByEmail("foodie@example.test")).thenReturn(false);
        when(users.existsByUsername("foodie1")).thenReturn(false);
        when(employees.existsByUsername("foodie1")).thenReturn(false);
        when(passwords.encode("secret-1")).thenReturn("encoded");
        when(users.saveAndFlush(any(User.class))).thenAnswer(invocation -> invocation.getArgument(0));
        when(challenges.issue(any(), any(), any(), any(), any()))
                .thenReturn(new EmailVerificationService.IssuedChallenge("challenge-1", 900_000));

        var response = authService(users, employees, sessions,
                mock(EmployeeSessionRepository.class), mock(PasswordResetTokenRepository.class),
                identities, passwords, challenges).register(request, null);

        assertEquals("restaurant_admin", response.requestedRole());
        assertTrue(response.verificationRequired());
        ArgumentCaptor<User> saved = ArgumentCaptor.forClass(User.class);
        verify(users).saveAndFlush(saved.capture());
        assertEquals(User.Role.foodie, saved.getValue().getRole());
        assertFalse(saved.getValue().getEmailVerified());
        verifyNoInteractions(sessions);
    }

    private static AuthService authService(
            UserRepository users,
            EmployeeRepository employees,
            ClientSessionRepository clientSessions,
            EmployeeSessionRepository employeeSessions,
            PasswordResetTokenRepository resetTokens,
            AccountIdentityRegistry identities,
            PasswordEncoder passwords,
            EmailVerificationService challenges) {
        return new AuthService(users, employees, clientSessions, employeeSessions,
                resetTokens, identities, passwords,
                new JwtUtil("0123456789abcdef0123456789abcdef", 60_000),
                challenges);
    }
}
