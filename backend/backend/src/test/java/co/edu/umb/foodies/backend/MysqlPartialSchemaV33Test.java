package co.edu.umb.foodies.backend;

import org.flywaydb.core.Flyway;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.core.io.ClassPathResource;
import org.springframework.jdbc.datasource.init.ScriptUtils;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.Statement;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

@EnabledIfEnvironmentVariable(named = "SAVORSYNC_V33_MYSQL84_TEST", matches = "true")
class MysqlPartialSchemaV33Test {
    private static final String SERVER = "jdbc:mysql://127.0.0.1:3308/";
    private static final String OPTIONS = "?sslMode=DISABLED&allowPublicKeyRetrieval=true";

    @Test
    void copiesPartialSchemaIntoFreshValidatedFlywayDestination() throws Exception {
        String source = createSchema("partial");
        String target = createSchema("target");
        seed(source);
        migrate(target);
        copy(source, target);

        try (Connection connection = connect(target); Statement sql = connection.createStatement()) {
            assertThat(number(sql, "SELECT COUNT(*) FROM clientes")).isEqualTo(2);
            assertThat(number(sql, "SELECT COUNT(*) FROM empleados WHERE id = 'legacy-mod' AND email_verified = 0"))
                    .isEqualTo(1);
            assertThat(number(sql, "SELECT COUNT(*) FROM account_identity_registry")).isEqualTo(3);
            assertThat(number(sql, """
                    SELECT COUNT(*) FROM reservas r JOIN publicaciones p ON p.restaurante_id = r.restaurante_id
                    JOIN menu_restaurante m ON m.restaurante_id = r.restaurante_id
                    JOIN imagenes_publicacion i ON i.publicacion_id = p.id
                    WHERE r.id = 'legacy-reservation' AND m.id = 'legacy-menu'
                      AND p.id = 'legacy-post' AND i.url LIKE 'https://images.example.test/%'
                    """)).isEqualTo(1);
            assertThat(number(sql, "SELECT COUNT(*) FROM comentarios WHERE id = 'legacy-reply' AND parent_id = 'legacy-comment'"))
                    .isEqualTo(1);
            assertThat(number(sql, "SELECT COUNT(*) FROM sesiones_cliente WHERE id = 'legacy-session' AND activa = 0"))
                    .isEqualTo(1);
            assertThat(number(sql, """
                    SELECT COUNT(*) FROM tokens_recuperacion WHERE id = 'legacy-code'
                    AND code = 'legacy-invalidated' AND consumed_at IS NOT NULL
                    """)).isEqualTo(1);
        }
        verifyApplicationAndBootstrap(target);
    }

    private static void verifyApplicationAndBootstrap(String schema) {
        try (var context = new org.springframework.boot.builder.SpringApplicationBuilder(
                BackendApplication.class, SimulatedEmailConfiguration.class).run(
                "--spring.profiles.active=v33-local",
                "--spring.datasource.url=" + SERVER + schema + OPTIONS,
                "--spring.datasource.username=root",
                "--spring.datasource.password=" + password(),
                "--spring.flyway.enabled=false",
                "--spring.jpa.hibernate.ddl-auto=validate",
                "--app.jwt.secret=" + UUID.randomUUID() + UUID.randomUUID(),
                "--cloudinary.cloud-name=fixture",
                "--cloudinary.api-key=fixture",
                "--cloudinary.api-secret=fixture",
                "--server.port=0", "--server.address=127.0.0.1")) {
            var server = (org.springframework.boot.web.servlet.context.ServletWebServerApplicationContext) context;
            var http = new org.springframework.boot.test.web.client.TestRestTemplate(
                    new org.springframework.boot.web.client.RestTemplateBuilder().rootUri(
                            "http://127.0.0.1:" + server.getWebServer().getPort()));
            var health = http.getForEntity("/actuator/health", java.util.Map.class);
            assertThat(health.getStatusCode().value()).isEqualTo(200);
            assertThat(health.getBody()).isEqualTo(java.util.Map.of("status", "UP"));

            var provisioning = context.getBean(co.edu.umb.foodies.backend.service.FirstAdminProvisioning.class);
            var identity = new co.edu.umb.foodies.backend.service.FirstAdminProvisioning.Identity(
                    "first-admin@example.test", "first.admin", "Synthetic Administrator");
            String secret = "fixture-admin-password-long";
            provisioning.create(identity, secret.toCharArray());
            assertThatThrownBy(() -> provisioning.create(identity, secret.toCharArray()))
                    .isInstanceOf(IllegalStateException.class);

            var credentials = java.util.Map.of("email", identity.email(), "password", secret);
            var blocked = http.postForEntity("/api/v1/auth/login", credentials, String.class);
            assertThat(blocked.getStatusCode().value()).isEqualTo(403);
            assertThat(blocked.getBody()).doesNotContain("\"token\"");

            var challenge = http.postForEntity("/api/v1/auth/email/verification", credentials,
                    co.edu.umb.foodies.backend.dto.response.RegistrationResponse.class);
            assertThat(challenge.getStatusCode().value()).isEqualTo(202);
            var message = context.getBean(SimulatedEmail.class).last;
            var code = java.util.regex.Pattern.compile("\\b[0-9]{6}\\b").matcher(message.text());
            assertThat(code.find()).isTrue();
            var verified = http.postForEntity("/api/v1/auth/email/verify", java.util.Map.of(
                            "challengeId", challenge.getBody().challengeId(), "code", code.group()),
                    co.edu.umb.foodies.backend.dto.response.AuthResponse.class);
            assertThat(verified.getStatusCode().value()).isEqualTo(200);
            var session = verified.getBody();
            assertThat(session.getUser().getRole()).isEqualTo("admin_sistema");
            assertThat(http.postForEntity("/api/v1/auth/login", credentials, String.class)
                    .getStatusCode().value()).isEqualTo(200);

            var headers = new org.springframework.http.HttpHeaders();
            headers.setBearerAuth(session.getToken());
            assertThat(http.exchange("/api/v1/users", org.springframework.http.HttpMethod.GET,
                    new org.springframework.http.HttpEntity<>(headers), String.class)
                    .getStatusCode().value()).isEqualTo(200);
            var moderator = java.util.Map.of("email", "new-moderator@example.test",
                    "username", "new.moderator", "password", "fixture-moderator-password",
                    "fullName", "Synthetic Moderator");
            assertThat(http.postForEntity("/api/v1/auth/moderators",
                    new org.springframework.http.HttpEntity<>(moderator, headers), String.class)
                    .getStatusCode().value()).isEqualTo(201);
            var moderatorSession = verifyRecordedCode(http, context.getBean(SimulatedEmail.class).last);
            var modHeaders = new org.springframework.http.HttpHeaders();
            modHeaders.setBearerAuth(moderatorSession.getToken());

            var foodie = java.util.Map.of("email", "new-foodie@example.test", "username", "new.foodie",
                    "password", "fixture-foodie-password", "fullName", "Synthetic Foodie", "role", "foodie");
            assertThat(http.postForEntity("/api/v1/auth/register", foodie, String.class)
                    .getStatusCode().value()).isEqualTo(202);
            var foodieSession = verifyRecordedCode(http, context.getBean(SimulatedEmail.class).last);
            assertThat(foodieSession.getUser().getRole()).isEqualTo("foodie");
            var foodieHeaders = new org.springframework.http.HttpHeaders();
            foodieHeaders.setBearerAuth(foodieSession.getToken());
            var request = new org.springframework.http.HttpEntity<>(
                    java.util.Map.of("description", "Synthetic restaurant application"), foodieHeaders);
            var firstRequest = http.postForEntity("/api/v1/auth/restaurant-admin/request", request, java.util.Map.class);
            var secondRequest = http.postForEntity("/api/v1/auth/restaurant-admin/request", request, java.util.Map.class);
            assertThat(firstRequest.getStatusCode().value()).isEqualTo(202);
            assertThat(secondRequest.getStatusCode().value()).isEqualTo(202);
            String requestId = (String) firstRequest.getBody().get("id");
            assertThat(secondRequest.getBody()).containsEntry("id", requestId);

            String approval = "/api/v1/auth/restaurant-admin/requests/" + requestId + "/approve";
            assertThat(http.postForEntity(approval, new org.springframework.http.HttpEntity<>(modHeaders), String.class)
                    .getStatusCode().value()).isEqualTo(403);
            var approved = http.postForEntity(approval, new org.springframework.http.HttpEntity<>(headers), java.util.Map.class);
            assertThat(approved.getStatusCode().value()).isEqualTo(200);
            assertThat(approved.getBody()).containsEntry("role", "restaurant_admin");
            assertThat(http.exchange("/api/v1/auth/me", org.springframework.http.HttpMethod.GET,
                    new org.springframework.http.HttpEntity<>(foodieHeaders), String.class)
                    .getStatusCode().value()).isEqualTo(401);
        }
    }

    private static co.edu.umb.foodies.backend.dto.response.AuthResponse verifyRecordedCode(
            org.springframework.boot.test.web.client.TestRestTemplate http,
            co.edu.umb.foodies.backend.service.SecurityEmailEvent message) {
        var otp = java.util.regex.Pattern.compile("es: ([0-9]{6})").matcher(message.text());
        var challenge = java.util.regex.Pattern.compile("Identificador de desafío: ([a-f0-9-]{36})")
                .matcher(message.text());
        assertThat(otp.find()).isTrue();
        assertThat(challenge.find()).isTrue();
        var response = http.postForEntity("/api/v1/auth/email/verify",
                java.util.Map.of("challengeId", challenge.group(1), "code", otp.group(1)),
                co.edu.umb.foodies.backend.dto.response.AuthResponse.class);
        assertThat(response.getStatusCode().value()).isEqualTo(200);
        return response.getBody();
    }

    @org.springframework.boot.test.context.TestConfiguration
    static class SimulatedEmailConfiguration {
        @org.springframework.context.annotation.Bean
        @org.springframework.context.annotation.Primary
        SimulatedEmail simulatedEmail() {
            return new SimulatedEmail();
        }
    }

    static class SimulatedEmail implements co.edu.umb.foodies.backend.service.SecurityEmailProvider {
        volatile co.edu.umb.foodies.backend.service.SecurityEmailEvent last;

        @Override
        public Delivery send(co.edu.umb.foodies.backend.service.SecurityEmailEvent event) {
            last = event;
            return Delivery.ACCEPTED;
        }
    }

    @Test
    void incompatiblePartialRowsAbortWithoutCopyingOtherRows() throws Exception {
        String source = createSchema("bad");
        String target = createSchema("empty");
        seed(source);
        try (Connection connection = connect(source); Statement sql = connection.createStatement()) {
            sql.executeUpdate("UPDATE comentarios SET contenido = REPEAT('x', 201) WHERE id = 'legacy-comment'");
        }
        migrate(target);
        assertThatThrownBy(() -> copy(source, target)).hasMessageContaining("comments fit 200 characters");
        try (Connection connection = connect(target); Statement sql = connection.createStatement()) {
            assertThat(number(sql, "SELECT COUNT(*) FROM clientes")).isZero();
            assertThat(number(sql, "SELECT COUNT(*) FROM account_identity_registry")).isZero();
        }
    }

    private static String createSchema(String purpose) throws Exception {
        String schema = "savorsync_v33_" + purpose + "_" + UUID.randomUUID().toString().substring(0, 8);
        try (Connection connection = connect("mysql"); Statement sql = connection.createStatement()) {
            sql.execute("CREATE DATABASE " + schema + " CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci");
        }
        return schema;
    }

    private static void seed(String schema) throws Exception {
        try (Connection connection = connect(schema)) {
            ScriptUtils.executeSqlScript(connection, new ClassPathResource("mysql/v33-partial-model.sql"));
        }
    }

    private static void migrate(String schema) {
        var flyway = Flyway.configure().dataSource(SERVER + schema + OPTIONS, "root", password())
                .locations("classpath:db/migration").baselineOnMigrate(false).load();
        assertThat(flyway.migrate().migrationsExecuted).isEqualTo(5);
        assertThat(flyway.migrate().migrationsExecuted).isZero();
        flyway.validate();
    }

    private static void copy(String source, String target) throws Exception {
        String copyScript = Files.readString(Path.of("ops", "copy-partial-schema.sql"));
        try (Connection connection = connect(target)) {
            ScriptUtils.executeSqlScript(connection, new ByteArrayResource(
                    copyScript.replace("savorsync_legacy_source", source).getBytes(StandardCharsets.UTF_8)));
        }
    }

    private static Connection connect(String schema) throws Exception {
        return DriverManager.getConnection(SERVER + schema + OPTIONS, "root", password());
    }

    private static String password() {
        String password = System.getenv("SAVORSYNC_V33_MYSQL84_ROOT_PASSWORD");
        if (password == null || password.isBlank()) throw new IllegalStateException("Missing local test credential");
        return password;
    }

    private static int number(Statement statement, String query) throws Exception {
        try (var result = statement.executeQuery(query)) {
            assertThat(result.next()).isTrue();
            return result.getInt(1);
        }
    }
}
