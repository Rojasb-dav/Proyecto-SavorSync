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
import org.springframework.http.HttpStatus;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.MimeMessageHelper;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.security.SecureRandom;
import java.time.LocalDateTime;
import java.util.UUID;
import java.util.concurrent.CompletableFuture;

@Service
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
        if (userRepository.existsByEmail(req.getEmail().trim())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "El correo ya está registrado");
        }
        if (userRepository.existsByUsername(req.getUsername().trim())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "El nombre de usuario ya existe");
        }

        // FALLO-03 Fix: El registro público asigna obligatoriamente el rol 'foodie'
        User.Role role = User.Role.foodie;

        User user = User.builder()
                .id(UUID.randomUUID().toString())
                .email(req.getEmail().trim())
                .username(req.getUsername().trim())
                .password(passwordEncoder.encode(req.getPassword().trim()))
                .fullName(req.getFullName() != null ? req.getFullName().trim() : req.getUsername().trim())
                .role(role)
                .isActive(true)
                .emailVerified(false)
                .build();

        user = userRepository.save(user);

        return buildAuthResponse(user, httpReq);
    }

    @Transactional
    public AuthResponse login(LoginRequest req, HttpServletRequest httpReq) {
        User user = userRepository.findByEmail(req.getEmail().trim())
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

    @Transactional
    public void logout(String token) {
        if (token == null || token.isBlank()) return;
        authSessionRepository.findBySessionTokenAndIsActiveTrue(token).ifPresent(s -> {
            s.setIsActive(false);
            authSessionRepository.save(s);
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
                System.err.println("WARN: Error en forgotPassword: " + e.getMessage());
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

        User user = userRepository.findByEmail(email.trim().toLowerCase())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Usuario no encontrado"));

        user.setPassword(passwordEncoder.encode(newPassword.trim()));
        userRepository.save(user);

        passwordResetTokenRepository.delete(resetToken);
    }

    private AuthResponse buildAuthResponse(User user, HttpServletRequest httpReq) {
        String token = jwtUtil.generateToken(user.getId(), user.getEmail(), user.getRole().name());

        try {
            AuthSession session = AuthSession.builder()
                    .id(UUID.randomUUID().toString())
                    .userId(user.getId())
                    .sessionToken(token)
                    .ipAddress(httpReq != null ? httpReq.getRemoteAddr() : "127.0.0.1")
                    .isActive(true)
                    .expiresAt(LocalDateTime.now().plusDays(1))
                    .build();

            authSessionRepository.save(session);
        } catch (Exception e) {
            System.err.println("WARN: No se pudo guardar la sesión de autenticación: " + e.getMessage());
        }

        return AuthResponse.builder()
                .token(token)
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
            System.err.println("ERROR enviando correo SMTP: " + e.getMessage());
        }
    }
}
