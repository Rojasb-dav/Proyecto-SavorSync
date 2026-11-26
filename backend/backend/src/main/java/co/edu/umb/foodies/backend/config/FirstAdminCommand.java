package co.edu.umb.foodies.backend.config;

import co.edu.umb.foodies.backend.service.FirstAdminProvisioning;
import lombok.RequiredArgsConstructor;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.boot.autoconfigure.condition.ConditionalOnNotWebApplication;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;

import javax.sql.DataSource;
import java.util.Arrays;

@Component
@Profile("bootstrap-admin & !development")
@ConditionalOnNotWebApplication
@ConditionalOnProperty(name = "app.bootstrap.admin-enabled", havingValue = "true")
@RequiredArgsConstructor
public class FirstAdminCommand implements ApplicationRunner {
    private final DataSource dataSource;
    private final FirstAdminProvisioning provisioning;

    @Override
    public void run(ApplicationArguments args) throws Exception {
        if (!args.containsOption("savorsync-bootstrap-admin")) {
            throw new IllegalStateException("La creación administrativa requiere la orden explícita.");
        }
        var console = System.console();
        if (console == null) throw new IllegalStateException("Se requiere una consola interactiva.");
        String email = console.readLine("Correo: ");
        String username = console.readLine("Usuario: ");
        String fullName = console.readLine("Nombre completo: ");
        char[] password = console.readPassword("Contraseña: ");
        char[] confirmation = console.readPassword("Confirme la contraseña: ");
        try {
            if (password == null || !Arrays.equals(password, confirmation)) {
                throw new IllegalArgumentException("Las contraseñas no coinciden.");
            }
            try (var connection = dataSource.getConnection(); var statement = connection.createStatement()) {
                try (var lock = statement.executeQuery("SELECT GET_LOCK(SHA2(DATABASE(), 256), 0)")) {
                    if (!lock.next() || lock.getInt(1) != 1) {
                        throw new IllegalStateException("Otra operación de aprovisionamiento está en curso.");
                    }
                }
                try {
                    provisioning.create(new FirstAdminProvisioning.Identity(email, username, fullName), password);
                } finally {
                    statement.execute("DO RELEASE_LOCK(SHA2(DATABASE(), 256))");
                }
            }
            console.printf("Cuenta creada. Verifique su correo desde el inicio de sesión.%n");
        } finally {
            if (password != null) Arrays.fill(password, '\0');
            if (confirmation != null) Arrays.fill(confirmation, '\0');
        }
    }
}
