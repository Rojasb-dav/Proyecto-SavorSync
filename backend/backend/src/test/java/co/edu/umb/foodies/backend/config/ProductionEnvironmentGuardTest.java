package co.edu.umb.foodies.backend.config;

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.atomic.AtomicInteger;

import com.zaxxer.hikari.HikariConfig;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.WebApplicationType;
import org.springframework.boot.context.properties.bind.Bindable;
import org.springframework.boot.context.properties.bind.Binder;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.env.MapPropertySource;
import org.springframework.core.env.StandardEnvironment;
import org.springframework.core.env.SystemEnvironmentPropertySource;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class ProductionEnvironmentGuardTest {

    private static final String CONFIG_LOCATION = "--spring.config.location=classpath:/";
    private static final String URL = "jdbc:mysql://fixture.test:3306/savorsync_v34_validation";
    private static final String REJECTION = "La configuración externa de Spring no se admite en producción.";
    private static final String FIXTURE_SECRET = "fixture-must-not-appear";
    private final AtomicInteger contextInitializations = new AtomicInteger();

    @Test
    void managedProductionBindsTheActualHikariAndSchemaSettings() {
        var application = application(managedVariables(), Map.of());
        application.setAdditionalProfiles("bootstrap-admin");
        try (var context = application.run(CONFIG_LOCATION, "--spring.datasource.url=" + URL,
                "--spring.datasource.hikari.jdbc-url=" + URL, "--spring.jpa.hibernate.ddl-auto=validate",
                "--spring.flyway.enabled=false", "--savorsync-bootstrap-admin")) {
            var environment = context.getEnvironment();
            var hikari = new HikariConfig();
            Binder.get(environment).bind("spring.datasource.hikari", Bindable.ofInstance(hikari));
            assertThat(hikari.getJdbcUrl()).isEqualTo(URL);
            assertThat(hikari.getDataSourceProperties())
                    .containsEntry("sslMode", "VERIFY_IDENTITY")
                    .containsEntry("fallbackToSystemTrustStore", "false")
                    .containsEntry("trustCertificateKeyStoreType", "PKCS12")
                    .containsEntry("trustCertificateKeyStoreUrl", "file:/tmp/fixture/mysql.p12")
                    .containsEntry("trustCertificateKeyStorePassword", FIXTURE_SECRET);
            assertThat(environment.getProperty("spring.jpa.hibernate.ddl-auto")).isEqualTo("validate");
            assertThat(environment.getProperty("spring.flyway.enabled", Boolean.class)).isFalse();
            assertThat(environment.getActiveProfiles()).containsExactlyInAnyOrder("production", "bootstrap-admin");
        }
    }

    @ParameterizedTest
    @ValueSource(strings = {"SPRING_DATASOURCE_HIKARI_JDBC_URL",
            "SPRING_DATASOURCE_HIKARI_DATA_SOURCE_PROPERTIES_SSLMODE",
            "spring.datasource.hikari.dataSourceProperties.fallbackToSystemTrustStore",
            "spring.datasource.hikari.data-source-properties.trustCertificateKeyStoreUrl",
            "SPRING_DATASOURCE_HIKARI_DATA_SOURCE_PROPERTIES_TRUSTCERTIFICATEKEYSTORETYPE",
            "SPRING_FLYWAY_ENABLED", "SPRING_JPA_HIBERNATE_DDLAUTO",
            "SPRING_CONFIG_ADDITIONALLOCATION", "SPRING_PROFILES_INCLUDE",
            "SPRING_PROFILES_GROUP_FIXTURE", "SPRING_APPLICATION_JSON"})
    void rejectsExternalSpringVariablesBeforeContextInitialization(String variable) {
        var variables = managedVariables();
        variables.put(variable, FIXTURE_SECRET);
        rejects(application(variables, Map.of()), CONFIG_LOCATION);
    }

    @ParameterizedTest
    @ValueSource(strings = {"spring.datasource.hikari.jdbcUrl",
            "spring.datasource.hikari.data-source-properties.sslMode",
            "spring.jpa.hibernate.ddlAuto", "spring.flyway.enabled", "spring.config.additional-location"})
    void rejectsJvmPropertyAliasesBeforeContextInitialization(String name) {
        rejects(application(managedVariables(), Map.of(name, FIXTURE_SECRET)), CONFIG_LOCATION);
    }

    @Test
    void rejectsProductionActivatedFromCommandLineAndJson() {
        rejects(application(Map.of(), Map.of()), "--spring.profiles.active=production");
        rejects(application(Map.of("SPRING_APPLICATION_JSON",
                "{\"spring\":{\"profiles\":{\"active\":\"production\"}}}"), Map.of()));
    }

    @ParameterizedTest
    @ValueSource(strings = {"spring.profiles.include=production", "spring.profiles.default=production",
            "spring.profiles.active=fixture\nspring.profiles.group.fixture=production"})
    void rejectsProductionActivatedThroughExternalConfig(String configuration, @TempDir Path directory)
            throws Exception {
        var file = Files.writeString(directory.resolve("activation.properties"), configuration);
        rejects(application(Map.of(), Map.of()), "--spring.config.location=" + file.toUri());
    }

    @Test
    void ordinaryDevelopmentAndTestProfilesRemainAvailable() {
        try (var context = application(Map.of("SPRING_PROFILES_ACTIVE", "development,test"), Map.of()).run()) {
            assertThat(context.getEnvironment().getActiveProfiles()).containsExactly("development", "test");
        }
    }

    private void rejects(SpringApplication application, String... arguments) {
        assertThatThrownBy(() -> application.run(arguments)).isInstanceOf(IllegalStateException.class)
                .hasMessage(REJECTION).hasMessageNotContaining(FIXTURE_SECRET);
        assertThat(contextInitializations).hasValue(0);
    }

    private SpringApplication application(Map<String, Object> variables, Map<String, Object> properties) {
        var environment = new StandardEnvironment();
        environment.getPropertySources().replace(StandardEnvironment.SYSTEM_ENVIRONMENT_PROPERTY_SOURCE_NAME,
                new SystemEnvironmentPropertySource(StandardEnvironment.SYSTEM_ENVIRONMENT_PROPERTY_SOURCE_NAME, variables));
        environment.getPropertySources().replace(StandardEnvironment.SYSTEM_PROPERTIES_PROPERTY_SOURCE_NAME,
                new MapPropertySource(StandardEnvironment.SYSTEM_PROPERTIES_PROPERTY_SOURCE_NAME, properties));
        var application = new SpringApplication(EmptyConfiguration.class);
        application.setEnvironment(environment);
        application.setWebApplicationType(WebApplicationType.NONE);
        application.setRegisterShutdownHook(false);
        application.addInitializers(context -> contextInitializations.incrementAndGet());
        return application;
    }

    private static Map<String, Object> managedVariables() {
        return new HashMap<>(Map.of("SAVORSYNC_PRODUCTION_ENTRYPOINT", "true",
                "SPRING_PROFILES_ACTIVE", "production", "SPRING_DATASOURCE_URL", URL,
                "MYSQL_TRUSTSTORE_URL", "file:/tmp/fixture/mysql.p12",
                "MYSQL_TRUSTSTORE_PASSWORD", FIXTURE_SECRET));
    }

    @Configuration(proxyBeanMethods = false)
    static class EmptyConfiguration {
    }
}
