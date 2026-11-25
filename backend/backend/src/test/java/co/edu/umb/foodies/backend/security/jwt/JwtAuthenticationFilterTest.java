package co.edu.umb.foodies.backend.security.jwt;

import co.edu.umb.foodies.backend.model.ClientSession;
import co.edu.umb.foodies.backend.model.EmployeeSession;
import co.edu.umb.foodies.backend.model.User;
import co.edu.umb.foodies.backend.repository.ClientSessionRepository;
import co.edu.umb.foodies.backend.repository.EmployeeSessionRepository;
import co.edu.umb.foodies.backend.repository.UserRepository;
import co.edu.umb.foodies.backend.repository.EmployeeRepository;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.SignatureAlgorithm;
import io.jsonwebtoken.security.Keys;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.dao.DataAccessResourceFailureException;
import org.springframework.http.HttpHeaders;
import org.springframework.mock.web.MockFilterChain;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;

import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.Date;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

class JwtAuthenticationFilterTest {

    private static final String USER_ID = "alex";
    private static final String ROLE = "foodie";
    private static final String PUBLIC_PATH = "/api/v1/posts";
    private static final String PRIVATE_PATH = "/api/v1/auth/me";

    private final String jwtSecret = UUID.randomUUID().toString();
    private final JwtUtil jwtUtil = new JwtUtil(jwtSecret, 60_000);
    private final ClientSessionRepository clientSessions = mock(ClientSessionRepository.class);
    private final EmployeeSessionRepository employeeSessions = mock(EmployeeSessionRepository.class);
    private final UserRepository users = mock(UserRepository.class);
    private final EmployeeRepository employees = mock(EmployeeRepository.class);
    private final ObjectMapper objectMapper = new ObjectMapper();
    private final JwtAuthenticationFilter filter =
            new JwtAuthenticationFilter(jwtUtil, clientSessions, employeeSessions, users, employees);

    private final JwtUtil.IssuedToken issued = jwtUtil.issueToken(USER_ID, null, ROLE);

    @AfterEach
    void clearSecurityContext() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void currentActiveAccountWithMatchingSessionGetsItsStoredRole() throws Exception {
        storeSession(USER_ID, issued.expiresAt());
        when(users.findById(USER_ID)).thenReturn(Optional.of(account(true, User.Role.foodie)));
        var chain = new MockFilterChain();
        var response = doFilter("GET", PRIVATE_PATH, issued.token(), chain);

        var authentication = SecurityContextHolder.getContext().getAuthentication();
        assertThat(authentication.getName()).isEqualTo(USER_ID);
        assertThat(authentication.getAuthorities().stream().map(SimpleGrantedAuthority.class::cast))
                .containsExactly(new SimpleGrantedAuthority("ROLE_FOODIE"));
        assertThat(chain.getRequest()).isNotNull();
        assertThat(response.getStatus()).isEqualTo(200);
    }

    @Test
    void missingOrRevokedSessionIsRejectedEvenOnPublicEndpoint() throws Exception {
        assertRejected(PUBLIC_PATH, issued.token());
        verifyNoInteractions(users, employees);
    }

    @Test
    void expiredSessionIsRejectedWhileJwtIsStillCurrent() throws Exception {
        storeSession(USER_ID, Instant.now().minusSeconds(1));
        assertRejected(PRIVATE_PATH, issued.token());
        verifyNoInteractions(users, employees);
    }

    @Test
    void sessionMustBelongToJwtSubject() throws Exception {
        storeSession("another-account", issued.expiresAt());
        assertRejected(PRIVATE_PATH, issued.token());
        verifyNoInteractions(users, employees);
    }

    @Test
    void inactiveAccountCannotUseExistingSession() throws Exception {
        storeSession(USER_ID, issued.expiresAt());
        when(users.findById(USER_ID)).thenReturn(Optional.of(account(false, User.Role.foodie)));
        assertRejected(PRIVATE_PATH, issued.token());
    }

    @Test
    void changedRoleRequiresAuthenticationAgain() throws Exception {
        storeSession(USER_ID, issued.expiresAt());
        when(users.findById(USER_ID)).thenReturn(Optional.of(account(true, User.Role.restaurant_admin)));
        assertRejected(PRIVATE_PATH, issued.token());
    }

    @Test
    void tokenExpirationIsCheckedBeforeStorage() throws Exception {
        String expired = Jwts.builder()
                .setId(UUID.randomUUID().toString())
                .setSubject(USER_ID)
                .claim("role", ROLE)
                .setExpiration(Date.from(Instant.now().minusSeconds(30)))
                .signWith(Keys.hmacShaKeyFor(jwtSecret.getBytes(StandardCharsets.UTF_8)), SignatureAlgorithm.HS256)
                .compact();
        assertRejected(PRIVATE_PATH, expired);
        verifyNoInteractions(clientSessions, employeeSessions, users, employees);
    }

    @Test
    void publicRequestWithoutCredentialPassesThrough() throws Exception {
        var chain = new MockFilterChain();
        doFilter("GET", PUBLIC_PATH, null, chain);
        assertThat(chain.getRequest()).isNotNull();
        verifyNoInteractions(clientSessions, employeeSessions, users, employees);
    }

    @Test
    void loginWithPreviousCredentialPassesThrough() throws Exception {
        var chain = new MockFilterChain();
        doFilter("POST", "/api/v1/auth/login", issued.token(), chain);
        assertThat(chain.getRequest()).isNotNull();
        verifyNoInteractions(clientSessions, employeeSessions, users, employees);
    }

    @Test
    void unavailableSessionStoreIsNotInterpretedAsRevocation() throws Exception {
        when(clientSessions.findBySessionTokenAndIsActiveTrue(jwtUtil.sessionTokenKey(issued.token())))
                .thenThrow(new DataAccessResourceFailureException("detalle interno de prueba"));
        var chain = new MockFilterChain();
        var response = doFilter("GET", PRIVATE_PATH, issued.token(), chain);

        assertThat(response.getStatus()).isEqualTo(503);
        assertThat(response.getContentAsString()).doesNotContain("detalle interno");
        assertThat(response.getHeader(HttpHeaders.WWW_AUTHENTICATE)).isNull();
        assertThat(chain.getRequest()).isNull();
    }

    private void assertRejected(String path, String token) throws Exception {
        var chain = new MockFilterChain();
        var response = doFilter("GET", path, token, chain);
        assertThat(response.getStatus()).isEqualTo(401);
        assertThat(response.getHeader(HttpHeaders.WWW_AUTHENTICATE)).isEqualTo("Bearer");
        assertThat(objectMapper.readTree(response.getContentAsString()).path("status").asInt()).isEqualTo(401);
        assertThat(SecurityContextHolder.getContext().getAuthentication()).isNull();
        assertThat(chain.getRequest()).isNull();
    }

    private MockHttpServletResponse doFilter(String method, String path, String token, MockFilterChain chain)
            throws Exception {
        var request = new MockHttpServletRequest(method, path);
        request.setServletPath(path);
        if (token != null) {
            request.addHeader(HttpHeaders.AUTHORIZATION, "Bearer " + token);
        }
        var response = new MockHttpServletResponse();
        filter.doFilter(request, response, chain);
        return response;
    }

    private void storeSession(String userId, Instant expiresAt) {
        String key = jwtUtil.sessionTokenKey(issued.token());
        when(clientSessions.findBySessionTokenAndIsActiveTrue(key))
                .thenReturn(Optional.of(ClientSession.builder().userId(userId).sessionToken(key).expiresAt(expiresAt).isActive(true).build()));
    }

    private User account(boolean active, User.Role role) {
        return User.builder().id(USER_ID).isActive(active).role(role).build();
    }
}
