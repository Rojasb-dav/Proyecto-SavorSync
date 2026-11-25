package co.edu.umb.foodies.backend.config;

import co.edu.umb.foodies.backend.model.Employee;
import co.edu.umb.foodies.backend.repository.EmployeeRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.CommandLineRunner;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

@Component
@RequiredArgsConstructor
public class DataSeeder implements CommandLineRunner {

    private final EmployeeRepository employeeRepository;
    private final PasswordEncoder passwordEncoder;

    @Value("${app.seed.moderator-password:Moderador2025!}")
    private String moderatorPassword;

    @Override
    @Transactional
    public void run(String... args) {
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
