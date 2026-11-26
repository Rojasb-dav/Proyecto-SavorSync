package co.edu.umb.foodies.backend.config;

import co.edu.umb.foodies.backend.model.Employee;
import co.edu.umb.foodies.backend.repository.EmployeeRepository;
import co.edu.umb.foodies.backend.service.AccountIdentityRegistry;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Profile;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

@Component
@Profile("development & !production & !bootstrap-admin")
@ConditionalOnProperty(
        name = "app.seed.moderator-enabled",
        havingValue = "true",
        matchIfMissing = false
)
public class DataSeeder implements CommandLineRunner {

    private final EmployeeRepository employeeRepository;
    private final AccountIdentityRegistry identities;
    private final PasswordEncoder passwordEncoder;
    private final String moderatorPassword;

    public DataSeeder(EmployeeRepository employeeRepository,
                      AccountIdentityRegistry identities,
                      PasswordEncoder passwordEncoder,
                      @Value("${app.seed.moderator-password:}") String moderatorPassword) {
        this.employeeRepository = employeeRepository;
        this.identities = identities;
        this.passwordEncoder = passwordEncoder;
        this.moderatorPassword = moderatorPassword;
    }

    @Override
    @Transactional
    public void run(String... args) {
        if (moderatorPassword == null || moderatorPassword.isBlank()
                || moderatorPassword.contains("${")) {
            throw new IllegalStateException(
                    "DataSeeder está activado, pero APP_SEED_MODERATOR_PASSWORD no está configurada."
            );
        }

        if (employeeRepository.existsByEmail("moderador@savorsync.com")) return;

        String id = UUID.randomUUID().toString();
        identities.register("employee", id, "moderador@savorsync.com", "moderador_pqrs");
        Employee moderator = Employee.builder()
                .id(id)
                .email("moderador@savorsync.com")
                .username("moderador_pqrs")
                .fullName("Moderador Oficial SavorSync")
                .password(passwordEncoder.encode(moderatorPassword))
                .role(Employee.Role.moderador)
                .isActive(true)
                .emailVerified(false)
                .build();
        employeeRepository.saveAndFlush(moderator);
    }
}
