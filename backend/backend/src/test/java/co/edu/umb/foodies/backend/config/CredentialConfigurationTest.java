package co.edu.umb.foodies.backend.config;

import co.edu.umb.foodies.backend.repository.UserRepository;
import co.edu.umb.foodies.backend.repository.EmployeeRepository;
import co.edu.umb.foodies.backend.service.AccountIdentityRegistry;
import org.junit.jupiter.api.Test;
import org.springframework.boot.autoconfigure.AutoConfigurations;
import org.springframework.boot.autoconfigure.context.PropertyPlaceholderAutoConfiguration;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.io.IOException;
import java.util.Map;
import java.util.Properties;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verifyNoInteractions;

class CredentialConfigurationTest {

    private final UserRepository userRepository = mock(UserRepository.class);
    private final EmployeeRepository employeeRepository = mock(EmployeeRepository.class);
    private final AccountIdentityRegistry identities = mock(AccountIdentityRegistry.class);

    private final ApplicationContextRunner context = new ApplicationContextRunner()
            .withConfiguration(AutoConfigurations.of(PropertyPlaceholderAutoConfiguration.class))
            .withUserConfiguration(DataSeeder.class)
            .withBean(UserRepository.class, () -> userRepository)
            .withBean(EmployeeRepository.class, () -> employeeRepository)
            .withBean(AccountIdentityRegistry.class, () -> identities)
            .withBean(PasswordEncoder.class, () -> mock(PasswordEncoder.class));

    @Test
    void externalConfigurationHasNoCredentialDefaults() throws IOException {
        Properties properties = new Properties();
        try (var input = getClass().getResourceAsStream("/application.properties")) {
            assertThat(input).isNotNull();
            properties.load(input);
        }
        Map<String, String> variables = Map.of(
                "spring.datasource.url", "SPRING_DATASOURCE_URL",
                "spring.datasource.username", "SPRING_DATASOURCE_USERNAME",
                "spring.datasource.password", "SPRING_DATASOURCE_PASSWORD",
                "app.jwt.secret", "APP_JWT_SECRET",
                "cloudinary.cloud-name", "CLOUDINARY_CLOUD_NAME",
                "cloudinary.api-key", "CLOUDINARY_API_KEY",
                "cloudinary.api-secret", "CLOUDINARY_API_SECRET",
                "spring.mail.username", "SPRING_MAIL_USERNAME",
                "spring.mail.password", "SPRING_MAIL_PASSWORD"
        );
        variables.forEach((property, variable) ->
                assertThat(properties.getProperty(property))
                        .startsWith("${" + variable)
                        .endsWith("}"));

        Properties development = new Properties();
        try (var input = getClass().getResourceAsStream("/application-development.properties")) {
            assertThat(input).isNotNull();
            development.load(input);
        }
        assertThat(development.getProperty("app.seed.moderator-enabled"))
                .isEqualTo("${APP_SEED_MODERATOR_ENABLED:false}");
        assertThat(development.getProperty("app.seed.moderator-password"))
                .isEqualTo("${APP_SEED_MODERATOR_PASSWORD:}");
        assertThat(properties.getProperty("app.cors.allowed-origins"))
                .isEqualTo("${APP_CORS_ALLOWED_ORIGINS:http://localhost:8080,http://127.0.0.1:8080}");
    }

    @Test
    void developmentDoesNotSeedByDefault() {
        context.withPropertyValues("spring.profiles.active=development")
                .run(application -> assertThat(application).doesNotHaveBean(DataSeeder.class));
        verifyNoInteractions(userRepository);
    }

    @Test
    void productionIgnoresSeederOptIn() {
        context.withPropertyValues(
                "spring.profiles.active=production,development",
                "app.seed.moderator-enabled=true"
        ).run(application -> assertThat(application).doesNotHaveBean(DataSeeder.class));
        verifyNoInteractions(userRepository, employeeRepository, identities);
    }

    @Test
    void developmentSeederRejectsEmptyPasswordBeforeAccessingDatabase() {
        context.withPropertyValues(
                "spring.profiles.active=development",
                "app.seed.moderator-enabled=true"
        ).run(application -> {
            assertThat(application).hasSingleBean(DataSeeder.class);
            assertThatThrownBy(
                    () -> application.getBean(DataSeeder.class).run()
            ).isInstanceOf(IllegalStateException.class);
        });
        verifyNoInteractions(userRepository, employeeRepository, identities);
    }
}
