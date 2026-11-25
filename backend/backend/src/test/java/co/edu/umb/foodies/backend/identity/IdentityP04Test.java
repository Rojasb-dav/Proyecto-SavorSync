package co.edu.umb.foodies.backend.identity;

import co.edu.umb.foodies.backend.dto.request.RegisterRequest;
import co.edu.umb.foodies.backend.dto.request.UpdateProfileRequest;
import co.edu.umb.foodies.backend.model.AuthSession;
import co.edu.umb.foodies.backend.model.User;
import co.edu.umb.foodies.backend.repository.AuthSessionRepository;
import co.edu.umb.foodies.backend.repository.PasswordResetTokenRepository;
import co.edu.umb.foodies.backend.repository.UserRepository;
import co.edu.umb.foodies.backend.security.jwt.JwtUtil;
import co.edu.umb.foodies.backend.service.AuthService;
import co.edu.umb.foodies.backend.service.identity.EmailVerificationService;
import co.edu.umb.foodies.backend.service.identity.IdentityService;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.http.HttpServletRequest;
import org.junit.jupiter.api.Test;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.server.ResponseStatusException;

import java.time.Instant;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

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
    void publicRegistrationIgnoresPrivilegedRoleAndCreatesFoodie() throws Exception {
        RegisterRequest request = objectMapper.readValue("""
                {"email":"foodie@example.test","username":"foodie1","password":"secret1",
                 "fullName":"Foodie","role":"admin_sistema"}
                """, RegisterRequest.class);

        UserRepository users = mock(UserRepository.class);
        AuthSessionRepository sessions = mock(AuthSessionRepository.class);
        PasswordResetTokenRepository resets = mock(PasswordResetTokenRepository.class);
        PasswordEncoder passwords = mock(PasswordEncoder.class);
        JwtUtil jwt = mock(JwtUtil.class);
        JavaMailSender mail = mock(JavaMailSender.class);
        HttpServletRequest http = mock(HttpServletRequest.class);

        when(users.existsByEmail("foodie@example.test")).thenReturn(false);
        when(users.existsByUsername("foodie1")).thenReturn(false);
        when(passwords.encode("secret1")).thenReturn("encoded");
        when(users.save(any(User.class))).thenAnswer(invocation -> {
            User user = invocation.getArgument(0);
            user.setId("foodie-id");
            return user;
        });
        when(jwt.issueToken("foodie-id", "foodie@example.test", "foodie"))
                .thenReturn(new JwtUtil.IssuedToken("signed", Instant.now().plusSeconds(3600)));
        when(jwt.sessionTokenKey("signed")).thenReturn("v1:hash");
        when(http.getHeader("X-Platform")).thenReturn("web");

        AuthService service = new AuthService(users, sessions, resets, passwords, jwt, mail);
        var response = service.register(request, http);

        assertEquals("foodie", response.getUser().getRole());
        assertEquals("Bearer", response.getTokenType());
        verify(sessions).saveAndFlush(any(AuthSession.class));
        verify(users).save(argThat(user -> user.getRole() == User.Role.foodie
                && Boolean.FALSE.equals(user.getEmailVerified())));
    }

    @Test
    void moderatorCreationDoesNotReplaceAdministratorSession() throws Exception {
        RegisterRequest request = objectMapper.readValue("""
                {"email":"moderator@example.test","username":"moderator1","password":"secret1",
                 "fullName":"Moderator"}
                """, RegisterRequest.class);

        UserRepository users = mock(UserRepository.class);
        AuthSessionRepository sessions = mock(AuthSessionRepository.class);
        PasswordResetTokenRepository resets = mock(PasswordResetTokenRepository.class);
        PasswordEncoder passwords = mock(PasswordEncoder.class);
        JwtUtil jwt = mock(JwtUtil.class);
        JavaMailSender mail = mock(JavaMailSender.class);
        when(users.existsByEmail("moderator@example.test")).thenReturn(false);
        when(users.existsByUsername("moderator1")).thenReturn(false);
        when(passwords.encode("secret1")).thenReturn("encoded");
        when(users.save(any(User.class))).thenAnswer(invocation -> {
            User user = invocation.getArgument(0);
            user.setId("moderator-id");
            return user;
        });

        var result = new AuthService(users, sessions, resets, passwords, jwt, mail)
                .createModerator(request);

        assertEquals("moderador", result.getRole());
        verify(sessions, never()).saveAndFlush(any(AuthSession.class));
    }

    @Test
    void emailVerificationAcceptsOnlyTheSignedUnexpiredCode() {
        JavaMailSender mail = mock(JavaMailSender.class);
        var service = new EmailVerificationService(mail, "0123456789abcdef0123456789abcdef",
                "no-reply@example.test");
        var user = User.builder().id("user-1").email("user@example.test")
                .username("user1").password("hash").fullName("User")
                .role(User.Role.foodie).isActive(true).emailVerified(false).build();

        service.send(user);
        var message = org.mockito.ArgumentCaptor.forClass(SimpleMailMessage.class);
        verify(mail).send(message.capture());
        Matcher matcher = Pattern.compile("[0-9]{10}\\.[A-Za-z0-9_-]{22}")
                .matcher(message.getValue().getText());
        assertTrue(matcher.find());
        String code = matcher.group();

        assertDoesNotThrow(() -> service.requireProof(user, code));
        assertThrows(ResponseStatusException.class, () -> service.requireProof(user, "invalid"));
        assertThrows(ResponseStatusException.class, () -> service.requireProof(
                User.builder().id("other-user").email("user@example.test").build(), code));
        assertThrows(ResponseStatusException.class, () -> service.send(user));
    }
}