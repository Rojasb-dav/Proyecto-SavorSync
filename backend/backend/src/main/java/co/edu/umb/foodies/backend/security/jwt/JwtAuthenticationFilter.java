package co.edu.umb.foodies.backend.security.jwt;

import co.edu.umb.foodies.backend.model.AuthSession;
import co.edu.umb.foodies.backend.model.User;
import co.edu.umb.foodies.backend.repository.AuthSessionRepository;
import co.edu.umb.foodies.backend.repository.UserRepository;
import co.edu.umb.foodies.backend.security.RestSecurityErrors;
import io.jsonwebtoken.JwtException;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.dao.DataAccessException;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.web.authentication.WebAuthenticationDetailsSource;
import org.springframework.security.web.util.matcher.OrRequestMatcher;
import org.springframework.security.web.util.matcher.RequestMatcher;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.time.Instant;
import java.util.List;
import java.util.Locale;

import static org.springframework.security.web.util.matcher.AntPathRequestMatcher.antMatcher;

@Component
@RequiredArgsConstructor
@Slf4j
public class JwtAuthenticationFilter extends OncePerRequestFilter {

    public static final RequestMatcher PUBLIC_AUTH_ENDPOINTS = new OrRequestMatcher(
            antMatcher(HttpMethod.POST, "/api/v1/auth/login"),
            antMatcher(HttpMethod.POST, "/api/v1/auth/register"),
            antMatcher(HttpMethod.POST, "/api/v1/auth/forgot-password"),
            antMatcher(HttpMethod.POST, "/api/v1/auth/reset-password")
    );

    private final JwtUtil jwtUtil;
    private final AuthSessionRepository authSessionRepository;
    private final UserRepository userRepository;
    private final RestSecurityErrors securityErrors;

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        return PUBLIC_AUTH_ENDPOINTS.matches(request);
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                    HttpServletResponse response,
                                    FilterChain filterChain) throws ServletException, IOException {
        String token = JwtUtil.bearerToken(request.getHeader(HttpHeaders.AUTHORIZATION));
        if (token == null) {
            filterChain.doFilter(request, response);
            return;
        }

        User user;
        try {
            user = findAuthenticatedUser(token);
        } catch (DataAccessException e) {
            log.warn("No se pudo verificar la sesión ({})", e.getClass().getSimpleName());
            SecurityContextHolder.clearContext();
            securityErrors.serviceUnavailable(response);
            return;
        }
        if (user == null) {
            SecurityContextHolder.clearContext();
            securityErrors.unauthorized(response);
            return;
        }

        String authority = "ROLE_" + user.getRole().name().toUpperCase(Locale.ROOT);
        var auth = UsernamePasswordAuthenticationToken.authenticated(
                user.getId(), null, List.of(new SimpleGrantedAuthority(authority))
        );
        auth.setDetails(new WebAuthenticationDetailsSource().buildDetails(request));
        var context = SecurityContextHolder.createEmptyContext();
        context.setAuthentication(auth);
        SecurityContextHolder.setContext(context);
        filterChain.doFilter(request, response);
    }

    private User findAuthenticatedUser(String token) {
        String userId;
        String tokenRole;
        try {
            var claims = jwtUtil.parse(token);
            userId = claims.getSubject();
            tokenRole = claims.get("role", String.class);
            if (userId == null || userId.isBlank() || claims.getExpiration() == null
                    || claims.getId() == null || tokenRole == null) {
                return null;
            }
        } catch (JwtException | IllegalArgumentException e) {
            return null;
        }

        AuthSession session = authSessionRepository
                .findBySessionTokenAndIsActiveTrue(jwtUtil.sessionTokenKey(token))
                .orElse(null);
        if (session == null || !userId.equals(session.getUserId())
                || session.getExpiresAt() == null || !session.getExpiresAt().isAfter(Instant.now())) {
            return null;
        }

        return userRepository.findById(userId)
                .filter(user -> Boolean.TRUE.equals(user.getIsActive()))
                .filter(user -> user.getRole() != null && user.getRole().name().equals(tokenRole))
                .orElse(null);
    }
}
