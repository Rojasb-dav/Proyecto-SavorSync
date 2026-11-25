package co.edu.umb.foodies.backend.security.jwt;

import co.edu.umb.foodies.backend.model.ClientSession;
import co.edu.umb.foodies.backend.model.EmployeeSession;
import co.edu.umb.foodies.backend.model.User;
import co.edu.umb.foodies.backend.model.Employee;
import co.edu.umb.foodies.backend.repository.ClientSessionRepository;
import co.edu.umb.foodies.backend.repository.EmployeeSessionRepository;
import co.edu.umb.foodies.backend.repository.UserRepository;
import co.edu.umb.foodies.backend.repository.EmployeeRepository;
import io.jsonwebtoken.Claims;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.web.authentication.WebAuthenticationDetailsSource;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.time.Instant;
import java.util.List;
import java.util.Optional;

@Component
@RequiredArgsConstructor
public class JwtAuthenticationFilter extends OncePerRequestFilter {

    private final JwtUtil jwtUtil;
    private final ClientSessionRepository clientSessionRepository;
    private final EmployeeSessionRepository employeeSessionRepository;
    private final UserRepository userRepository;
    private final EmployeeRepository employeeRepository;

    public static final String[] PUBLIC_AUTH_ENDPOINTS = {
            "/api/auth/register",
            "/api/auth/login",
            "/api/auth/forgot-password",
            "/api/auth/reset-password",
            "/api/v1/auth/register",
            "/api/v1/auth/login",
            "/api/v1/auth/forgot-password",
            "/api/v1/auth/reset-password",
            "/api/v1/auth/verify-email",
            "/api/v1/auth/resend-verification"
    };

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                    HttpServletResponse response,
                                    FilterChain filterChain) throws ServletException, IOException {

        String path = request.getRequestURI();
        for (String endpoint : PUBLIC_AUTH_ENDPOINTS) {
            if (path.startsWith(endpoint.replace("/**", ""))) {
                filterChain.doFilter(request, response);
                return;
            }
        }

        String token = JwtUtil.bearerToken(request.getHeader("Authorization"));
        if (token != null && !token.isBlank()) {
            try {
                Claims claims = jwtUtil.parse(token);
                String cleanToken = jwtUtil.sessionTokenKey(token);

                if (claims.getExpiration().before(java.util.Date.from(Instant.now()))) {
                    sendErrorResponse(response, HttpServletResponse.SC_UNAUTHORIZED, "Token expirado");
                    return;
                }

                ClientSession clientSession = null;
                EmployeeSession employeeSession = null;

                try {
                    clientSession = clientSessionRepository.findBySessionTokenAndIsActiveTrue(cleanToken).orElse(null);
                    employeeSession = employeeSessionRepository.findBySessionTokenAndIsActiveTrue(cleanToken).orElse(null);
                } catch (org.springframework.dao.DataAccessException e) {
                    sendErrorResponse(response, HttpServletResponse.SC_SERVICE_UNAVAILABLE, "Error de base de datos");
                    return;
                }

                String role = null;
                String principal = null;

                if (clientSession != null) {
                    if (clientSession.getExpiresAt().isBefore(Instant.now())) {
                        sendErrorResponse(response, HttpServletResponse.SC_UNAUTHORIZED, "Sesión expirada");
                        return;
                    }
                    if (!clientSession.getUserId().equals(claims.getSubject())) {
                        sendErrorResponse(response, HttpServletResponse.SC_UNAUTHORIZED, "Sujeto inválido");
                        return;
                    }
                    User user = userRepository.findById(clientSession.getUserId()).orElse(null);
                    if (user == null || !Boolean.TRUE.equals(user.getIsActive())) {
                        sendErrorResponse(response, HttpServletResponse.SC_UNAUTHORIZED, "Cuenta inactiva");
                        return;
                    }
                    if (user.getRole() == null || !user.getRole().name().equals(claims.get("role", String.class))) {
                        sendErrorResponse(response, HttpServletResponse.SC_UNAUTHORIZED, "Rol modificado. Inicie sesión nuevamente.");
                        return;
                    }
                    role = user.getRole().name();
                    principal = user.getId();
                } else if (employeeSession != null) {
                    if (employeeSession.getExpiresAt().isBefore(Instant.now())) {
                        sendErrorResponse(response, HttpServletResponse.SC_UNAUTHORIZED, "Sesión expirada");
                        return;
                    }
                    if (!employeeSession.getEmployeeId().equals(claims.getSubject())) {
                        sendErrorResponse(response, HttpServletResponse.SC_UNAUTHORIZED, "Sujeto inválido");
                        return;
                    }
                    Employee employee = employeeRepository.findById(employeeSession.getEmployeeId()).orElse(null);
                    if (employee == null || !Boolean.TRUE.equals(employee.getIsActive())) {
                        sendErrorResponse(response, HttpServletResponse.SC_UNAUTHORIZED, "Cuenta inactiva");
                        return;
                    }
                    if (employee.getRole() == null || !employee.getRole().name().equals(claims.get("role", String.class))) {
                        sendErrorResponse(response, HttpServletResponse.SC_UNAUTHORIZED, "Rol modificado. Inicie sesión nuevamente.");
                        return;
                    }
                    role = employee.getRole().name();
                    principal = employee.getId();
                } else {
                    SecurityContextHolder.clearContext();
                    sendErrorResponse(response, HttpServletResponse.SC_UNAUTHORIZED, "Sesión inválida o expirada");
                    return;
                }

                if (principal != null && !principal.isBlank()) {
                    var authorities = List.of(new SimpleGrantedAuthority("ROLE_" + role.toUpperCase()));
                    UsernamePasswordAuthenticationToken auth =
                            new UsernamePasswordAuthenticationToken(principal, null, authorities);
                    auth.setDetails(new WebAuthenticationDetailsSource().buildDetails(request));
                    SecurityContextHolder.getContext().setAuthentication(auth);
                } else {
                    sendErrorResponse(response, HttpServletResponse.SC_UNAUTHORIZED, "Token inválido");
                    return;
                }
            } catch (Exception e) {
                SecurityContextHolder.clearContext();
                sendErrorResponse(response, HttpServletResponse.SC_UNAUTHORIZED, "Token inválido");
                return;
            }
        }

        filterChain.doFilter(request, response);
    }

    private void sendErrorResponse(HttpServletResponse response, int status, String message) throws IOException {
        response.setStatus(status);
        response.setContentType("application/json");
        response.setCharacterEncoding("UTF-8");
        if (status == HttpServletResponse.SC_UNAUTHORIZED) {
            response.setHeader("WWW-Authenticate", "Bearer");
        }
        response.getWriter().write(String.format("{\"status\":%d,\"message\":\"%s\"}", status, message));
        response.getWriter().flush();
    }
}
