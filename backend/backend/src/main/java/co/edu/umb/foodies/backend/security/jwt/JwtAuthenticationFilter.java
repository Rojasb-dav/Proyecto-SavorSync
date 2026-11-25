package co.edu.umb.foodies.backend.security.jwt;

import co.edu.umb.foodies.backend.model.ClientSession;
import co.edu.umb.foodies.backend.model.EmployeeSession;
import co.edu.umb.foodies.backend.model.Employee;
import co.edu.umb.foodies.backend.model.User;
import co.edu.umb.foodies.backend.repository.ClientSessionRepository;
import co.edu.umb.foodies.backend.repository.EmployeeRepository;
import co.edu.umb.foodies.backend.repository.EmployeeSessionRepository;
import co.edu.umb.foodies.backend.repository.UserRepository;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.jsonwebtoken.Claims;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.dao.DataAccessException;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.web.authentication.WebAuthenticationDetailsSource;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.time.Instant;
import java.util.Date;
import java.util.List;
import java.util.Map;

@Component
@RequiredArgsConstructor
public class JwtAuthenticationFilter extends OncePerRequestFilter {

    private final JwtUtil jwtUtil;
    private final ClientSessionRepository clientSessions;
    private final EmployeeSessionRepository employeeSessions;
    private final UserRepository users;
    private final EmployeeRepository employees;
    private final ObjectMapper objectMapper;

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        if ("OPTIONS".equalsIgnoreCase(request.getMethod())) return true;
        String path = request.getRequestURI();
        return "POST".equalsIgnoreCase(request.getMethod())
                && ("/api/v1/auth/register".equals(path)
                || "/api/v1/auth/login".equals(path)
                || "/api/v1/auth/email/verification".equals(path)
                || "/api/v1/auth/email/verify".equals(path)
                || "/api/v1/auth/forgot-password".equals(path)
                || "/api/v1/auth/reset-password".equals(path));
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response,
                                    FilterChain filterChain) throws ServletException, IOException {
        String token = JwtUtil.bearerToken(request.getHeader(HttpHeaders.AUTHORIZATION));
        if (token == null || token.isBlank()) {
            filterChain.doFilter(request, response);
            return;
        }

        final Claims claims;
        try {
            claims = jwtUtil.parse(token);
            if (claims.getExpiration() == null
                    || claims.getExpiration().before(Date.from(Instant.now()))) {
                unauthorized(response);
                return;
            }
        } catch (RuntimeException invalidToken) {
            unauthorized(response);
            return;
        }

        try {
            String accountType = claims.get("accountType", String.class);
            String roleClaim = claims.get("role", String.class);
            String sessionFingerprint = jwtUtil.sessionTokenKey(token);
            String principal;
            String currentRole;
            boolean verified;

            if ("client".equals(accountType)) {
                ClientSession session = clientSessions
                        .findBySessionTokenAndIsActiveTrue(sessionFingerprint).orElse(null);
                if (!validSession(session == null ? null : session.getExpiresAt(), session == null
                        ? null : session.getUserId(), claims.getSubject())) {
                    unauthorized(response);
                    return;
                }
                User user = users.findById(session.getUserId()).orElse(null);
                if (user == null || !Boolean.TRUE.equals(user.getIsActive()) || user.getRole() == null) {
                    unauthorized(response);
                    return;
                }
                currentRole = user.getRole().name();
                verified = Boolean.TRUE.equals(user.getEmailVerified());
                principal = user.getId();
            } else if ("employee".equals(accountType)) {
                EmployeeSession session = employeeSessions
                        .findBySessionTokenAndIsActiveTrue(sessionFingerprint).orElse(null);
                if (!validSession(session == null ? null : session.getExpiresAt(), session == null
                        ? null : session.getEmployeeId(), claims.getSubject())) {
                    unauthorized(response);
                    return;
                }
                Employee employee = employees.findById(session.getEmployeeId()).orElse(null);
                if (employee == null || !Boolean.TRUE.equals(employee.getIsActive())
                        || employee.getRole() == null) {
                    unauthorized(response);
                    return;
                }
                currentRole = employee.getRole().name();
                verified = Boolean.TRUE.equals(employee.getEmailVerified());
                principal = employee.getId();
            } else {
                unauthorized(response);
                return;
            }

            if (roleClaim == null || !roleClaim.equals(currentRole)) {
                unauthorized(response);
                return;
            }

            String authority = verified
                    ? "ROLE_" + currentRole.toUpperCase(java.util.Locale.ROOT)
                    : "ROLE_UNVERIFIED";
            var auth = new UsernamePasswordAuthenticationToken(
                    principal, null, List.of(new SimpleGrantedAuthority(authority)));
            auth.setDetails(new WebAuthenticationDetailsSource().buildDetails(request));
            SecurityContextHolder.getContext().setAuthentication(auth);
        } catch (DataAccessException unavailable) {
            serviceUnavailable(response);
            return;
        }

        filterChain.doFilter(request, response);
    }

    private static boolean validSession(Instant expiresAt, String owner, String subject) {
        return expiresAt != null && expiresAt.isAfter(Instant.now())
                && owner != null && owner.equals(subject);
    }

    private void unauthorized(HttpServletResponse response) throws IOException {
        writeError(response, HttpServletResponse.SC_UNAUTHORIZED, "AUTHENTICATION_REQUIRED",
                "Se requiere una sesión válida.");
        response.setHeader(HttpHeaders.WWW_AUTHENTICATE, "Bearer");
    }

    private void serviceUnavailable(HttpServletResponse response) throws IOException {
        writeError(response, HttpServletResponse.SC_SERVICE_UNAVAILABLE, "SESSION_SERVICE_UNAVAILABLE",
                "No se pudo verificar la sesión. Intenta nuevamente.");
    }

    private void writeError(HttpServletResponse response, int status, String code, String message)
            throws IOException {
        response.setStatus(status);
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        response.setCharacterEncoding(java.nio.charset.StandardCharsets.UTF_8.name());
        objectMapper.writeValue(response.getOutputStream(), Map.of(
                "status", status, "code", code, "message", message));
    }
}