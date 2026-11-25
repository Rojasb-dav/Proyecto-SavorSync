package co.edu.umb.foodies.backend.service;

import co.edu.umb.foodies.backend.dto.request.LoginRequest;
import co.edu.umb.foodies.backend.dto.request.RegisterRequest;
import co.edu.umb.foodies.backend.dto.response.AuthResponse;
import co.edu.umb.foodies.backend.dto.response.UserResponse;
import co.edu.umb.foodies.backend.model.AuthSession;
import co.edu.umb.foodies.backend.model.PasswordResetToken;
import co.edu.umb.foodies.backend.model.User;
import co.edu.umb.foodies.backend.repository.AuthSessionRepository;
import co.edu.umb.foodies.backend.repository.PasswordResetTokenRepository;
import co.edu.umb.foodies.backend.repository.UserRepository;
import co.edu.umb.foodies.backend.security.jwt.JwtUtil;
import jakarta.mail.internet.MimeMessage;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.MimeMessageHelper;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.security.SecureRandom;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDateTime;
import java.util.UUID;
import java.util.concurrent.CompletableFuture;

@Service
@Slf4j
@RequiredArgsConstructor
public class AuthService {

    private final UserRepository userRepository;
    private final AuthSessionRepository authSessionRepository;
    private final PasswordResetTokenRepository passwordResetTokenRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtUtil jwtUtil;
    private final JavaMailSender mailSender;

    @org.springframework.beans.factory.annotation.Value("${spring.mail.username}")
    private String senderEmail;

    @Transactional
    public AuthResponse register(RegisterRequest req, HttpServletRequest httpReq) {
        return buildAuthResponse(createAccount(req, User.Role.foodie), httpReq);
    }

    @Transactional
    public UserResponse createModerator(RegisterRequest req) {
        return UserResponse.from(createAccount(req, User.Role.moderador));
    }

    private User createAccount(RegisterRequest req, User.Role role) {
        if (userRepository.existsByEmail(req.getEmail().trim())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "El correo ya está registrado");
        }
        if (userRepository.existsByUsername(req.getUsername().trim())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "El nombre de usuario ya existe");
        }

        User user = User.builder()
                .email(req.getEmail().trim())
                .username(req.getUsername().trim())
                .password(passwordEncoder.encode(req.getPassword().trim()))
                .fullName(req.getFullName() != null ? req.getFullName().trim() : req.getUsername().trim())
                .role(role)
                .isActive(true)
                .emailVerified(false)
                .build();

        return userRepository.save(user);
    }

    @Transactional
    public AuthResponse login(LoginRequest req, HttpServletRequest httpReq) {
        User user = userRepository.findByEmailForUpdate(req.getEmail().trim())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Credenciales inválidas"));

        if (!Boolean.TRUE.equals(user.getIsActive())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Cuenta inactiva");
        }

        if (!passwordEncoder.matches(req.getPassword().trim(), user.getPassword())) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Credenciales inválidas");
        }

        String platformHeader = httpReq != null ? httpReq.getHeader("X-Platform") : null;
        if ("mobile".equalsIgnoreCase(platformHeader) && (user.getRole() == User.Role.restaurant_admin || user.getRole() == User.Role.moderador || user.getRole() == User.Role.admin_sistema)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Acceso denegado: Los perfiles de Administrador y Moderador sólo tienen acceso permitido desde la plataforma Web en computador.");
        }

        return buildAuthResponse(user, httpReq);
    }

    @Transactional(readOnly = true)
    public UserResponse currentUser(String userId) {
        return userRepository.findById(userId)
                .filter(user -> Boolean.TRUE.equals(user.getIsActive()))
                .map(UserResponse::from)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Sesión inválida"));
    }

    @Transactional
    public void logout(String token) {
        authSessionRepository.findBySessionTokenAndIsActiveTrue(jwtUtil.sessionTokenKey(token))
                .ifPresent(session -> {
                    session.setIsActive(false);
                    authSessionRepository.save(session);
                });
    }

    @Transactional
    public void forgotPassword(String email) {
        userRepository.findByEmail(email.trim().toLowerCase()).ifPresent(user -> {
            // FALLO-25 Fix: Generador criptográficamente seguro de 6 dígitos
            String code = String.format("%06d", new SecureRandom().nextInt(900000) + 100000);
            
            try {
                passwordResetTokenRepository.deleteByEmail(user.getEmail());
                passwordResetTokenRepository.flush();

                PasswordResetToken resetToken = PasswordResetToken.builder()
                        .id(UUID.randomUUID().toString())
                        .email(user.getEmail())
                        .code(code)
                        .expiresAt(LocalDateTime.now().plusMinutes(15))
                        .build();

                passwordResetTokenRepository.save(resetToken);

                CompletableFuture.runAsync(() -> sendResetEmail(user.getEmail(), code));
            } catch (Exception e) {
                log.warn("No se pudo registrar la solicitud de recuperación ({})", e.getClass().getSimpleName());
            }
        });
    }

    @Transactional
    public void resetPassword(String email, String token, String newPassword) {
        PasswordResetToken resetToken = passwordResetTokenRepository.findByEmailAndCode(email.trim().toLowerCase(), token.trim())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.BAD_REQUEST, "Código de verificación inválido o expirado"));

        if (resetToken.getExpiresAt().isBefore(LocalDateTime.now())) {
            passwordResetTokenRepository.delete(resetToken);
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "El código de verificación ha expirado");
        }

        User user = userRepository.findByEmailForUpdate(email.trim().toLowerCase())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Usuario no encontrado"));

        user.setPassword(passwordEncoder.encode(newPassword.trim()));
        userRepository.save(user);
        authSessionRepository.revokeAllByUserId(user.getId());

        passwordResetTokenRepository.delete(resetToken);
    }

    private AuthResponse buildAuthResponse(User user, HttpServletRequest httpReq) {
        JwtUtil.IssuedToken issued = jwtUtil.issueToken(user.getId(), user.getEmail(), user.getRole().name());
        String platformHeader = httpReq == null ? null : httpReq.getHeader("X-Platform");
        AuthSession.Platform platform = "web".equalsIgnoreCase(platformHeader)
                ? AuthSession.Platform.web_restaurante : AuthSession.Platform.mobile;
        AuthSession session = AuthSession.builder()
                .id(UUID.randomUUID().toString())
                .userId(user.getId())
                .sessionToken(jwtUtil.sessionTokenKey(issued.token()))
                .platform(platform)
                .ipAddress(httpReq == null ? null : httpReq.getRemoteAddr())
                .isActive(true)
                .expiresAt(issued.expiresAt())
                .build();
        authSessionRepository.saveAndFlush(session);

        long expiresInMs = Duration.between(Instant.now(), issued.expiresAt()).toMillis();
        if (expiresInMs <= 0) {
            throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE, "No se pudo iniciar una sesión válida");
        }
        return AuthResponse.builder()
                .token(issued.token())
                .tokenType("Bearer")
                .expiresInMs(expiresInMs)
                .user(UserResponse.from(user))
                .build();
    }

    private void sendResetEmail(String toEmail, String code) {
        try {
            MimeMessage message = mailSender.createMimeMessage();
            MimeMessageHelper helper = new MimeMessageHelper(message, true, "UTF-8");
            helper.setFrom(senderEmail);
            helper.setTo(toEmail);
            helper.setSubject("Código de Recuperación de Contraseña - SavorSync 🔐");

            String htmlBody = "<div style='font-family: Arial, sans-serif; padding: 20px; background-color: #f9f9f9;'>"
                    + "<h2 style='color: #FF5A5F;'>SavorSync 🍔</h2>"
                    + "<p>Hola,</p>"
                    + "<p>Hemos recibido una solicitud para restablecer tu contraseña en SavorSync.</p>"
                    + "<p>Tu código de verificación de 6 dígitos es:</p>"
                    + "<h1 style='color: #333; letter-spacing: 5px; background: #eee; padding: 10px; display: inline-block;'>" + code + "</h1>"
                    + "<p>Este código vencerá en 15 minutos. Si no solicitaste este cambio, puedes ignorar este mensaje.</p>"
                    + "<br><p>El equipo de SavorSync</p>"
                    + "</div>";

            helper.setText(htmlBody, true);
            mailSender.send(message);
        } catch (Exception e) {
            log.error("No se pudo enviar el correo de recuperación ({})", e.getClass().getSimpleName());
        }
    }
}
