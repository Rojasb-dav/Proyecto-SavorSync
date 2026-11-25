package co.edu.umb.foodies.backend.service;

import co.edu.umb.foodies.backend.dto.request.LoginRequest;
import co.edu.umb.foodies.backend.dto.request.RegisterRequest;
import co.edu.umb.foodies.backend.dto.response.AuthResponse;
import co.edu.umb.foodies.backend.dto.response.UserResponse;
import co.edu.umb.foodies.backend.model.ClientSession;
import co.edu.umb.foodies.backend.model.Employee;
import co.edu.umb.foodies.backend.model.EmployeeSession;
import co.edu.umb.foodies.backend.model.PasswordResetToken;
import co.edu.umb.foodies.backend.model.User;
import co.edu.umb.foodies.backend.repository.ClientSessionRepository;
import co.edu.umb.foodies.backend.repository.EmployeeRepository;
import co.edu.umb.foodies.backend.repository.EmployeeSessionRepository;
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
    private final EmployeeRepository employeeRepository;
    private final ClientSessionRepository clientSessionRepository;
    private final EmployeeSessionRepository employeeSessionRepository;
    private final PasswordResetTokenRepository passwordResetTokenRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtUtil jwtUtil;
    private final JavaMailSender mailSender;

    @org.springframework.beans.factory.annotation.Value("${spring.mail.username}")
    private String senderEmail;

    @Transactional
    public AuthResponse register(RegisterRequest req, HttpServletRequest httpReq) {
        if (userRepository.existsByEmail(req.getEmail().trim()) || employeeRepository.existsByEmail(req.getEmail().trim())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "El correo ya está registrado");
        }
        if (userRepository.existsByUsername(req.getUsername().trim()) || employeeRepository.existsByUsername(req.getUsername().trim())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "El nombre de usuario ya existe");
        }

        User.Role role = User.Role.foodie;
        if (User.Role.restaurant_admin.name().equalsIgnoreCase(req.getRole())) {
             role = User.Role.restaurant_admin;
        }

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
    public UserResponse currentUser(String userId) {
        User user = userRepository.findById(userId).orElse(null);
        if (user != null) {
            if (!Boolean.TRUE.equals(user.getIsActive())) throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Sesión inválida");
            return UserResponse.fromSelf(user);
        }
        Employee employee = employeeRepository.findById(userId).orElse(null);
        if (employee != null) {
            if (!Boolean.TRUE.equals(employee.getIsActive())) throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Sesión inválida");
            return UserResponse.fromSelf(employee);
        }
        throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Sesión inválida");
    }

    @Transactional
    public UserResponse createModerator(RegisterRequest req) {
        if (userRepository.existsByEmail(req.getEmail().trim()) || employeeRepository.existsByEmail(req.getEmail().trim())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "El correo ya está registrado");
        }
        if (userRepository.existsByUsername(req.getUsername().trim()) || employeeRepository.existsByUsername(req.getUsername().trim())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "El nombre de usuario ya existe");
        }

        Employee employee = Employee.builder()
                .id(UUID.randomUUID().toString())
                .email(req.getEmail().trim())
                .username(req.getUsername().trim())
                .password(passwordEncoder.encode(req.getPassword().trim()))
                .fullName(req.getFullName() != null ? req.getFullName().trim() : req.getUsername().trim())
                .role(Employee.Role.moderador)
                .isActive(true)
                .build();

        employee = employeeRepository.save(employee);
        return UserResponse.fromSelf(employee);
    }

    @Transactional
    public AuthResponse login(LoginRequest req, HttpServletRequest httpReq) {
        User user = userRepository.findByEmail(req.getEmail().trim()).orElse(null);
        if (user != null) {
            if (!Boolean.TRUE.equals(user.getIsActive())) {
                throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Cuenta inactiva");
            }
            if (!passwordEncoder.matches(req.getPassword().trim(), user.getPassword())) {
                throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Credenciales inválidas");
            }

            return buildAuthResponse(user, httpReq);
        }

        Employee employee = employeeRepository.findByEmail(req.getEmail().trim()).orElse(null);
        if (employee != null) {
            if (!Boolean.TRUE.equals(employee.getIsActive())) {
                throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Cuenta inactiva");
            }
            if (!passwordEncoder.matches(req.getPassword().trim(), employee.getPassword())) {
                throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Credenciales inválidas");
            }

            String platformHeader = httpReq != null ? httpReq.getHeader("X-Platform") : null;
            if ("mobile".equalsIgnoreCase(platformHeader)) {
                throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Acceso denegado: Los perfiles de Administrador y Moderador sólo tienen acceso permitido desde la plataforma Web en computador.");
            }

            return buildEmployeeAuthResponse(employee, httpReq);
        }

        throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Credenciales inválidas");
    }

    @Transactional
    public void logout(String token) {
        if (token == null || token.isBlank()) return;
        String clean = jwtUtil.sessionTokenKey(token);
        clientSessionRepository.findBySessionTokenAndIsActiveTrue(clean).ifPresent(s -> {
            s.setIsActive(false);
            clientSessionRepository.save(s);
        });
        employeeSessionRepository.findBySessionTokenAndIsActiveTrue(clean).ifPresent(s -> {
            s.setIsActive(false);
            employeeSessionRepository.save(s);
        });
    }

    @Transactional
    public void forgotPassword(String email) {
        userRepository.findByEmail(email.trim().toLowerCase()).ifPresent(user -> {
            String code = String.format("%06d", new SecureRandom().nextInt(900000) + 100000);
            String encodedCode = passwordEncoder.encode(code);
            
            try {
                passwordResetTokenRepository.deleteByEmail(user.getEmail());
                passwordResetTokenRepository.flush();

                PasswordResetToken resetToken = PasswordResetToken.builder()
                        .id(UUID.randomUUID().toString())
                        .email(user.getEmail())
                        .code(encodedCode)
                        .expiresAt(LocalDateTime.now().plusMinutes(15))
                        .build();

                passwordResetTokenRepository.saveAndFlush(resetToken);

                CompletableFuture.runAsync(() -> sendResetEmail(user.getEmail(), code));
            } catch (Exception e) {
                System.err.println("WARN: Error en forgotPassword: " + e.getMessage());
            }
        });

        employeeRepository.findByEmail(email.trim().toLowerCase()).ifPresent(employee -> {
            String code = String.format("%06d", new SecureRandom().nextInt(900000) + 100000);
            String encodedCode = passwordEncoder.encode(code);

            try {
                passwordResetTokenRepository.deleteByEmail(employee.getEmail());
                passwordResetTokenRepository.flush();

                PasswordResetToken resetToken = PasswordResetToken.builder()
                        .id(UUID.randomUUID().toString())
                        .email(employee.getEmail())
                        .code(encodedCode)
                        .expiresAt(LocalDateTime.now().plusMinutes(15))
                        .build();

                passwordResetTokenRepository.saveAndFlush(resetToken);

                CompletableFuture.runAsync(() -> sendResetEmail(employee.getEmail(), code));
            } catch (Exception e) {
                System.err.println("WARN: Error en forgotPassword: " + e.getMessage());
            }
        });
    }

    @Transactional
    public void resetPassword(String email, String token, String newPassword) {
        PasswordResetToken resetToken = passwordResetTokenRepository.findAll().stream()
                .filter(t -> t.getEmail().equalsIgnoreCase(email.trim()) && passwordEncoder.matches(token.trim(), t.getCode()))
                .findFirst()
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.BAD_REQUEST, "Código de verificación inválido o expirado"));

        if (resetToken.getExpiresAt().isBefore(LocalDateTime.now())) {
            passwordResetTokenRepository.delete(resetToken);
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "El código de verificación ha expirado");
        }

        User user = userRepository.findByEmail(email.trim().toLowerCase()).orElse(null);
        if (user != null) {
            user.setPassword(passwordEncoder.encode(newPassword.trim()));
            userRepository.save(user);

            clientSessionRepository.findAll().stream()
                .filter(s -> user.getId().equals(s.getUserId()) && s.getIsActive())
                .forEach(s -> {
                    s.setIsActive(false);
                    clientSessionRepository.save(s);
                });
        } else {
            Employee employee = employeeRepository.findByEmail(email.trim().toLowerCase())
                    .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Usuario no encontrado"));
            employee.setPassword(passwordEncoder.encode(newPassword.trim()));
            employeeRepository.save(employee);

            employeeSessionRepository.findAll().stream()
                .filter(s -> employee.getId().equals(s.getEmployeeId()) && s.getIsActive())
                .forEach(s -> {
                    s.setIsActive(false);
                    employeeSessionRepository.save(s);
                });
        }

        passwordResetTokenRepository.delete(resetToken);
    }

    private AuthResponse buildAuthResponse(User user, HttpServletRequest httpReq) {
        JwtUtil.IssuedToken tokenInfo = jwtUtil.issueToken(user.getId(), user.getEmail(), user.getRole().name());

        long ttl = java.time.Duration.between(java.time.Instant.now(), tokenInfo.expiresAt()).toMillis();
        if (ttl <= 0) {
            throw new IllegalStateException("Invalid token lifetime");
        }

        ClientSession session = ClientSession.builder()
                .id(UUID.randomUUID().toString())
                .userId(user.getId())
                .sessionToken(jwtUtil.sessionTokenKey(tokenInfo.token()))
                .ipAddress(httpReq != null ? httpReq.getRemoteAddr() : "127.0.0.1")
                .isActive(true)
                .platform(ClientSession.Platform.mobile)
                .expiresAt(tokenInfo.expiresAt())
                .build();

        clientSessionRepository.saveAndFlush(session);

        return AuthResponse.builder()
                .token(tokenInfo.token())
                .tokenType("Bearer")
                .expiresInMs(ttl)
                .user(UserResponse.fromSelf(user))
                .build();
    }

    private AuthResponse buildEmployeeAuthResponse(Employee employee, HttpServletRequest httpReq) {
        JwtUtil.IssuedToken tokenInfo = jwtUtil.issueToken(employee.getId(), employee.getEmail(), employee.getRole().name());

        long ttl = java.time.Duration.between(java.time.Instant.now(), tokenInfo.expiresAt()).toMillis();
        if (ttl <= 0) {
            throw new IllegalStateException("Invalid token lifetime");
        }

        EmployeeSession session = EmployeeSession.builder()
                .id(UUID.randomUUID().toString())
                .employeeId(employee.getId())
                .sessionToken(jwtUtil.sessionTokenKey(tokenInfo.token()))
                .ipAddress(httpReq != null ? httpReq.getRemoteAddr() : "127.0.0.1")
                .isActive(true)
                .platform(EmployeeSession.Platform.web_admin)
                .expiresAt(tokenInfo.expiresAt())
                .build();

        employeeSessionRepository.saveAndFlush(session);

        return AuthResponse.builder()
                .token(tokenInfo.token())
                .tokenType("Bearer")
                .expiresInMs(ttl)
                .user(UserResponse.fromSelf(employee))
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
