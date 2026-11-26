package co.edu.umb.foodies.backend;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

// Authentication uses only the explicitly configured JWT filter chain.
@SpringBootApplication(exclude = org.springframework.boot.autoconfigure.security.servlet.UserDetailsServiceAutoConfiguration.class)
public class BackendApplication {

    public static void main(String[] args) {
        if (!java.util.List.of(args).contains("--savorsync-bootstrap-admin")) {
            SpringApplication.run(BackendApplication.class, args);
            return;
        }
        if (!"true".equals(System.getenv("APP_BOOTSTRAP_ADMIN_ENABLED"))) {
            throw new IllegalStateException("Aprovisionamiento administrativo desactivado.");
        }
        var app = new SpringApplication(BackendApplication.class);
        app.setAdditionalProfiles("bootstrap-admin");
        app.setWebApplicationType(org.springframework.boot.WebApplicationType.NONE);
        app.addInitializers(context -> {
            if (context instanceof org.springframework.boot.web.context.WebServerApplicationContext) {
                throw new IllegalStateException("El aprovisionamiento requiere un proceso sin servidor web.");
            }
        });
        try (var context = app.run(args)) {
            // Closing the context terminates this administrative process.
        }
    }

}
