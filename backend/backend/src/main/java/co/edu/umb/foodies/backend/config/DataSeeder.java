package co.edu.umb.foodies.backend.config;

import co.edu.umb.foodies.backend.model.User;
import co.edu.umb.foodies.backend.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.boot.CommandLineRunner;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

@Component
@RequiredArgsConstructor
public class DataSeeder implements CommandLineRunner {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;

    @Override
    @Transactional
    public void run(String... args) {
        // Crear usuario Moderador por defecto para atención de PQRS y Gobierno si no existe
        if (!userRepository.existsByEmail("moderador@savorsync.com")) {
            User moderador = User.builder()
                    .email("moderador@savorsync.com")
                    .username("moderador_pqrs")
                    .fullName("Moderador Oficial SavorSync")
                    .password(passwordEncoder.encode("Moderador2025!"))
                    .role(User.Role.moderador)
                    .bio("Moderador Oficial de la Plataforma, Administración de Usuarios y PQRS")
                    .isActive(true)
                    .emailVerified(true)
                    .build();

            userRepository.save(moderador);
            System.out.println("SEEDER: Usuario Moderador verificado en la base de datos (moderador@savorsync.com).");
        }
    }
}
