package co.edu.umb.foodies.backend.security.jwt;

import co.edu.umb.foodies.backend.model.ClientSession;
import co.edu.umb.foodies.backend.model.EmployeeSession;
import co.edu.umb.foodies.backend.repository.ClientSessionRepository;
import co.edu.umb.foodies.backend.repository.EmployeeSessionRepository;
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
import java.util.List;

@Component
@RequiredArgsConstructor
public class JwtAuthenticationFilter extends OncePerRequestFilter {

    private final JwtUtil jwtUtil;
    private final ClientSessionRepository clientSessionRepository;
    private final EmployeeSessionRepository employeeSessionRepository;

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

                boolean isClientActive = clientSessionRepository.findBySessionTokenAndIsActiveTrue(cleanToken).isPresent();
                boolean isEmployeeActive = employeeSessionRepository.findBySessionTokenAndIsActiveTrue(cleanToken).isPresent();

                if (isClientActive || isEmployeeActive) {
                    String userId = claims.getSubject();
                    String email = claims.get("email", String.class);
                    String role = claims.get("role", String.class);

                    String principal = (userId != null && !userId.isBlank()) ? userId : email;
                    if (principal != null && !principal.isBlank()) {
                        var authorities = List.of(new SimpleGrantedAuthority("ROLE_" + (role == null ? "foodie" : role).toUpperCase()));
                        UsernamePasswordAuthenticationToken auth =
                                new UsernamePasswordAuthenticationToken(principal, null, authorities);
                        auth.setDetails(new WebAuthenticationDetailsSource().buildDetails(request));
                        SecurityContextHolder.getContext().setAuthentication(auth);
                    }
                } else {
                    SecurityContextHolder.clearContext();
                }
            } catch (Exception e) {
                SecurityContextHolder.clearContext();
            }
        }

        filterChain.doFilter(request, response);
    }
}
