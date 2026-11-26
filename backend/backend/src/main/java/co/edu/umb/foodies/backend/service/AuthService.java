package co.edu.umb.foodies.backend.service;

import co.edu.umb.foodies.backend.dto.request.EmailVerificationRequest;
import co.edu.umb.foodies.backend.dto.request.LoginRequest;
import co.edu.umb.foodies.backend.dto.request.RegisterRequest;
import co.edu.umb.foodies.backend.dto.response.AuthResponse;
import co.edu.umb.foodies.backend.dto.response.RegistrationResponse;
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
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
import java.util.Locale;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class AuthService {

    private static final int BCRYPT_MAX_BYTES = 72;

    private final UserRepository userRepository;
    private final EmployeeRepository employeeRepository;
    private final ClientSessionRepository clientSessionRepository;
    private final EmployeeSessionRepository employeeSessionRepository;
    private final PasswordResetTokenRepository passwordResetTokenRepository;
    private final AccountIdentityRegistry identities;
    private final PasswordEncoder passwordEncoder;
    private final JwtUtil jwtUtil;
    private final EmailVerificationService challenges;

    @Transactional
    public RegistrationResponse register(RegisterRequest req, HttpServletRequest httpReq) {
        String email = normalizeEmail(req.getEmail());
        String username = normalizeUsername(req.getUsername());
        validatePassword(req.getPassword());
        String requestedRole = normalizeRequestedRole(req.getRole());

        if (userRepository.existsByEmail(email) || employeeRepository.existsByEmail(email)) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "El correo ya está registrado.");
        }
        if (userRepository.existsByUsername(username) || employeeRepository.existsByUsername(username)) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "El nombre de usuario ya existe.");
        }

        // A restaurant account remains a Foodie until the verified request is approved.
        String userId = UUID.randomUUID().toString();
        User user = User.builder()
                .id(userId)
                .email(email)
                .username(username)
                .password(passwordEncoder.encode(req.getPassword()))
                .fullName(req.getFullName().trim())
                .role(User.Role.foodie)
                .isActive(true)
                .emailVerified(false)
                .build();
        user = userRepository.saveAndFlush(user);
        identities.register("client", userId, email, username, requestedRole);

        EmailVerificationService.IssuedChallenge challenge = challenges.issue(
                user.getId(), email, PasswordResetToken.IdentityType.client,
                PasswordResetToken.Purpose.EMAIL_VERIFICATION, sourceAddress(httpReq));
        return new RegistrationResponse(true, challenge.challengeId(),
                challenge.expiresInMs(), requestedRole);
    }

    @Transactional
    public AuthResponse login(LoginRequest req, HttpServletRequest httpReq) {
        if (req.getPassword().getBytes(StandardCharsets.UTF_8).length > BCRYPT_MAX_BYTES) {
            throw invalidCredentials();
        }
        String email = normalizeEmail(req.getEmail());
        User user = userRepository.findByEmail(email).orElse(null);
        Employee employee = employeeRepository.findByEmail(email).orElse(null);

        if (user != null && employee != null) {
            throw invalidCredentials();
        }
        if (user != null) {
            if (!Boolean.TRUE.equals(user.getIsActive())) {
                throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Cuenta inactiva.");
            }
            if (!passwordEncoder.matches(req.getPassword(), user.getPassword())) {
                throw invalidCredentials();
            }
            if (!Boolean.TRUE.equals(user.getEmailVerified())) {
                throw new ResponseStatusException(HttpStatus.FORBIDDEN,
                        "EMAIL_VERIFICATION_REQUIRED: verifica tu correo antes de iniciar sesión.");
            }
            return createClientSession(user, httpReq);
        }

        if (employee != null) {
            if (!Boolean.TRUE.equals(employee.getIsActive())) {
                throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Cuenta inactiva.");
            }
            if (!passwordEncoder.matches(req.getPassword(), employee.getPassword())) {
                throw invalidCredentials();
            }
            if (!Boolean.TRUE.equals(employee.getEmailVerified())) {
                throw new ResponseStatusException(HttpStatus.FORBIDDEN,
                        "EMAIL_VERIFICATION_REQUIRED: verifica tu correo antes de iniciar sesión.");
            }
            return createEmployeeSession(employee, httpReq);
        }
        throw invalidCredentials();
    }

    @Transactional
    public AuthResponse verifyEmail(String challengeId, String code, HttpServletRequest httpReq) {
        var verified = challenges.verify(challengeId, code,
                PasswordResetToken.Purpose.EMAIL_VERIFICATION);
        if (verified.isEmpty()) return null;

        PasswordResetToken challenge = verified.get();
        if (challenge.getIdentityType() == PasswordResetToken.IdentityType.client) {
            User user = userRepository.findById(challenge.getIdentityId()).orElse(null);
            if (user == null || !Boolean.TRUE.equals(user.getIsActive())
                    || !normalizeEmail(user.getEmail()).equals(challenge.getEmail())) return null;
            user.setEmailVerified(true);
            userRepository.saveAndFlush(user);
            return createClientSession(user, httpReq);
        }

        Employee employee = employeeRepository.findById(challenge.getIdentityId()).orElse(null);
        if (employee == null || !Boolean.TRUE.equals(employee.getIsActive())
                || !normalizeEmail(employee.getEmail()).equals(challenge.getEmail())) return null;
        employee.setEmailVerified(true);
        employeeRepository.saveAndFlush(employee);
        return createEmployeeSession(employee, httpReq);
    }

    @Transactional
    public RegistrationResponse requestEmailVerification(
            EmailVerificationRequest request, HttpServletRequest httpReq) {
        String email = normalizeEmail(request.email());
        var previous = request.challengeId() == null ? null
                : passwordResetTokenRepository.findById(request.challengeId())
                        .filter(token -> token.getPurpose() == PasswordResetToken.Purpose.EMAIL_VERIFICATION)
                        .orElse(null);
        if (email.isBlank() && previous != null) email = previous.getEmail();

        RegistrationResponse generic = new RegistrationResponse(true, null, 0, null);
        if (email.isBlank()) return generic;

        String source = sourceAddress(httpReq);
        if (!challenges.checkRequestLimit(email, source)) {
            throw new ResponseStatusException(HttpStatus.TOO_MANY_REQUESTS,
                    "Demasiadas solicitudes. Espera antes de intentar nuevamente.");
        }

        User user = userRepository.findByEmail(email).orElse(null);
        Employee employee = employeeRepository.findByEmail(email).orElse(null);
        if (user != null && employee == null && !Boolean.TRUE.equals(user.getEmailVerified())
                && Boolean.TRUE.equals(user.getIsActive())
                && canResumeVerification(request, previous, email, user.getId(),
                        PasswordResetToken.IdentityType.client, user.getPassword())) {
            var issued = challenges.issue(user.getId(), email, PasswordResetToken.IdentityType.client,
                    PasswordResetToken.Purpose.EMAIL_VERIFICATION, source, true);
            String requestedRole = identities.requestedRole("client", user.getId());
            return new RegistrationResponse(true, issued.challengeId(), issued.expiresInMs(),
                    requestedRole == null ? "foodie" : requestedRole);
        }
        if (employee != null && user == null && !Boolean.TRUE.equals(employee.getEmailVerified())
                && Boolean.TRUE.equals(employee.getIsActive())
                && canResumeVerification(request, previous, email, employee.getId(),
                        PasswordResetToken.IdentityType.employee, employee.getPassword())) {
            var issued = challenges.issue(employee.getId(), email, PasswordResetToken.IdentityType.employee,
                    PasswordResetToken.Purpose.EMAIL_VERIFICATION, source, true);
            return new RegistrationResponse(true, issued.challengeId(), issued.expiresInMs(), "employee");
        }
        return generic;
    }

    private boolean canResumeVerification(EmailVerificationRequest request, PasswordResetToken previous,
                                          String email, String identityId,
                                          PasswordResetToken.IdentityType identityType, String passwordHash) {
        if (request.password() != null) {
            if (request.password().getBytes(StandardCharsets.UTF_8).length > BCRYPT_MAX_BYTES
                    || !passwordEncoder.matches(request.password(), passwordHash)) {
                return false;
            }
            identities.lockForChallenge(identityType.name(), identityId);
            return true;
        }
        if (previous == null || previous.getConsumedAt() != null
                || !email.equals(previous.getEmail()) || !identityId.equals(previous.getIdentityId())
                || identityType != previous.getIdentityType()) {
            return false;
        }
        identities.lockForChallenge(identityType.name(), identityId);
        return passwordResetTokenRepository.consumeForResend(previous.getId()) == 1;
    }

    @Transactional
    public UserResponse currentUser(String userId) {
        User user = userRepository.findById(userId).orElse(null);
        if (user != null) {
            if (!Boolean.TRUE.equals(user.getIsActive()) || !Boolean.TRUE.equals(user.getEmailVerified())) {
                throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Sesión inválida.");
            }
            return UserResponse.fromSelf(user);
        }
        Employee employee = employeeRepository.findById(userId).orElse(null);
        if (employee != null) {
            if (!Boolean.TRUE.equals(employee.getIsActive()) || !Boolean.TRUE.equals(employee.getEmailVerified())) {
                throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Sesión inválida.");
            }
            return UserResponse.fromSelf(employee);
        }
        throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Sesión inválida.");
    }

    @Transactional
    public UserResponse createModerator(RegisterRequest req, HttpServletRequest httpReq) {
        String email = normalizeEmail(req.getEmail());
        String username = normalizeUsername(req.getUsername());
        validatePassword(req.getPassword());
        if (userRepository.existsByEmail(email) || employeeRepository.existsByEmail(email)
                || userRepository.existsByUsername(username) || employeeRepository.existsByUsername(username)) {
            throw new ResponseStatusException(HttpStatus.CONFLICT,
                    "El correo o nombre de usuario ya está registrado.");
        }

        String employeeId = UUID.randomUUID().toString();
        Employee employee = Employee.builder()
                .id(employeeId)
                .email(email)
                .username(username)
                .password(passwordEncoder.encode(req.getPassword()))
                .fullName(req.getFullName().trim())
                .role(Employee.Role.moderador)
                .isActive(true)
                .emailVerified(false)
                .build();
        employee = employeeRepository.saveAndFlush(employee);
        identities.register("employee", employeeId, email, username);
        challenges.issue(employee.getId(), email, PasswordResetToken.IdentityType.employee,
                PasswordResetToken.Purpose.EMAIL_VERIFICATION, sourceAddress(httpReq));
        return UserResponse.fromSelf(employee);
    }

    @Transactional
    public void logout(String token) {
        if (token == null || token.isBlank()) return;
        String accountType = jwtUtil.parse(token).get("accountType", String.class);
        String fingerprint = jwtUtil.sessionTokenKey(token);
        if ("client".equals(accountType)) {
            clientSessionRepository.findBySessionTokenAndIsActiveTrue(fingerprint).ifPresent(session -> {
                session.setIsActive(false);
                clientSessionRepository.save(session);
            });
        } else if ("employee".equals(accountType)) {
            employeeSessionRepository.findBySessionTokenAndIsActiveTrue(fingerprint).ifPresent(session -> {
                session.setIsActive(false);
                employeeSessionRepository.save(session);
            });
        }
    }

    @Transactional
    public void forgotPassword(String emailInput, HttpServletRequest request) {
        String email = normalizeEmail(emailInput);
        if (!challenges.checkRequestLimit(email, sourceAddress(request))) {
            throw new ResponseStatusException(HttpStatus.TOO_MANY_REQUESTS,
                    "Demasiadas solicitudes. Espera antes de intentar nuevamente.");
        }
        User user = userRepository.findByEmail(email).orElse(null);
        Employee employee = employeeRepository.findByEmail(email).orElse(null);
        if (user != null && employee == null) {
            identities.lockForChallenge("client", user.getId());
            challenges.issue(user.getId(), email, PasswordResetToken.IdentityType.client,
                    PasswordResetToken.Purpose.PASSWORD_RESET, sourceAddress(request), true);
        } else if (employee != null && user == null) {
            identities.lockForChallenge("employee", employee.getId());
            challenges.issue(employee.getId(), email, PasswordResetToken.IdentityType.employee,
                    PasswordResetToken.Purpose.PASSWORD_RESET, sourceAddress(request), true);
        }
        // Generic response is returned even when the address does not identify an account.
    }

    @Transactional
    public boolean resetPassword(String emailInput, String code, String newPassword) {
        String email = normalizeEmail(emailInput);
        try {
            validatePassword(newPassword);
        } catch (ResponseStatusException invalidPassword) {
            return false;
        }

        User user = userRepository.findByEmail(email).orElse(null);
        Employee employee = employeeRepository.findByEmail(email).orElse(null);
        if ((user == null) == (employee == null)) return false;

        PasswordResetToken.IdentityType identityType = user != null
                ? PasswordResetToken.IdentityType.client
                : PasswordResetToken.IdentityType.employee;
        String identityId = user != null ? user.getId() : employee.getId();
        identities.lockForChallenge(identityType.name(), identityId);
        if (!challenges.consumePasswordResetChallenge(identityId, email, code, identityType)) return false;

        String encoded = passwordEncoder.encode(newPassword);
        if (user != null) {
            user.setPassword(encoded);
            userRepository.save(user);
            clientSessionRepository.revokeActiveByUserId(user.getId());
        } else {
            employee.setPassword(encoded);
            employeeRepository.save(employee);
            employeeSessionRepository.revokeActiveByEmployeeId(employee.getId());
        }
        return true;
    }

    private AuthResponse createClientSession(User user, HttpServletRequest request) {
        JwtUtil.IssuedToken tokenInfo = jwtUtil.issueToken(
                user.getId(), user.getEmail(), user.getRole().name(), "client");
        long ttl = Duration.between(Instant.now(), tokenInfo.expiresAt()).toMillis();
        if (ttl <= 0) throw new IllegalStateException("Invalid token lifetime.");

        ClientSession session = ClientSession.builder()
                .id(UUID.randomUUID().toString())
                .userId(user.getId())
                .sessionToken(jwtUtil.sessionTokenKey(tokenInfo.token()))
                .ipAddress(sourceAddress(request))
                .isActive(true)
                .platform(resolveClientPlatform(request))
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

    private AuthResponse createEmployeeSession(Employee employee, HttpServletRequest request) {
        JwtUtil.IssuedToken tokenInfo = jwtUtil.issueToken(
                employee.getId(), employee.getEmail(), employee.getRole().name(), "employee");
        long ttl = Duration.between(Instant.now(), tokenInfo.expiresAt()).toMillis();
        if (ttl <= 0) throw new IllegalStateException("Invalid token lifetime.");

        EmployeeSession.Platform platform = employee.getRole() == Employee.Role.moderador
                ? EmployeeSession.Platform.web_moderacion
                : EmployeeSession.Platform.web_admin;
        EmployeeSession session = EmployeeSession.builder()
                .id(UUID.randomUUID().toString())
                .employeeId(employee.getId())
                .sessionToken(jwtUtil.sessionTokenKey(tokenInfo.token()))
                .ipAddress(sourceAddress(request))
                .isActive(true)
                .platform(platform)
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

    private static ClientSession.Platform resolveClientPlatform(HttpServletRequest request) {
        String declared = request == null ? null : request.getHeader("X-Platform");
        if (declared == null || declared.isBlank() || "mobile".equalsIgnoreCase(declared)) {
            return ClientSession.Platform.mobile;
        }
        if ("web".equalsIgnoreCase(declared)) {
            return ClientSession.Platform.web_restaurante;
        }
        throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Plataforma declarada no admitida.");
    }

    private static String sourceAddress(HttpServletRequest request) {
        String address = request == null ? null : request.getRemoteAddr();
        return address == null || address.isBlank() ? "unknown" : address;
    }

    private static String normalizeEmail(String email) {
        return email == null ? "" : email.trim().toLowerCase(Locale.ROOT);
    }

    private static String normalizeUsername(String username) {
        return username == null ? "" : username.trim();
    }

    private static String normalizeRequestedRole(String requestedRole) {
        String role = requestedRole == null || requestedRole.isBlank()
                ? "foodie" : requestedRole.trim().toLowerCase(Locale.ROOT);
        if (!"foodie".equals(role) && !"restaurant_admin".equals(role)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Tipo de cuenta no permitido.");
        }
        return role;
    }

    private static void validatePassword(String password) {
        if (password == null || password.length() < 8 || password.length() > 100
                || password.getBytes(StandardCharsets.UTF_8).length > BCRYPT_MAX_BYTES) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "La contraseña debe tener al menos 8 caracteres y no exceder el límite seguro de BCrypt.");
        }
    }

    private static ResponseStatusException invalidCredentials() {
        return new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Credenciales inválidas.");
    }
}
