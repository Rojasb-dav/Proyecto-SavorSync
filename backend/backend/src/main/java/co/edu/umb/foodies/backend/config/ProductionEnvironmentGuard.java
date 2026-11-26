package co.edu.umb.foodies.backend.config;

import java.util.Arrays;
import java.util.Locale;
import java.util.Set;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.env.EnvironmentPostProcessor;
import org.springframework.core.Ordered;
import org.springframework.core.env.ConfigurableEnvironment;
import org.springframework.core.env.EnumerablePropertySource;
import org.springframework.core.env.Profiles;
import org.springframework.core.env.StandardEnvironment;

/** Fail before auto-configuration can initialize Hikari, Hibernate or Flyway. */
public final class ProductionEnvironmentGuard implements EnvironmentPostProcessor, Ordered {

    private static final Set<String> ALLOWED_SPRING_ENVIRONMENT = Set.of(
            "SPRING_PROFILES_ACTIVE", "SPRING_DATASOURCE_URL",
            "SPRING_DATASOURCE_USERNAME", "SPRING_DATASOURCE_PASSWORD");

    @Override
    public int getOrder() {
        // Check the profiles after ConfigData resolves include, groups and default profiles.
        return Ordered.LOWEST_PRECEDENCE;
    }

    @Override
    public void postProcessEnvironment(ConfigurableEnvironment environment, SpringApplication application) {
        var sources = environment.getPropertySources();
        var container = sources.get(StandardEnvironment.SYSTEM_ENVIRONMENT_PROPERTY_SOURCE_NAME);
        boolean managed = container != null && "true".equals(container.getProperty("SAVORSYNC_PRODUCTION_ENTRYPOINT"));
        boolean production = environment.acceptsProfiles(Profiles.of("production"));
        if (!managed && !production) {
            return;
        }
        if (!managed || !production || !"classpath:/".equals(environment.getProperty("spring.config.location"))
                || Arrays.stream(environment.getActiveProfiles())
                        .anyMatch(profile -> !Set.of("production", "bootstrap-admin").contains(profile))) {
            throw rejected();
        }
    }

    /** Reject overrides before Boot processes JSON or imports configuration data. */
    public static final class BeforeConfig implements EnvironmentPostProcessor, Ordered {
        @Override
        public int getOrder() {
            return Ordered.HIGHEST_PRECEDENCE;
        }

        @Override
        public void postProcessEnvironment(ConfigurableEnvironment environment, SpringApplication application) {
            var container = environment.getPropertySources()
                    .get(StandardEnvironment.SYSTEM_ENVIRONMENT_PROPERTY_SOURCE_NAME);
            if (container != null && "true".equals(container.getProperty("SAVORSYNC_PRODUCTION_ENTRYPOINT"))) {
                checkExternalSources(environment);
            }
        }
    }

    private static void checkExternalSources(ConfigurableEnvironment environment) {
        var sources = environment.getPropertySources();
        var container = sources.get(StandardEnvironment.SYSTEM_ENVIRONMENT_PROPERTY_SOURCE_NAME);
        if (container instanceof EnumerablePropertySource<?> variables) {
            for (String name : variables.getPropertyNames()) {
                String canonical = canonicalName(name);
                if ((canonical.startsWith("spring") && !ALLOWED_SPRING_ENVIRONMENT.contains(name))
                        || canonical.startsWith("logging") || canonical.equals("debug") || canonical.equals("trace")
                        || canonical.startsWith("hibernate") || canonical.startsWith("flyway")
                        || canonical.startsWith("javatooloptions") || canonical.startsWith("javaoptions")
                        || canonical.startsWith("jdkjavaoptions")) {
                    throw rejected();
                }
            }
        }
        var system = sources.get(StandardEnvironment.SYSTEM_PROPERTIES_PROPERTY_SOURCE_NAME);
        if (system instanceof EnumerablePropertySource<?> properties) {
            for (String name : properties.getPropertyNames()) {
                String canonical = canonicalName(name);
                if (canonical.startsWith("spring") || canonical.startsWith("hibernate")
                        || canonical.startsWith("flyway") || canonical.startsWith("logging")
                        || canonical.equals("debug") || canonical.equals("trace")) {
                    throw rejected();
                }
            }
        }
    }

    private static String canonicalName(String name) {
        return name.toLowerCase(Locale.ROOT).replaceAll("[^a-z0-9]", "");
    }

    private static IllegalStateException rejected() {
        // Never include property values, injected JSON, URLs or credential material.
        return new IllegalStateException("La configuración externa de Spring no se admite en producción.");
    }
}
