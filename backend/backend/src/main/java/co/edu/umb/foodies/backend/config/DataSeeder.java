package co.edu.umb.foodies.backend.config;

import co.edu.umb.foodies.backend.model.Employee;
import co.edu.umb.foodies.backend.repository.EmployeeRepository;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.autoconfigure.condition.ConditionalOnExpression;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Profile;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

@Component
@Profile("!production")
@ConditionalOnProperty(name="app.seed.moderator-enabled", havingValue="true")
public class DataSeeder implements CommandLineRunner {

    private final EmployeeRepository employeeRepository;
    private final PasswordEncoder passwordEncoder;
    private final String moderatorPassword;

    public DataSeeder(EmployeeRepository employeeRepository,
                      PasswordEncoder passwordEncoder,
                      @Value("${app.seed.moderator-password:#{null}}") String moderatorPassword) {
        this.employeeRepository = employeeRepository;
        this.passwordEncoder = passwordEncoder;
        this.moderatorPassword = moderatorPassword;
    }

    @Override
    @Transactional
    public void run(String... args) {
        if (moderatorPassword == null || moderatorPassword.trim().isEmpty() || moderatorPassword.contains("${")) {
            throw new IllegalStateException("Se ha activado el DataSeeder, pero app.seed.moderator-password está vacía.");
        }

        if (!employeeRepository.existsByEmail("moderador@savorsync.com")) {
            Employee moderador = Employee.builder()
                    .email("moderador@savorsync.com")
                    .username("moderador_pqrs")
                    .fullName("Moderador Oficial SavorSync")
                    .password(passwordEncoder.encode(moderatorPassword))
                    .role(Employee.Role.moderador)
                    .isActive(true)
                    .build();

            employeeRepository.save(moderador);
            System.out.println("SEEDER: Usuario Moderador inicializado de forma segura.");
        }
    }
}
