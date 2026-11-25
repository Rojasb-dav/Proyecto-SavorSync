package co.edu.umb.foodies.backend;

import co.edu.umb.foodies.backend.dto.response.AuthResponse;
import co.edu.umb.foodies.backend.dto.response.UserResponse;
import co.edu.umb.foodies.backend.service.UserService;
import co.edu.umb.foodies.backend.model.Pqrs;
import org.mockito.ArgumentCaptor;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;

import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.verify;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@ActiveProfiles("test")
@EnabledIfEnvironmentVariable(named = "SAVORSYNC_SESSION_MYSQL_URL",
        matches = "jdbc:mysql://127\\.0\\.0\\.1:[0-9]+/foodies_db(?:\\?.*)?")
class SessionMySqlTest {

    private static final String JWT_SECRET = UUID.randomUUID().toString() + UUID.randomUUID();

    @Autowired
    private TestRestTemplate http;

    @Autowired
    private JdbcTemplate jdbc;

    @Autowired
    private UserService userService;

    @MockBean
    private JavaMailSender mailSender;

    @DynamicPropertySource
    static void properties(DynamicPropertyRegistry properties) {
        properties.add("spring.datasource.url", () -> System.getenv("SAVORSYNC_SESSION_MYSQL_URL"));
        properties.add("spring.datasource.username", () -> System.getenv("SAVORSYNC_SESSION_MYSQL_USER"));
        properties.add("spring.datasource.password", () -> System.getenv("SAVORSYNC_SESSION_MYSQL_PASSWORD"));
        properties.add("app.jwt.secret", () -> JWT_SECRET);
        properties.add("cloudinary.cloud-name", () -> "local-test");
        properties.add("cloudinary.api-key", () -> "local-test");
        properties.add("cloudinary.api-secret", () -> "local-test");
        properties.add("spring.mail.username", () -> "local-test@example.test");
        properties.add("spring.mail.password", () -> "local-test");
    }

    @Test
    void persistsAndRevokesSessionsThroughTheHttpContract() {
        String username = "session_" + UUID.randomUUID().toString().replace("-", "");
        String email = username + "@example.test";
        String password = UUID.randomUUID().toString();

        assertThat(me(null).getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
        var registration = http.postForEntity("/api/v1/auth/register", Map.of(
                "email", email, "username", username, "password", password
        ), AuthResponse.class);
        assertThat(registration.getStatusCode()).isEqualTo(HttpStatus.OK);
        AuthResponse first = registration.getBody();
        assertThat(first).isNotNull();
        assertThat(first.getTokenType()).isEqualTo("Bearer");
        assertThat(first.getExpiresInMs()).isPositive();
        String userId = first.getUser().getId();

        String stored = jdbc.queryForObject("select session_token from sesiones_cliente where cliente_id = ?",
                String.class, userId);
        assertThat(first.getToken()).hasSizeGreaterThan(191);
        assertThat(stored).matches("v1:[0-9a-f]{64}");
        String postId = UUID.randomUUID().toString();
        jdbc.update("insert into publicaciones (id, cliente_id, contenido) values (?, ?, ?)",
                postId, userId, "Publicación de prueba de sesión");
        var restored = me(first.getToken());
        assertThat(restored.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(restored.getBody()).isNotNull();
        assertThat(restored.getBody().getId()).isEqualTo(userId);
        assertThat(restored.getBody().getPostsCount()).isEqualTo(1);

        String commentsPath = "/api/v1/posts/" + postId + "/comments";
        assertThat(http.getForEntity(commentsPath, String.class).getStatusCode()).isEqualTo(HttpStatus.OK);
        jdbc.update("update publicaciones set es_publica = false where id = ?", postId);
        assertThat(http.getForEntity(commentsPath, String.class).getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
        assertThat(http.exchange(commentsPath, HttpMethod.GET,
                new HttpEntity<>(headers(first.getToken())), String.class).getStatusCode()).isEqualTo(HttpStatus.OK);

        var login = http.postForEntity("/api/v1/auth/login", Map.of("email", email, "password", password),
                AuthResponse.class);
        assertThat(login.getStatusCode()).isEqualTo(HttpStatus.OK);
        AuthResponse second = login.getBody();
        assertThat(second).isNotNull();
        assertThat(second.getToken()).isNotEqualTo(first.getToken());

        var logout = http.exchange("/api/v1/auth/logout", HttpMethod.POST,
                new HttpEntity<>(headers(first.getToken())), String.class);
        assertThat(logout.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(me(first.getToken()).getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
        assertThat(me(second.getToken()).getStatusCode()).isEqualTo(HttpStatus.OK);

        userService.toggleUserStatus(userId);
        assertThat(me(second.getToken()).getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
        userService.toggleUserStatus(userId);
        assertThat(me(second.getToken()).getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
        assertThat(jdbc.queryForObject("select count(*) from sesiones_cliente where cliente_id = ? and activa",
                Integer.class, userId)).isZero();
    }

    @Test
    void verifiesEmailAndApprovesRestaurantWithoutChangingTheAdministratorSession() {
        String customer = "foodie_" + UUID.randomUUID().toString().replace("-", "");
        String password = UUID.randomUUID().toString();
        var signup = http.postForEntity("/api/v1/auth/register",
                account(customer, password, "admin_sistema"), AuthResponse.class);
        assertThat(signup.getStatusCode()).isEqualTo(HttpStatus.OK);
        var foodie = signup.getBody();
        assertThat(foodie).isNotNull();
        assertThat(foodie.getUser().getRole()).isEqualTo("foodie");
        assertThat(foodie.getUser().getEmailVerified()).isFalse();

        var profile = http.exchange("/api/v1/users/" + foodie.getUser().getId(), HttpMethod.PUT,
                new HttpEntity<>(Map.of("emailVerified", true), headers(foodie.getToken())), UserResponse.class);
        assertThat(profile.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(profile.getBody()).isNotNull();
        assertThat(profile.getBody().getEmailVerified()).isFalse();

        var sent = http.exchange("/api/v1/auth/email/verification", HttpMethod.POST,
                new HttpEntity<>(headers(foodie.getToken())), String.class);
        assertThat(sent.getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);
        var mail = ArgumentCaptor.forClass(SimpleMailMessage.class);
        verify(mailSender).send(mail.capture());
        assertThat(mail.getValue().getTo()).containsExactly(customer + "@example.test");
        String code = mail.getValue().getText().lines()
                .filter(line -> line.matches("[0-9]{10}\\.[A-Za-z0-9_-]{22}"))
                .findFirst().orElseThrow();

        var invalidCode = http.exchange("/api/v1/auth/email/verify", HttpMethod.POST,
                new HttpEntity<>(Map.of("code", "incorrecto"), headers(foodie.getToken())), String.class);
        assertThat(invalidCode.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        var verification = http.exchange("/api/v1/auth/email/verify", HttpMethod.POST,
                new HttpEntity<>(Map.of("code", code), headers(foodie.getToken())), UserResponse.class);
        assertThat(verification.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(verification.getBody()).isNotNull();
        assertThat(verification.getBody().getEmailVerified()).isTrue();

        var requestBody = new HttpEntity<>(Map.of("code", code, "description", "Solicitud de prueba"),
                headers(foodie.getToken()));
        var application = http.exchange("/api/v1/auth/restaurant-admin/request", HttpMethod.POST, requestBody, Pqrs.class);
        assertThat(application.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(application.getBody()).isNotNull();
        String ticketId = application.getBody().getId();
        var repeated = http.exchange("/api/v1/auth/restaurant-admin/request", HttpMethod.POST, requestBody, Pqrs.class);
        assertThat(repeated.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(repeated.getBody()).isNotNull();
        assertThat(repeated.getBody().getId()).isEqualTo(ticketId);
        String approvalPath = "/api/v1/auth/restaurant-admin/requests/" + ticketId + "/approve";
        assertThat(http.exchange(approvalPath, HttpMethod.POST, new HttpEntity<>(headers(foodie.getToken())), String.class)
                .getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);

        String administrator = "admin_" + UUID.randomUUID().toString().replace("-", "");
        var staff = http.postForEntity("/api/v1/auth/register",
                account(administrator, password, "foodie"), AuthResponse.class).getBody();
        assertThat(staff).isNotNull();
        jdbc.update("update clientes set rol = 'admin_sistema' where id = ?", staff.getUser().getId());
        var administratorAuth = http.postForEntity("/api/v1/auth/login",
                Map.of("email", administrator + "@example.test", "password", password), AuthResponse.class).getBody();
        assertThat(administratorAuth).isNotNull();
        String adminToken = administratorAuth.getToken();

        String moderator = "mod_" + UUID.randomUUID().toString().replace("-", "");
        var moderatorResult = http.exchange("/api/v1/auth/moderators", HttpMethod.POST,
                new HttpEntity<>(account(moderator, password, "admin_sistema"), headers(adminToken)), UserResponse.class);
        assertThat(moderatorResult.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(moderatorResult.getBody()).isNotNull();
        assertThat(moderatorResult.getBody().getRole()).isEqualTo("moderador");

        var approved = http.exchange(approvalPath, HttpMethod.POST,
                new HttpEntity<>(headers(adminToken)), UserResponse.class);
        assertThat(approved.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(approved.getBody()).isNotNull();
        assertThat(approved.getBody().getRole()).isEqualTo("restaurant_admin");
        assertThat(me(foodie.getToken()).getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
        assertThat(me(adminToken).getBody()).extracting(UserResponse::getRole).isEqualTo("admin_sistema");
    }

    private Map<String, String> account(String username, String password, String attemptedRole) {
        return Map.of("email", username + "@example.test", "username", username,
                "password", password, "role", attemptedRole);
    }

    private ResponseEntity<UserResponse> me(String token) {
        return http.exchange("/api/v1/auth/me", HttpMethod.GET, new HttpEntity<>(headers(token)), UserResponse.class);
    }

    private HttpHeaders headers(String token) {
        HttpHeaders headers = new HttpHeaders();
        if (token != null) {
            headers.setBearerAuth(token);
        }
        return headers;
    }
}
