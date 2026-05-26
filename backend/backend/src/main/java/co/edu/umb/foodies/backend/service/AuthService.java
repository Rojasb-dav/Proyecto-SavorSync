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

    @Transactional
    public AuthResponse register(RegisterRequest req, HttpServletRequest httpReq) {
        if (userRepository.existsByEmail(req.getEmail())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "El correo ya está registrado");
        }
        if (userRepository.existsByUsername(req.getUsername())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "El nombre de usuario ya existe");
        }

        User.Role role = User.Role.foodie;
        if (req.getRole() != null && !req.getRole().isBlank()) {
            try {
                role = User.Role.valueOf(req.getRole());
            } catch (IllegalArgumentException ex) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Rol inválido");
            }
        }

        User user = User.builder()
                .email(req.getEmail())
                .username(req.getUsername())
                .password(passwordEncoder.encode(req.getPassword()))
                .fullName(req.getFullName())
                .role(role)
                .isActive(true)
                .emailVerified(false)
                .build();

        user = userRepository.save(user);

        return buildAuthResponse(user, httpReq);
    }

    @Transactional
    public AuthResponse login(LoginRequest req, HttpServletRequest httpReq) {
        User user = userRepository.findByEmail(req.getEmail())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Credenciales inválidas"));

        if (!Boolean.TRUE.equals(user.getIsActive())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Cuenta inactiva");
        }

        if (!passwordEncoder.matches(req.getPassword(), user.getPassword())) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Credenciales inválidas");
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
                    .expiresAt(LocalDateTime.now().plusHours(24)) // Ampliado a 24 horas por problemas de timezone
                    .build());

            SimpleMailMessage message = new SimpleMailMessage();
            message.setFrom("SavorSync <" + "tu_correo@gmail.com" + ">");
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
        
        System.out.println("DEBUG: Iniciando reset para " + cleanEmail + " con código [" + cleanCode + "]");
        
        // Buscamos todos los tokens para este email para ver qué hay en la base de datos
        PasswordResetToken token = passwordResetTokenRepository.findByEmailAndCode(cleanEmail, cleanCode)
                .orElseThrow(() -> {
                    System.out.println("DEBUG: No se encontró el token en la BD para el email y código proporcionados");
                    return new ResponseStatusException(HttpStatus.BAD_REQUEST, "Código incorrecto");
                });

        System.out.println("DEBUG: Token encontrado. Expira en: " + token.getExpiresAt());

        if (token.getExpiresAt().isBefore(LocalDateTime.now())) {
            System.out.println("DEBUG: El token ha expirado. Hora actual: " + LocalDateTime.now());
            passwordResetTokenRepository.delete(token);
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "El código ha expirado");
        }

        User user = userRepository.findByEmail(cleanEmail)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Usuario no encontrado"));

        user.setPassword(passwordEncoder.encode(newPassword));
        userRepository.save(user);
        
        // Limpiamos los tokens usados
        passwordResetTokenRepository.deleteByEmail(cleanEmail);
        System.out.println("DEBUG: Contraseña actualizada con éxito para " + cleanEmail);
    }

    private AuthResponse buildAuthResponse(User user, HttpServletRequest httpReq) {
        String token = jwtUtil.generateToken(user.getId(), user.getEmail(), user.getRole().name());

        AuthSession session = AuthSession.builder()
                .userId(user.getId())
                .sessionToken(token)
                .platform(AuthSession.Platform.mobile)
                .ipAddress(httpReq != null ? httpReq.getRemoteAddr() : null)
                .expiresAt(LocalDateTime.now().plusNanos(jwtUtil.getExpirationMs() * 1_000_000L))
                .isActive(true)
                .build();
        authSessionRepository.save(session);

        return AuthResponse.builder()
                .token(token)
                .tokenType("Bearer")
                .expiresInMs(jwtUtil.getExpirationMs())
                .user(UserResponse.from(user, user.getId()))
                .build();
    }
}
