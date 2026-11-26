package co.edu.umb.foodies.backend;

import org.flywaydb.core.Flyway;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.Statement;

import static org.assertj.core.api.Assertions.assertThat;

class MysqlMigrationValidationTest {

    private static final String FRESH_SCHEMA = "foodies_db_v33_empty_"
            + java.util.UUID.randomUUID().toString().substring(0, 8);

    @Test
    @EnabledIfEnvironmentVariable(named = "SAVORSYNC_RUN_MYSQL_MIGRATION_VALIDATION", matches = "true")
    void migratesFreshDisposableSchemaAndValidatesFlywayHistory() throws Exception {
        String originalUrl = required("SAVORSYNC_SESSION_MYSQL_URL");
        String user = required("SAVORSYNC_SESSION_MYSQL_USER");
        String password = required("SAVORSYNC_SESSION_MYSQL_PASSWORD");
        String rootPassword = required("SAVORSYNC_SESSION_MYSQL_ROOT_PASSWORD");
        String rootUrl = originalUrl.replaceFirst("/foodies_db(?:_v(?:32|34)_[a-z0-9_]+)?(?:\\?.*)?$",
                "/mysql?sslMode=DISABLED&allowPublicKeyRetrieval=true");
        String freshUrl = originalUrl.replaceFirst("/foodies_db(?:_v(?:32|34)_[a-z0-9_]+)?(?:\\?.*)?$",
                "/" + FRESH_SCHEMA + "?sslMode=DISABLED&allowPublicKeyRetrieval=true");

        boolean previousTrustFunctionCreators;
        boolean alreadyMigrated = false;
        try (Connection root = DriverManager.getConnection(rootUrl, "root", rootPassword);
             Statement statement = root.createStatement()) {
            boolean exists;
            try (ResultSet databases = statement.executeQuery(
                    "SELECT COUNT(*) FROM information_schema.schemata WHERE schema_name = '" + FRESH_SCHEMA + "'")) {
                databases.next();
                exists = databases.getInt(1) != 0;
            }
            if (exists) {
                int tablesCount;
                try (ResultSet tables = statement.executeQuery(
                        "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '" + FRESH_SCHEMA + "'")) {
                    tables.next();
                    tablesCount = tables.getInt(1);
                }
                if (tablesCount != 0) {
                    assertThat(tablesCount).as("Existing validation schema must be complete").isEqualTo(27);
                    try (ResultSet history = statement.executeQuery(
                            "SELECT COUNT(*), SUM(success) FROM " + FRESH_SCHEMA
                                    + ".flyway_schema_history WHERE version IS NOT NULL")) {
                        history.next();
                        assertThat(history.getInt(1)).isEqualTo(6);
                        assertThat(history.getInt(2)).isEqualTo(6);
                        alreadyMigrated = true;
                    }
                }
            } else {
                statement.execute("CREATE DATABASE " + FRESH_SCHEMA
                        + " CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci");
            }

            statement.execute("CREATE USER IF NOT EXISTS 'savorsync_test'@'%' IDENTIFIED BY '"
                    + escapeSqlLiteral(password) + "'");
            statement.execute("GRANT ALL PRIVILEGES ON " + FRESH_SCHEMA
                    + ".* TO 'savorsync_test'@'%'");
            try (ResultSet setting = statement.executeQuery(
                    "SELECT @@GLOBAL.log_bin_trust_function_creators")) {
                setting.next();
                previousTrustFunctionCreators = setting.getBoolean(1);
            }
            // MySQL 8 requires this local-only setting to create triggers without SUPER when binary logging is enabled.
            statement.execute("SET GLOBAL log_bin_trust_function_creators = 1");
        }

        Flyway flyway = Flyway.configure()
                .dataSource(freshUrl, user, password)
                .locations("classpath:db/migration")
                .baselineOnMigrate(false)
                .load();

        try {
            if (!alreadyMigrated) {
                Flyway throughV4 = Flyway.configure()
                        .dataSource(freshUrl, user, password)
                        .locations("classpath:db/migration")
                        .target("4")
                        .baselineOnMigrate(false)
                        .load();
                throughV4.migrate();
                try (Connection connection = DriverManager.getConnection(freshUrl, user, password);
                     Statement statement = connection.createStatement()) {
                    statement.executeUpdate("INSERT INTO clientes "
                            + "(id, email, username, password, full_name, rol) VALUES "
                            + "('f32c0000-0000-4000-8000-000000000001', "
                            + "'legacy-admin@example.test', 'legacy-admin', 'synthetic-only', "
                            + "'Synthetic legacy applicant', 'restaurant_admin') "
                            + "ON DUPLICATE KEY UPDATE rol = 'restaurant_admin'");
                    statement.executeUpdate("INSERT INTO account_identity_registry "
                            + "(identity_type, identity_id, email_normalized, username_normalized) VALUES "
                            + "('client', 'f32c0000-0000-4000-8000-000000000001', "
                            + "'legacy-admin@example.test', 'legacy-admin') "
                            + "ON DUPLICATE KEY UPDATE email_normalized = VALUES(email_normalized)");
                }
            }
            assertThat(flyway.migrate().migrationsExecuted).isEqualTo(alreadyMigrated ? 0 : 2);
            assertThat(flyway.migrate().migrationsExecuted).isZero();
            flyway.validate();
        } finally {
            try (Connection root = DriverManager.getConnection(rootUrl, "root", rootPassword);
                 Statement statement = root.createStatement()) {
                statement.execute("SET GLOBAL log_bin_trust_function_creators = "
                        + (previousTrustFunctionCreators ? "1" : "0"));
            }
        }

        try (Connection connection = DriverManager.getConnection(freshUrl, user, password);
             Statement statement = connection.createStatement()) {
            try (ResultSet count = statement.executeQuery(
                    "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '" + FRESH_SCHEMA
                            + "' AND table_type = 'BASE TABLE'")) {
                count.next();
                assertThat(count.getInt(1))
                        .as("22 academic tables + four additions + Flyway history")
                        .isEqualTo(27);
            }
            try (ResultSet triggers = statement.executeQuery(
                    "SELECT COUNT(*) FROM information_schema.triggers WHERE trigger_schema = '" + FRESH_SCHEMA + "'")) {
                triggers.next();
                assertThat(triggers.getInt(1)).isEqualTo(31);
            }
            try (ResultSet keys = statement.executeQuery("""
                    SELECT SUM(constraint_type = 'PRIMARY KEY') AS primary_keys,
                           SUM(constraint_type = 'FOREIGN KEY') AS foreign_keys
                    FROM information_schema.table_constraints
                    WHERE constraint_schema = DATABASE()
                    """)) {
                assertThat(keys.next()).isTrue();
                assertThat(keys.getInt("primary_keys")).isEqualTo(27);
                assertThat(keys.getInt("foreign_keys")).isEqualTo(35);
            }
            try (ResultSet index = statement.executeQuery("""
                    SELECT column_name FROM information_schema.statistics
                    WHERE table_schema = DATABASE() AND table_name = 'tokens_recuperacion'
                      AND index_name = 'uk_security_challenge_active' AND non_unique = 0
                    ORDER BY seq_in_index
                    """)) {
                var columns = new java.util.ArrayList<String>();
                while (index.next()) columns.add(index.getString(1));
                assertThat(columns).containsExactly("identity_type", "purpose", "active_identity_id");
            }
            try (ResultSet definitions = statement.executeQuery("""
                    SELECT table_name, column_name, column_type, is_nullable
                    FROM information_schema.columns
                    WHERE table_schema = DATABASE()
                      AND (table_name, column_name) IN (
                          ('clientes', 'rol'), ('empleados', 'cargo'),
                          ('sesiones_cliente', 'plataforma'), ('sesiones_empleado', 'plataforma'),
                          ('comentarios', 'contenido'))
                    """)) {
                var columns = new java.util.HashMap<String, String>();
                while (definitions.next()) {
                    assertThat(definitions.getString("is_nullable")).isEqualTo("NO");
                    columns.put(definitions.getString("table_name") + "." + definitions.getString("column_name"),
                            definitions.getString("column_type"));
                }
                assertThat(columns).containsExactlyInAnyOrderEntriesOf(java.util.Map.of(
                        "clientes.rol", "enum('foodie','restaurant_admin')",
                        "empleados.cargo", "enum('moderador','admin_sistema')",
                        "sesiones_cliente.plataforma", "enum('mobile','web_restaurante')",
                        "sesiones_empleado.plataforma", "enum('web_admin','web_moderacion')",
                        "comentarios.contenido", "varchar(200)"));
            }
            try (ResultSet requestedRole = statement.executeQuery(
                    "SELECT requested_role FROM account_identity_registry "
                            + "WHERE identity_type = 'client' "
                            + "AND identity_id = 'f32c0000-0000-4000-8000-000000000001'")) {
                assertThat(requestedRole.next()).isTrue();
                assertThat(requestedRole.getString(1)).isEqualTo("restaurant_admin");
            }
            try (ResultSet history = statement.executeQuery(
                    "SELECT COUNT(*), SUM(success) FROM flyway_schema_history WHERE version IS NOT NULL")) {
                history.next();
                assertThat(history.getInt(1)).isEqualTo(6);
                assertThat(history.getInt(2)).isEqualTo(6);
            }
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
}
