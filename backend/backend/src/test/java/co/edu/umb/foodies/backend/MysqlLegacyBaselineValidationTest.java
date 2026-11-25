package co.edu.umb.foodies.backend;

import org.flywaydb.core.Flyway;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.jdbc.datasource.init.ScriptUtils;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.Statement;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class MysqlLegacyBaselineValidationTest {

    private static final String CLIENT_ID = "f3210000-0000-4000-8000-000000000001";
    private static final String SECOND_CLIENT_ID = "f3210000-0000-4000-8000-000000000002";
    private static final String EMPLOYEE_ID = "f3210000-0000-4000-8000-000000000003";
    private static final String RESTAURANT_ID = "f3210000-0000-4000-8000-000000000004";
    private static final String POST_ID = "f3210000-0000-4000-8000-000000000005";
    private static final String FOLLOW_ID = "f3210000-0000-4000-8000-000000000006";
    private static final String RESERVATION_ID = "f3210000-0000-4000-8000-000000000007";

    @Test
    @EnabledIfEnvironmentVariable(named = "SAVORSYNC_RUN_MYSQL_MIGRATION_VALIDATION", matches = "true")
    void explicitLegacyBaselinePreservesAccountsRestaurantsPostsReservationsAndRelations() throws Exception {
        String schema = uniqueSchema("legacy");
        LocalDatabase db = prepareSchema(schema);
        boolean previousTrust = enableTriggerCreation(db.rootUrl());
        try {
            installOriginalLegacySchema(db.schemaUrl());
            seedLegacyRows(db.schemaUrl());

            Flyway flyway = Flyway.configure()
                    .dataSource(db.schemaUrl(), db.user(), db.password())
                    .locations("classpath:db/migration")
                    .baselineOnMigrate(false)
                    .baselineVersion("1")
                    .baselineDescription("Verified original 22-table SavorSync schema")
                    .load();
            flyway.baseline();
            flyway.migrate();
            flyway.migrate();

            try (Connection connection = DriverManager.getConnection(
                    db.schemaUrl(), db.user(), db.password());
                 Statement statement = connection.createStatement()) {
                assertThat(count(statement, "clientes", schema)).isEqualTo(2);
                assertThat(count(statement, "empleados", schema)).isEqualTo(1);
                assertThat(count(statement, "restaurantes", schema)).isEqualTo(1);
                assertThat(count(statement, "publicaciones", schema)).isEqualTo(1);
                assertThat(count(statement, "seguidores", schema)).isEqualTo(1);
                assertThat(count(statement, "reservas", schema)).isEqualTo(1);
                assertThat(count(statement, "tokens_recuperacion", schema)).isZero();
                assertThat(count(statement, "flyway_schema_history", schema)).isEqualTo(5);

                try (ResultSet requestedRole = statement.executeQuery(
                        "SELECT requested_role FROM account_identity_registry "
                                + "WHERE identity_type = 'client' AND identity_id = '" + CLIENT_ID + "'")) {
                    assertThat(requestedRole.next()).isTrue();
                    assertThat(requestedRole.getString(1)).isEqualTo("restaurant_admin");
                }
                try (ResultSet employee = statement.executeQuery(
                        "SELECT email_verified FROM empleados WHERE id = '" + EMPLOYEE_ID + "'")) {
                    assertThat(employee.next()).isTrue();
                    assertThat(employee.getBoolean(1)).isFalse();
                }
                assertThat(count(statement, "restaurantes", schema,
                        "id = '" + RESTAURANT_ID + "' AND owner_id = '" + CLIENT_ID + "'")).isEqualTo(1);
                assertThat(count(statement, "publicaciones", schema,
                        "id = '" + POST_ID + "' AND cliente_id = '" + CLIENT_ID
                                + "' AND restaurante_id = '" + RESTAURANT_ID + "'")).isEqualTo(1);
                assertThat(count(statement, "reservas", schema,
                        "id = '" + RESERVATION_ID + "' AND cliente_id = '" + CLIENT_ID
                                + "' AND restaurante_id = '" + RESTAURANT_ID + "'")).isEqualTo(1);
                assertThat(count(statement, "seguidores", schema,
                        "id = '" + FOLLOW_ID + "' AND seguidor_id = '" + CLIENT_ID
                                + "' AND seguido_id = '" + SECOND_CLIENT_ID + "'")).isEqualTo(1);

                try (ResultSet tables = statement.executeQuery(
                        "SELECT COUNT(*) FROM information_schema.tables "
                                + "WHERE table_schema = '" + schema + "' AND table_type = 'BASE TABLE'")) {
                    tables.next();
                    assertThat(tables.getInt(1)).isEqualTo(27);
                }
            }
        } finally {
            restoreTriggerCreation(db.rootUrl(), previousTrust);
        }
    }

    @Test
    @EnabledIfEnvironmentVariable(named = "SAVORSYNC_RUN_MYSQL_MIGRATION_VALIDATION", matches = "true")
    void duplicateNormalizedIdentityStopsLegacyMigrationWithoutDeletingAccounts() throws Exception {
        String schema = uniqueSchema("collision");
        LocalDatabase db = prepareSchema(schema);
        boolean previousTrust = enableTriggerCreation(db.rootUrl());
        try {
            installOriginalLegacySchema(db.schemaUrl());
            try (Connection connection = DriverManager.getConnection(
                    db.schemaUrl(), db.user(), db.password());
                 Statement statement = connection.createStatement()) {
                statement.executeUpdate("INSERT INTO clientes "
                        + "(id, email, username, password, full_name) VALUES "
                        + "('f3220000-0000-4000-8000-000000000001', "
                        + "'duplicate@example.test', 'client-duplicate', 'synthetic-test-only', 'Synthetic Client')");
                statement.executeUpdate("INSERT INTO empleados "
                        + "(id, email, username, password, full_name, cargo) VALUES "
                        + "('f3220000-0000-4000-8000-000000000002', "
                        + "'DUPLICATE@example.test', 'employee-duplicate', 'synthetic-test-only', "
                        + "'Synthetic Employee', 'moderador')");
            }

            Flyway flyway = Flyway.configure()
                    .dataSource(db.schemaUrl(), db.user(), db.password())
                    .locations("classpath:db/migration")
                    .baselineOnMigrate(false)
                    .baselineVersion("1")
                    .baselineDescription("Collision fixture for the original schema")
                    .load();
            flyway.baseline();

            assertThatThrownBy(flyway::migrate)
                    .hasMessageContaining("V3__identity_challenges_and_rate_limits.sql");
            try (Connection connection = DriverManager.getConnection(
                    db.schemaUrl(), db.user(), db.password());
                 Statement statement = connection.createStatement()) {
                assertThat(count(statement, "clientes", schema)).isEqualTo(1);
                assertThat(count(statement, "empleados", schema)).isEqualTo(1);
                try (ResultSet collision = statement.executeQuery(
                        "SELECT COUNT(*) FROM ("
                                + "SELECT LOWER(TRIM(email)) normalized_email FROM clientes "
                                + "UNION ALL "
                                + "SELECT LOWER(TRIM(email)) normalized_email FROM empleados"
                                + ") identities GROUP BY normalized_email HAVING COUNT(*) > 1")) {
                    assertThat(collision.next()).isTrue();
                    assertThat(collision.getLong(1)).isEqualTo(2);
                }
                assertThat(count(statement, "flyway_schema_history", schema,
                        "version = '2' AND success = 1")).isEqualTo(1);
                assertThat(count(statement, "flyway_schema_history", schema,
                        "version = '3' AND success = 0")).isEqualTo(1);
                assertThat(count(statement, "account_identity_registry", schema)).isZero();
            }
        } finally {
            restoreTriggerCreation(db.rootUrl(), previousTrust);
        }
    }

    private static String uniqueSchema(String purpose) {
        return "foodies_db_v32_" + purpose + "_"
                + java.util.UUID.randomUUID().toString().replace("-", "").substring(0, 8);
    }

    private static LocalDatabase prepareSchema(String schema) throws Exception {
        String originalUrl = required("SAVORSYNC_SESSION_MYSQL_URL");
        assertThat(originalUrl)
                .as("Migration validation may only connect to the local MySQL test server")
                .matches("jdbc:mysql://127\\.0\\.0\\.1:[0-9]+/foodies_db(?:_v32_[a-z0-9_]+)?(?:\\?.*)?");
        String user = required("SAVORSYNC_SESSION_MYSQL_USER");
        String password = required("SAVORSYNC_SESSION_MYSQL_PASSWORD");
        String rootPassword = required("SAVORSYNC_SESSION_MYSQL_ROOT_PASSWORD");
        String rootUrl = originalUrl.replaceFirst("/foodies_db(?:_v32_[a-z0-9_]+)?(?:\\?.*)?$",
                "/mysql?sslMode=DISABLED&allowPublicKeyRetrieval=true");
        String schemaUrl = originalUrl.replaceFirst("/foodies_db(?:_v32_[a-z0-9_]+)?(?:\\?.*)?$",
                "/" + schema + "?sslMode=DISABLED&allowPublicKeyRetrieval=true");
        try (Connection root = DriverManager.getConnection(rootUrl, "root", rootPassword);
             Statement statement = root.createStatement()) {
            try (ResultSet existing = statement.executeQuery(
                    "SELECT COUNT(*) FROM information_schema.schemata WHERE schema_name = '" + schema + "'")) {
                existing.next();
                if (existing.getInt(1) == 0) {
                    statement.execute("CREATE DATABASE " + schema
                            + " CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci");
                } else {
                    try (ResultSet tables = statement.executeQuery(
                            "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '" + schema + "'")) {
                        tables.next();
                        assertThat(tables.getInt(1))
                                .as("Disposable legacy fixture schema is expected to be unused")
                                .isZero();
                    }
                }
            }
            statement.execute("CREATE USER IF NOT EXISTS '" + escapeSqlLiteral(user)
                    + "'@'%' IDENTIFIED BY '" + escapeSqlLiteral(password) + "'");
            statement.execute("GRANT ALL PRIVILEGES ON " + schema + ".* TO '"
                    + escapeSqlLiteral(user) + "'@'%'");
        }
        return new LocalDatabase(rootUrl, schemaUrl, user, password, rootPassword);
    }

    private static void installOriginalLegacySchema(String schemaUrl) throws Exception {
        Path sqlPath = Path.of(System.getProperty("user.dir"), "..", "..", "schema_foodies_db.sql")
                .toAbsolutePath().normalize();
        String source = Files.readString(sqlPath, StandardCharsets.UTF_8);
        assertThat(source).contains("DROP DATABASE IF EXISTS foodies_db;");
        int schemaStart = source.indexOf("CREATE TABLE clientes");
        assertThat(schemaStart).isGreaterThanOrEqualTo(0);
        String safeLegacySql = source.substring(schemaStart);
        assertThat(safeLegacySql.toUpperCase(java.util.Locale.ROOT))
                .doesNotContain("DROP DATABASE", "CREATE DATABASE", "USE FOODIES_DB");
        try (Connection connection = DriverManager.getConnection(
                schemaUrl, required("SAVORSYNC_SESSION_MYSQL_USER"),
                required("SAVORSYNC_SESSION_MYSQL_PASSWORD"))) {
            ScriptUtils.executeSqlScript(connection,
                    new ByteArrayResource(safeLegacySql.getBytes(StandardCharsets.UTF_8)));
        }
    }

    private static void seedLegacyRows(String schemaUrl) throws Exception {
        try (Connection connection = DriverManager.getConnection(
                schemaUrl, required("SAVORSYNC_SESSION_MYSQL_USER"),
                required("SAVORSYNC_SESSION_MYSQL_PASSWORD"));
             Statement statement = connection.createStatement()) {
            statement.executeUpdate("INSERT INTO clientes (id, email, username, password, full_name, rol) VALUES "
                    + "('" + CLIENT_ID + "', 'legacy-admin@example.test', 'legacy-admin', "
                    + "'synthetic-test-only', 'Synthetic Legacy Applicant', 'restaurant_admin')");
            statement.executeUpdate("INSERT INTO clientes (id, email, username, password, full_name, rol) VALUES "
                    + "('" + SECOND_CLIENT_ID + "', 'legacy-foodie@example.test', 'legacy-foodie', "
                    + "'synthetic-test-only', 'Synthetic Legacy Foodie', 'foodie')");
            statement.executeUpdate("INSERT INTO empleados (id, email, username, password, full_name, cargo) VALUES "
                    + "('" + EMPLOYEE_ID + "', 'legacy-admin-system@example.test', 'legacy-system-admin', "
                    + "'synthetic-test-only', 'Synthetic Legacy System Admin', 'admin_sistema')");
            statement.executeUpdate("INSERT INTO restaurantes "
                    + "(id, owner_id, nombre, direccion, ciudad, categoria, estado) VALUES "
                    + "('" + RESTAURANT_ID + "', '" + CLIENT_ID
                    + "', 'Synthetic Legacy Restaurant', 'Test Address', 'Test City', 'Synthetic', 'activo')");
            statement.executeUpdate("INSERT INTO publicaciones "
                    + "(id, cliente_id, restaurante_id, contenido, calificacion, estado) VALUES "
                    + "('" + POST_ID + "', '" + CLIENT_ID + "', '" + RESTAURANT_ID
                    + "', 'Synthetic legacy review', 5, 'publicada')");
            statement.executeUpdate("INSERT INTO seguidores (id, seguidor_id, seguido_id) VALUES "
                    + "('" + FOLLOW_ID + "', '" + CLIENT_ID + "', '" + SECOND_CLIENT_ID + "')");
            statement.executeUpdate("INSERT INTO reservas "
                    + "(id, restaurante_id, cliente_id, num_personas, fecha_reserva, hora_reserva) VALUES "
                    + "('" + RESERVATION_ID + "', '" + RESTAURANT_ID + "', '" + CLIENT_ID
                    + "', 2, '2030-01-02', '19:00:00')");
        }
    }

    private static long count(Statement statement, String table, String schema) throws Exception {
        return count(statement, table, schema, "1 = 1");
    }

    private static long count(Statement statement, String table, String schema, String where) throws Exception {
        try (ResultSet result = statement.executeQuery(
                "SELECT COUNT(*) FROM " + schema + "." + table + " WHERE " + where)) {
            result.next();
            return result.getLong(1);
        }
    }

    private static boolean enableTriggerCreation(String rootUrl) throws Exception {
        try (Connection root = DriverManager.getConnection(
                rootUrl, "root", required("SAVORSYNC_SESSION_MYSQL_ROOT_PASSWORD"));
             Statement statement = root.createStatement();
             ResultSet setting = statement.executeQuery(
                     "SELECT @@GLOBAL.log_bin_trust_function_creators")) {
            setting.next();
            boolean previous = setting.getBoolean(1);
            statement.execute("SET GLOBAL log_bin_trust_function_creators = 1");
            return previous;
        }
    }

    private static void restoreTriggerCreation(String rootUrl, boolean previous) throws Exception {
        try (Connection root = DriverManager.getConnection(
                rootUrl, "root", required("SAVORSYNC_SESSION_MYSQL_ROOT_PASSWORD"));
             Statement statement = root.createStatement()) {
            statement.execute("SET GLOBAL log_bin_trust_function_creators = " + (previous ? "1" : "0"));
        }
    }

    private static String required(String key) {
        String value = System.getenv(key);
        if (value == null || value.isBlank()) {
            throw new IllegalStateException(key + " must be set for local MySQL migration validation.");
        }
        return value;
    }

    private static String escapeSqlLiteral(String value) {
        return value.replace("'", "''");
    }

    private record LocalDatabase(
            String rootUrl,
            String schemaUrl,
            String user,
            String password,
            String rootPassword) {}
}
