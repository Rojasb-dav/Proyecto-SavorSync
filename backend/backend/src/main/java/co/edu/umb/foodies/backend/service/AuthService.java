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
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.time.LocalDateTime;
import java.util.Random;

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

        User.Role role = User.Role.foodie;
        if (req.getRole() != null && !req.getRole().isBlank()) {
            try {
                role = User.Role.valueOf(req.getRole().trim().toLowerCase());
            } catch (IllegalArgumentException ex) {
                role = User.Role.foodie;
            }
        }

        String platformHeader = httpReq != null ? httpReq.getHeader("X-Platform") : null;
        if ("mobile".equalsIgnoreCase(platformHeader) && (role == User.Role.restaurant_admin || role == User.Role.moderador || role == User.Role.admin_sistema)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Acceso denegado: Los perfiles de Administrador y Moderador sólo pueden ingresar desde la plataforma Web en computador.");
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
        userRepository.findByEmail(email).ifPresent(user -> {
            String code = String.format("%06d", new Random().nextInt(999999));
            
            passwordResetTokenRepository.deleteByEmail(email);
            passwordResetTokenRepository.save(PasswordResetToken.builder()
                    .email(email)
                    .code(code)
                    .expiresAt(LocalDateTime.now().plusHours(24))
                    .build());

            SimpleMailMessage message = new SimpleMailMessage();
            message.setFrom("SavorSync <" + senderEmail + ">");
            message.setTo(email);
            message.setSubject("Código de Recuperación - SavorSync");
            message.setText("Hola " + user.getFullName() + ",\n\n" +
                    "Tu código de recuperación es: " + code + "\n\n" +
                    "Este código expirará en 15 minutos.\n\n" +
                    "Atentamente,\nEl equipo de SavorSync.");
            
            mailSender.send(message);
        });
    }

    @Transactional
    public void resetPassword(String email, String code, String newPassword) {
        String cleanEmail = email.trim().toLowerCase();
        String cleanCode = code.trim();

        PasswordResetToken token = passwordResetTokenRepository.findByEmailAndCode(cleanEmail, cleanCode)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.BAD_REQUEST, "Código incorrecto"));

        if (token.getExpiresAt().isBefore(LocalDateTime.now())) {
            passwordResetTokenRepository.delete(token);
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "El código ha expirado");
        }

        User user = userRepository.findByEmail(cleanEmail)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Usuario no encontrado"));

        user.setPassword(passwordEncoder.encode(newPassword));
        userRepository.save(user);
        
        passwordResetTokenRepository.deleteByEmail(cleanEmail);
    }

    private AuthResponse buildAuthResponse(User user, HttpServletRequest httpReq) {
        String token = jwtUtil.generateToken(user.getId(), user.getEmail(), user.getRole().name());

        try {
            String truncatedSessionToken = token;
            if (truncatedSessionToken.length() > 190) {
                truncatedSessionToken = truncatedSessionToken.substring(0, 190);
            }

            AuthSession session = AuthSession.builder()
                    .userId(user.getId())
                    .sessionToken(truncatedSessionToken)
                    .platform(AuthSession.Platform.mobile)
                    .ipAddress(httpReq != null ? httpReq.getRemoteAddr() : null)
                    .expiresAt(LocalDateTime.now().plusNanos(jwtUtil.getExpirationMs() * 1_000_000L))
                    .isActive(true)
                    .build();
            authSessionRepository.save(session);
        } catch (Exception e) {
            System.err.println("WARN: Registro de sesión opcional omitido: " + e.getMessage());
        }

        return AuthResponse.builder()
                .token(token)
                .tokenType("Bearer")
                .expiresInMs(jwtUtil.getExpirationMs())
                .user(UserResponse.from(user, user.getId()))
                .build();
    }
}
