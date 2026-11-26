package co.edu.umb.foodies.backend;

import org.flywaydb.core.Flyway;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.Statement;
import java.sql.SQLException;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

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

    @ParameterizedTest
    @ValueSource(ints = {3307, 3308})
    @EnabledIfEnvironmentVariable(named = "SAVORSYNC_V35B_DML_TEST", matches = "true")
    void enforcesMigratedConstraintsForDmlOnlyAccounts(int port) throws Exception {
        String suffix = UUID.randomUUID().toString().substring(0, 8);
        String schema = "v35b_integrity_" + suffix;
        String user = "v35b_dml_" + suffix;
        String password = required("SAVORSYNC_SESSION_MYSQL_PASSWORD");
        String rootPassword = required("SAVORSYNC_SESSION_MYSQL_ROOT_PASSWORD");
        String server = "jdbc:mysql://127.0.0.1:" + port + "/";
        String options = "?sslMode=DISABLED&allowPublicKeyRetrieval=true";
        String url = server + schema + options;

        try (Connection root = DriverManager.getConnection(server + "mysql" + options, "root", rootPassword);
             Statement sql = root.createStatement()) {
            assertThat(value(sql, "SELECT VERSION()")).startsWith(port == 3307 ? "8.0." : "8.4.");
            sql.execute("CREATE DATABASE " + schema + " CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci");
            sql.execute("CREATE USER '" + user + "'@'%' IDENTIFIED BY '" + escapeSqlLiteral(password) + "'");
            sql.execute("GRANT SELECT, INSERT, UPDATE, DELETE ON " + schema + ".* TO '" + user + "'@'%'");
        }
        Flyway flyway = Flyway.configure().dataSource(url, "root", rootPassword)
                .locations("classpath:db/migration").load();
        assertThat(flyway.migrate().migrationsExecuted).isEqualTo(6);
        flyway.validate();
        assertThat(flyway.info().pending()).isEmpty();

        try (Connection dml = DriverManager.getConnection(url, user, password);
             Statement sql = dml.createStatement()) {
            assertThat(value(sql, "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema=DATABASE()"))
                    .isEqualTo("27");
            assertThat(value(sql, """
                    SELECT COUNT(*) FROM information_schema.referential_constraints WHERE constraint_schema=DATABASE()
                    """)).isEqualTo("35");
            assertThatThrownBy(() -> sql.execute("CREATE TABLE forbidden_ddl (id INT)"))
                    .isInstanceOf(SQLException.class).hasMessageContaining("denied");
            dml.setAutoCommit(false);
            try {
                sql.executeUpdate("""
                        INSERT INTO clientes (email, username, password, full_name, rol) VALUES
                        ('owner@example.test', 'owner', 'fixture-only', 'Owner', 'restaurant_admin'),
                        ('foodie@example.test', 'foodie', 'fixture-only', 'Foodie', 'foodie')
                        """);
                String owner = value(sql, "SELECT id FROM clientes WHERE username='owner'");
                String foodie = value(sql, "SELECT id FROM clientes WHERE username='foodie'");
                assertThat(UUID.fromString(owner).toString()).isEqualTo(owner);
                assertThat(UUID.fromString(foodie).toString()).isEqualTo(foodie);

                String restaurant = "INSERT INTO restaurantes (owner_id,nombre,direccion,ciudad,categoria)"
                        + " VALUES ('%s','Fixture','Fixture','Fixture','Fixture')";
                sql.executeUpdate(restaurant.formatted(owner));
                String restaurantId = value(sql, "SELECT id FROM restaurantes WHERE owner_id='" + owner + "'");
                assertThat(UUID.fromString(restaurantId).toString()).isEqualTo(restaurantId);
                assertThatThrownBy(() -> sql.executeUpdate(restaurant.formatted(foodie)))
                        .isInstanceOf(SQLException.class).hasMessageContaining("Restaurant owner");
                String follow = "INSERT INTO seguidores (seguidor_id,seguido_id) VALUES ('%s','%s')";
                sql.executeUpdate(follow.formatted(foodie, owner));
                String followId = value(sql, "SELECT id FROM seguidores");
                assertThat(UUID.fromString(followId).toString()).isEqualTo(followId);
                assertThatThrownBy(() -> sql.executeUpdate(follow.formatted(foodie, foodie)))
                        .isInstanceOf(SQLException.class).hasMessageContaining("ck_follow_distinct_accounts");
                assertThatThrownBy(() -> sql.executeUpdate(follow.formatted(foodie, UUID.randomUUID())))
                        .isInstanceOf(SQLException.class).hasMessageContaining("foreign key constraint");
            } finally {
                dml.rollback();
            }
            for (String table : new String[]{"clientes", "restaurantes", "seguidores"}) {
                assertThat(value(sql, "SELECT COUNT(*) FROM " + table)).isEqualTo("0");
            }
        }
        try (Connection root = DriverManager.getConnection(url, "root", rootPassword);
             Statement sql = root.createStatement()) {
            assertThat(value(sql, "SELECT COUNT(*) FROM information_schema.triggers WHERE trigger_schema=DATABASE()"))
                    .isEqualTo("31");
        }
    }

    private static String value(Statement sql, String query) throws SQLException {
        try (ResultSet result = sql.executeQuery(query)) {
            assertThat(result.next()).isTrue();
            return result.getString(1);
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
