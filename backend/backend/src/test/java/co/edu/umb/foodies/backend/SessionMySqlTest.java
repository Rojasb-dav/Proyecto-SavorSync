package co.edu.umb.foodies.backend;

import co.edu.umb.foodies.backend.dto.PostDTO;
import co.edu.umb.foodies.backend.dto.response.AuthResponse;
import co.edu.umb.foodies.backend.dto.response.RegistrationResponse;
import co.edu.umb.foodies.backend.dto.response.UserResponse;
import co.edu.umb.foodies.backend.model.Employee;
import co.edu.umb.foodies.backend.model.PasswordResetToken;
import co.edu.umb.foodies.backend.model.User;
import co.edu.umb.foodies.backend.repository.ClientSessionRepository;
import co.edu.umb.foodies.backend.repository.EmployeeRepository;
import co.edu.umb.foodies.backend.repository.EmployeeSessionRepository;
import co.edu.umb.foodies.backend.repository.PostRepository;
import co.edu.umb.foodies.backend.repository.UserRepository;
import co.edu.umb.foodies.backend.service.AccountIdentityRegistry;
import co.edu.umb.foodies.backend.service.CloudinaryAssetRegistry;
import co.edu.umb.foodies.backend.service.CloudinaryService;
import co.edu.umb.foodies.backend.service.PostService;
import co.edu.umb.foodies.backend.service.UserService;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.mockito.ArgumentCaptor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.boot.test.mock.mockito.SpyBean;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;

import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@ActiveProfiles("test")
@EnabledIfEnvironmentVariable(named = "SAVORSYNC_SESSION_MYSQL_URL",
        matches = "jdbc:mysql://127\\.0\\.0\\.1:[0-9]+/foodies_db(?:_v32_[a-z0-9_]+)?(?:\\?.*)?")
class SessionMySqlTest {

    private static final String JWT_SECRET = UUID.randomUUID().toString() + UUID.randomUUID();

    @Autowired private TestRestTemplate http;
    @Autowired private JdbcTemplate jdbc;
    @Autowired private UserService userService;
    @Autowired private PostService postService;
    @Autowired private CloudinaryAssetRegistry assetRegistry;
    @Autowired private AccountIdentityRegistry identities;
    @Autowired private UserRepository users;
    @Autowired private EmployeeRepository employees;
    @Autowired private ClientSessionRepository clientSessions;
    @Autowired private EmployeeSessionRepository employeeSessions;
    @Autowired private PasswordEncoder passwordEncoder;

    @SpyBean private PostRepository postRepository;
    @MockBean private JavaMailSender mailSender;

    @DynamicPropertySource
    static void properties(DynamicPropertyRegistry properties) {
        properties.add("spring.datasource.url", () -> System.getenv("SAVORSYNC_SESSION_MYSQL_URL"));
        properties.add("spring.datasource.username", () -> System.getenv("SAVORSYNC_SESSION_MYSQL_USER"));
        properties.add("spring.datasource.password", () -> System.getenv("SAVORSYNC_SESSION_MYSQL_PASSWORD"));
        properties.add("app.jwt.secret", () -> JWT_SECRET);
        properties.add("app.flyway.enabled", () -> "true");
        properties.add("spring.jpa.hibernate.ddl-auto", () -> "validate");
        properties.add("app.security.codes.max-per-hour", () -> "100000");
        properties.add("app.security.codes.source-max-per-hour", () -> "100000");
        properties.add("app.security.codes.resend-seconds", () -> "0");
        properties.add("cloudinary.cloud-name", () -> "local-test");
        properties.add("cloudinary.api-key", () -> "local-test");
        properties.add("cloudinary.api-secret", () -> "local-test");
        properties.add("spring.mail.username", () -> "local-test@example.test");
        properties.add("spring.mail.password", () -> "local-test");
    }

    @Test
    void registersWithoutJwtThenVerifiesLogsOutAndRevokesSessions() {
        String username = unique("foodie");
        String email = username + "@example.test";
        String password = "V32-safe-test-password";
        assertThat(currentUser(null).getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);

        ResponseEntity<RegistrationResponse> registration = register(email, username, password, "foodie");
        assertThat(registration.getStatusCode()).isEqualTo(HttpStatus.ACCEPTED);
        RegistrationResponse pending = registration.getBody();
        assertThat(pending).isNotNull();
        assertThat(pending.verificationRequired()).isTrue();
        assertThat(pending.challengeId()).isNotBlank();
        assertThat(pending.requestedRole()).isEqualTo("foodie");
        assertThat(jdbc.queryForObject(
                "select count(*) from sesiones_cliente s join clientes c on c.id = s.cliente_id where c.email = ?",
                Integer.class, email)).isZero();

        SimpleMailMessage sent = lastMail();
        assertThat(sent.getTo()).containsExactly(email);
        VerificationCode emailed = extractCode(sent);
        assertThat(emailed.challengeId()).isEqualTo(pending.challengeId());

        AuthResponse first = verify(pending.challengeId(), emailed.code());
        assertSessionPersisted(first);
        String userId = first.getUser().getId();

        String postId = UUID.randomUUID().toString();
        jdbc.update("insert into publicaciones (id, cliente_id, contenido, es_publica, estado) values (?, ?, ?, true, 'publicada')",
                postId, userId, "Reseña de prueba MySQL");
        assertThat(currentUser(first.getToken()).getStatusCode()).isEqualTo(HttpStatus.OK);

        String commentsPath = "/api/v1/posts/" + postId + "/comments";
        assertThat(http.getForEntity(commentsPath, String.class).getStatusCode()).isEqualTo(HttpStatus.OK);
        jdbc.update("update publicaciones set es_publica = false where id = ?", postId);
        assertThat(http.getForEntity(commentsPath, String.class).getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
        assertThat(http.exchange(commentsPath, HttpMethod.GET,
                new HttpEntity<>(headers(first.getToken())), String.class).getStatusCode()).isEqualTo(HttpStatus.OK);

        ResponseEntity<AuthResponse> login = http.postForEntity("/api/v1/auth/login",
                Map.of("email", email, "password", password), AuthResponse.class);
        assertThat(login.getStatusCode()).isEqualTo(HttpStatus.OK);
        AuthResponse second = login.getBody();
        assertThat(second).isNotNull();
        assertThat(second.getToken()).isNotEqualTo(first.getToken());

        ResponseEntity<String> logout = http.exchange("/api/v1/auth/logout", HttpMethod.POST,
                new HttpEntity<>(headers(first.getToken())), String.class);
        assertThat(logout.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(currentUser(first.getToken()).getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
        assertThat(currentUser(second.getToken()).getStatusCode()).isEqualTo(HttpStatus.OK);

        userService.toggleUserStatus(userId);
        assertThat(currentUser(second.getToken()).getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
        userService.toggleUserStatus(userId);
        assertThat(currentUser(second.getToken()).getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
        assertThat(jdbc.queryForObject(
                "select count(*) from sesiones_cliente where cliente_id = ? and activa = true",
                Integer.class, userId)).isZero();
    }

    @Test
    void preservesRequestedRestaurantRoleAcrossResendAndRevokesSessionOnApproval() {
        String username = unique("restapp");
        String email = username + "@example.test";
        String password = "V32-safe-test-password";
        ResponseEntity<RegistrationResponse> registrationResponse =
                register(email, username, password, "restaurant_admin");
        assertThat(registrationResponse.getStatusCode())
                .as("registration HTTP response: %s", registrationResponse.getBody())
                .isEqualTo(HttpStatus.ACCEPTED);
        RegistrationResponse registration = registrationResponse.getBody();
        assertThat(registration).isNotNull();
        assertThat(registration.verificationRequired())
                .as("registration response: %s", registration)
                .isTrue();
        assertThat(registration.requestedRole()).isEqualTo("restaurant_admin");

        ResponseEntity<RegistrationResponse> resendResponse = http.postForEntity(
                "/api/v1/auth/email/verification",
                Map.of("email", email, "challengeId", registration.challengeId()),
                RegistrationResponse.class);
        assertThat(resendResponse.getStatusCode()).isEqualTo(HttpStatus.ACCEPTED);
        RegistrationResponse resent = resendResponse.getBody();
        assertThat(resent).isNotNull();
        assertThat(resent.requestedRole()).isEqualTo("restaurant_admin");
        AuthResponse applicantSession = verify(resent.challengeId(), extractCode(lastMail()).code());
        assertThat(applicantSession.getUser().getRole()).isEqualTo("foodie");
        assertThat(identities.requestedRole("client", applicantSession.getUser().getId()))
                .isEqualTo("restaurant_admin");

        ResponseEntity<co.edu.umb.foodies.backend.model.Pqrs> request = http.exchange(
                "/api/v1/auth/restaurant-admin/request", HttpMethod.POST,
                new HttpEntity<>(Map.of("description", "Solicitud sintética de prueba"),
                        headers(applicantSession.getToken())),
                co.edu.umb.foodies.backend.model.Pqrs.class);
        assertThat(request.getStatusCode()).isEqualTo(HttpStatus.ACCEPTED);
        assertThat(request.getBody()).isNotNull();

        Employee systemAdmin = createEmployee("admin_sistema", false);
        ResponseEntity<AuthResponse> beforeVerify = http.postForEntity("/api/v1/auth/login",
                Map.of("email", systemAdmin.getEmail(), "password", "V32-safe-test-password"),
                AuthResponse.class);
        assertThat(beforeVerify.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);

        RegistrationResponse adminChallenge = http.postForEntity("/api/v1/auth/email/verification",
                Map.of("email", systemAdmin.getEmail(), "password", password), RegistrationResponse.class).getBody();
        assertThat(adminChallenge).isNotNull();
        assertThat(adminChallenge.requestedRole()).isEqualTo("employee");
        AuthResponse adminSession = verify(adminChallenge.challengeId(), extractCode(lastMail()).code());
        assertThat(adminSession.getUser().getRole()).isEqualTo("admin_sistema");

        String moderatorUsername = unique("moderator");
        ResponseEntity<UserResponse> moderator = http.exchange("/api/v1/auth/moderators", HttpMethod.POST,
                new HttpEntity<>(Map.of(
                        "email", moderatorUsername + "@example.test",
                        "username", moderatorUsername,
                        "password", "V32-safe-test-password",
                        "fullName", "Moderador de pruebas"),
                        headers(adminSession.getToken())),
                UserResponse.class);
        assertThat(moderator.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(moderator.getBody()).isNotNull();
        assertThat(moderator.getBody().getRole()).isEqualTo("moderador");
        assertThat(currentUser(adminSession.getToken()).getStatusCode()).isEqualTo(HttpStatus.OK);

        ResponseEntity<UserResponse> approval = http.exchange(
                "/api/v1/auth/restaurant-admin/requests/" + request.getBody().getId() + "/approve",
                HttpMethod.POST, new HttpEntity<>(headers(adminSession.getToken())), UserResponse.class);
        assertThat(approval.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(approval.getBody()).isNotNull();
        assertThat(approval.getBody().getRole()).isEqualTo("restaurant_admin");
        assertThat(currentUser(applicantSession.getToken()).getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
        assertThat(currentUser(adminSession.getToken()).getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(jdbc.queryForObject(
                "select count(*) from sesiones_cliente where cliente_id = ? and activa = true",
                Integer.class, applicantSession.getUser().getId())).isZero();

        assertEmployeeCanCompleteVerification("moderador");
    }

    @Test
    void emailOnlyResendDoesNotDiscloseTheAccountOrInvalidateItsChallenge() {
        String username = unique("private");
        String email = username + "@example.test";
        RegistrationResponse registration = register(email, username, "V32-safe-test-password",
                "restaurant_admin").getBody();
        assertThat(registration).isNotNull();
        VerificationCode original = extractCode(lastMail());

        for (Map<String, String> unproven : List.of(
                Map.of("email", email),
                Map.of("email", username + ".unknown@example.test"),
                Map.of("email", email, "password", "wrong-test-password"),
                Map.of("email", email, "challengeId", UUID.randomUUID().toString()))) {
            var response = http.postForEntity("/api/v1/auth/email/verification",
                    unproven, RegistrationResponse.class);
            assertThat(response.getStatusCode()).isEqualTo(HttpStatus.ACCEPTED);
            assertThat(response.getBody()).isEqualTo(new RegistrationResponse(true, null, 0, null));
        }
        org.mockito.Mockito.verify(mailSender, times(1)).send(any(SimpleMailMessage.class));
        verify(registration.challengeId(), original.code());
    }

    @Test
    void recordsFailedAttemptAndConsumesAValidCodeOnceAcrossConcurrentRequests() throws Exception {
        String username = unique("once");
        String email = username + "@example.test";
        RegistrationResponse pending = register(email, username, "V32-safe-test-password", "foodie").getBody();
        assertThat(pending).isNotNull();
        String correct = extractCode(lastMail()).code();
        String wrong = "123456".equals(correct) ? "654321" : "123456";
        String path = "/api/v1/auth/email/verify";
        var invalid = http.postForEntity(path,
                Map.of("challengeId", pending.challengeId(), "code", wrong), String.class);
        assertThat(invalid.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(jdbc.queryForObject("select failed_attempts from tokens_recuperacion where id = ?",
                Integer.class, pending.challengeId())).isEqualTo(1);

        var workers = java.util.concurrent.Executors.newFixedThreadPool(2);
        var ready = new java.util.concurrent.CyclicBarrier(2);
        java.util.concurrent.Callable<Integer> verifyConcurrently = () -> {
            ready.await(10, java.util.concurrent.TimeUnit.SECONDS);
            return http.postForEntity(path, Map.of("challengeId", pending.challengeId(), "code", correct),
                    String.class).getStatusCode().value();
        };
        try {
            var first = workers.submit(verifyConcurrently);
            var second = workers.submit(verifyConcurrently);
            assertThat(List.of(first.get(20, java.util.concurrent.TimeUnit.SECONDS),
                    second.get(20, java.util.concurrent.TimeUnit.SECONDS)))
                    .containsExactlyInAnyOrder(200, 400);
        } finally {
            workers.shutdownNow();
        }
        assertThat(jdbc.queryForObject(
                "select count(*) from sesiones_cliente s join clientes c on c.id = s.cliente_id where c.email = ?",
                Integer.class, email)).isEqualTo(1);
    }

    @Test
    void recoveryCodeResetsThePasswordOnlyOnceAndRevokesTheSession() throws Exception {
        RegisteredUser user = registerAndVerify("recovery", "foodie");
        var request = http.postForEntity("/api/v1/auth/forgot-password",
                Map.of("email", user.email()), String.class);
        assertThat(request.getStatusCode()).isEqualTo(HttpStatus.ACCEPTED);
        String code = extractCode(lastMail()).code();

        var workers = java.util.concurrent.Executors.newFixedThreadPool(2);
        var ready = new java.util.concurrent.CyclicBarrier(2);
        java.util.concurrent.Callable<Integer> reset = () -> {
            ready.await(10, java.util.concurrent.TimeUnit.SECONDS);
            return http.postForEntity("/api/v1/auth/reset-password", Map.of(
                    "email", user.email(), "code", code, "newPassword", "new-test-password"),
                    String.class).getStatusCode().value();
        };
        try {
            var first = workers.submit(reset);
            var second = workers.submit(reset);
            assertThat(List.of(first.get(20, java.util.concurrent.TimeUnit.SECONDS),
                    second.get(20, java.util.concurrent.TimeUnit.SECONDS)))
                    .containsExactlyInAnyOrder(200, 400);
        } finally {
            workers.shutdownNow();
        }
        assertThat(currentUser(user.token()).getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
        assertThat(http.postForEntity("/api/v1/auth/login", Map.of(
                "email", user.email(), "password", "new-test-password"), AuthResponse.class)
                .getStatusCode()).isEqualTo(HttpStatus.OK);
    }

    @Test
    void concurrentResendsUsingOneChallengeReturnOnlyOneReplacement() throws Exception {
        String username = unique("resend");
        String email = username + "@example.test";
        RegistrationResponse pending = register(email, username, "V32-safe-test-password",
                "restaurant_admin").getBody();
        assertThat(pending).isNotNull();

        java.util.concurrent.Callable<RegistrationResponse> resend = () -> {
            var response = http.postForEntity("/api/v1/auth/email/verification",
                    Map.of("email", email, "challengeId", pending.challengeId()),
                    RegistrationResponse.class);
            assertThat(response.getStatusCode()).isEqualTo(HttpStatus.ACCEPTED);
            return response.getBody();
        };
        var results = runTogether(resend, resend);
        assertThat(results).filteredOn(response -> response.challengeId() != null)
                .singleElement().satisfies(response ->
                        assertThat(response.requestedRole()).isEqualTo("restaurant_admin"));
        verify(lastMailChallenge(results), extractCode(lastMail()).code());
    }

    private static String lastMailChallenge(List<RegistrationResponse> responses) {
        return responses.stream().map(RegistrationResponse::challengeId)
                .filter(java.util.Objects::nonNull).findFirst().orElseThrow();
    }

    @Test
    void concurrentRecoveryRequestsLeaveJustOneActiveChallenge() throws Exception {
        RegisteredUser user = registerAndVerify("recoveryIssue", "foodie");
        java.util.concurrent.Callable<Integer> request = () ->
                http.postForEntity("/api/v1/auth/forgot-password",
                        Map.of("email", user.email()), String.class).getStatusCode().value();
        assertThat(runTogether(request, request)).containsExactly(202, 202);
        assertThat(jdbc.queryForObject("""
                select count(*) from tokens_recuperacion
                where identity_id = ? and purpose = 'PASSWORD_RESET' and consumed_at is null
                """, Integer.class, user.userId())).isEqualTo(1);
    }

    @Test
    void concurrentClientAndEmployeeClaimsCannotDuplicateAnEmail() throws Exception {
        String email = unique("identity") + "@example.test";
        assertThat(runTogether(() -> claimIdentity("client", email),
                () -> claimIdentity("employee", email.toUpperCase(java.util.Locale.ROOT))))
                .containsExactlyInAnyOrder(201, 409);
        assertThat(jdbc.queryForObject("""
                select count(*) from account_identity_registry where email_normalized = ?
                """, Integer.class, email)).isEqualTo(1);
    }

    private int claimIdentity(String type, String email) {
        try {
            identities.register(type, UUID.randomUUID().toString(), email, unique(type));
            return 201;
        } catch (org.springframework.web.server.ResponseStatusException duplicate) {
            return duplicate.getStatusCode().value();
        }
    }

    private static <T> List<T> runTogether(java.util.concurrent.Callable<T> first,
                                           java.util.concurrent.Callable<T> second) throws Exception {
        var workers = java.util.concurrent.Executors.newFixedThreadPool(2);
        var ready = new java.util.concurrent.CyclicBarrier(2);
        try {
            var left = workers.submit(() -> {
                ready.await(10, java.util.concurrent.TimeUnit.SECONDS);
                return first.call();
            });
            var right = workers.submit(() -> {
                ready.await(10, java.util.concurrent.TimeUnit.SECONDS);
                return second.call();
            });
            return List.of(left.get(20, java.util.concurrent.TimeUnit.SECONDS),
                    right.get(20, java.util.concurrent.TimeUnit.SECONDS));
        } finally {
            workers.shutdownNow();
        }
    }

    @Test
    void aDeniedSourceDoesNotConsumeTheIdentityAllowance(
            @Autowired co.edu.umb.foodies.backend.service.AuthRateLimitService limits) {
        String identity = UUID.randomUUID().toString();
        String source = UUID.randomUUID().toString();
        jdbc.update("""
                INSERT INTO auth_rate_limits (bucket_key, window_started_at, request_count)
                VALUES (?, CURRENT_TIMESTAMP, 99999)
                """, source);

        assertThat(limits.record(identity, source)).isTrue();
        assertThat(limits.record(identity, source)).isFalse();
        assertThat(jdbc.queryForObject("select request_count from auth_rate_limits where bucket_key = ?",
                Integer.class, identity)).isEqualTo(1);
        assertThat(jdbc.queryForObject("select request_count from auth_rate_limits where bucket_key = ?",
                Integer.class, source)).isEqualTo(100000);
        assertThat(limits.record(identity, UUID.randomUUID().toString())).isTrue();
    }

    @Test
    void imageOwnershipBlocksForeignReuseAndRollsBackAssociationWhenPostSaveFails() {
        RegisteredUser owner = registerAndVerify("imageOwner", "foodie");
        RegisteredUser other = registerAndVerify("imageOther", "foodie");
        String ownedUrl = recordAsset(owner.userId(), "owner");
        PostDTO post = postWithImage(ownedUrl);

        var created = postService.createPost(post, owner.userId());
        assertThat(created.getId()).isNotBlank();
        assertThat(assetRegistry.attachIfOwned("client", owner.userId(), ownedUrl, "post", created.getId()))
                .isTrue();
        assertThat(assetRegistry.attachIfOwned("client", owner.userId(), ownedUrl, "another-post", UUID.randomUUID().toString()))
                .isFalse();
        assertThatThrownBy(() -> postService.createPost(postWithImage(ownedUrl), owner.userId()))
                .isInstanceOf(org.springframework.web.server.ResponseStatusException.class);

        assertThatThrownBy(() -> postService.createPost(postWithImage(ownedUrl), other.userId()))
                .isInstanceOf(org.springframework.web.server.ResponseStatusException.class);
        assertThatThrownBy(() -> postService.createPost(
                postWithImage("https://arbitrary.example.test/not-owned.png"), owner.userId()))
                .isInstanceOf(org.springframework.web.server.ResponseStatusException.class);

        String rollbackUrl = recordAsset(owner.userId(), "rollback");
        doThrow(new DataIntegrityViolationException("synthetic persistence failure"))
                .when(postRepository).save(any(co.edu.umb.foodies.backend.model.Post.class));
        assertThatThrownBy(() -> postService.createPost(postWithImage(rollbackUrl), owner.userId()))
                .isInstanceOf(DataIntegrityViolationException.class);
        reset(postRepository);

        assertThat(jdbc.queryForObject(
                "select count(*) from cloudinary_assets where secure_url = ? and attached_at is null",
                Integer.class, rollbackUrl)).isEqualTo(1);
        assertThat(jdbc.queryForObject(
                "select count(*) from publicaciones where cliente_id = ?",
                Integer.class, owner.userId())).isEqualTo(1);

        String avatarUrl = recordAsset(owner.userId(), "avatar");
        assertThat(userService.updateAvatar(owner.userId(), owner.userId(), avatarUrl).getAvatarUrl())
                .isEqualTo(avatarUrl);
        assertThat(userService.updateAvatar(owner.userId(), owner.userId(), avatarUrl).getAvatarUrl())
                .isEqualTo(avatarUrl);
        assertThatThrownBy(() -> userService.updateAvatar(
                owner.userId(), owner.userId(), "https://arbitrary.example.test/avatar.png"))
                .isInstanceOf(org.springframework.web.server.ResponseStatusException.class);

        jdbc.update("update clientes set avatar_url = ? where id = ?",
                "https://legacy.example.test/historical.png", owner.userId());
        var legacyProfile = new co.edu.umb.foodies.backend.dto.request.UpdateProfileRequest();
        legacyProfile.setAvatarUrl("https://legacy.example.test/historical.png");
        assertThat(userService.updateProfile(owner.userId(), owner.userId(), legacyProfile).getAvatarUrl())
                .isEqualTo("https://legacy.example.test/historical.png");
    }

    private void assertEmployeeCanCompleteVerification(String role) {
        Employee employee = createEmployee(role, false);
        RegistrationResponse challenge = http.postForEntity("/api/v1/auth/email/verification",
                Map.of("email", employee.getEmail(), "password", "V32-safe-test-password"),
                RegistrationResponse.class).getBody();
        assertThat(challenge).isNotNull();
        assertThat(challenge.requestedRole()).isEqualTo("employee");
        AuthResponse verified = verify(challenge.challengeId(), extractCode(lastMail()).code());
        assertThat(verified.getUser().getRole()).isEqualTo(role);
        assertThat(jdbc.queryForObject(
                "select count(*) from sesiones_empleado where empleado_id = ? and activa = true",
                Integer.class, employee.getId())).isEqualTo(1);
    }

    private Employee createEmployee(String role, boolean verified) {
        String username = unique(role);
        Employee employee = Employee.builder()
                .id(UUID.randomUUID().toString())
                .email(username + "@example.test")
                .username(username)
                .password(passwordEncoder.encode("V32-safe-test-password"))
                .fullName("Empleado sintético de pruebas")
                .role(Employee.Role.valueOf(role))
                .isActive(true)
                .emailVerified(verified)
                .build();
        employee = employees.saveAndFlush(employee);
        identities.register("employee", employee.getId(), employee.getEmail(), employee.getUsername());
        return employee;
    }

    private RegisteredUser registerAndVerify(String prefix, String role) {
        String username = unique(prefix);
        String email = username + "@example.test";
        RegistrationResponse challenge = register(email, username, "V32-safe-test-password", role).getBody();
        assertThat(challenge).isNotNull();
        AuthResponse session = verify(challenge.challengeId(), extractCode(lastMail()).code());
        return new RegisteredUser(email, username, session.getUser().getId(), session.getToken());
    }

    private String recordAsset(String ownerId, String suffix) {
        String url = "https://res.cloudinary.com/local-test/image/upload/v1/" + suffix + "-" + UUID.randomUUID() + ".png";
        assetRegistry.recordUpload("client", ownerId,
                new CloudinaryService.UploadResult(url, "test/" + suffix + "-" + UUID.randomUUID(), "png"));
        return url;
    }

    private static PostDTO postWithImage(String url) {
        return PostDTO.builder().content("Prueba de titularidad").imageUrl(url).build();
    }

    private ResponseEntity<RegistrationResponse> register(String email, String username,
                                                           String password, String requestedRole) {
        return http.postForEntity("/api/v1/auth/register", Map.of(
                "email", email,
                "username", username,
                "password", password,
                "fullName", "Usuario de pruebas",
                "role", requestedRole), RegistrationResponse.class);
    }

    private AuthResponse verify(String challengeId, String code) {
        ResponseEntity<AuthResponse> response = http.postForEntity("/api/v1/auth/email/verify", Map.of(
                "challengeId", challengeId,
                "code", code), AuthResponse.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getBody()).isNotNull();
        assertThat(response.getBody().getTokenType()).isEqualTo("Bearer");
        assertThat(response.getBody().getExpiresInMs()).isPositive();
        return response.getBody();
    }

    private void assertSessionPersisted(AuthResponse response) {
        String tokenFingerprint = jdbc.queryForObject(
                "select session_token from sesiones_cliente where cliente_id = ?",
                String.class, response.getUser().getId());
        assertThat(tokenFingerprint).matches("v1:[0-9a-f]{64}");
        assertThat(response.getToken()).hasSizeGreaterThan(191);
    }

    private SimpleMailMessage lastMail() {
        ArgumentCaptor<SimpleMailMessage> captor = ArgumentCaptor.forClass(SimpleMailMessage.class);
        org.mockito.Mockito.verify(mailSender, org.mockito.Mockito.atLeastOnce()).send(captor.capture());
        List<SimpleMailMessage> messages = captor.getAllValues();
        return messages.get(messages.size() - 1);
    }

    private static VerificationCode extractCode(SimpleMailMessage message) {
        String body = message.getText();
        Matcher code = Pattern.compile("es: ([0-9]{6})").matcher(body);
        Matcher challenge = Pattern.compile("Identificador de desafío: ([0-9a-fA-F-]{36})").matcher(body);
        assertThat(code.find()).as("six-digit OTP is included only in the mocked email").isTrue();
        assertThat(challenge.find()).as("challenge identifier is included in the mocked email").isTrue();
        return new VerificationCode(challenge.group(1), code.group(1));
    }

    private ResponseEntity<UserResponse> currentUser(String token) {
        return http.exchange("/api/v1/auth/me", HttpMethod.GET,
                new HttpEntity<>(headers(token)), UserResponse.class);
    }

    private static HttpHeaders headers(String token) {
        HttpHeaders headers = new HttpHeaders();
        if (token != null) headers.setBearerAuth(token);
        return headers;
    }

    private static String unique(String prefix) {
        return prefix + "_" + UUID.randomUUID().toString().replace("-", "");
    }

    private record VerificationCode(String challengeId, String code) {}
    private record RegisteredUser(String email, String username, String userId, String token) {}
}
