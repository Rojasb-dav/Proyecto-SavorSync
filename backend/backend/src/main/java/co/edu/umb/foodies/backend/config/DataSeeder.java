package co.edu.umb.foodies.backend.config;

import co.edu.umb.foodies.backend.model.User;
import co.edu.umb.foodies.backend.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.CommandLineRunner;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

@Component
@RequiredArgsConstructor
public class DataSeeder implements CommandLineRunner {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;

    @Value("${app.seed.moderator-password:Moderador2025!}")
    private String moderatorPassword;

    @Override
    @Transactional
    public void run(String... args) {
        if (!userRepository.existsByEmail("moderador@savorsync.com")) {
            User moderador = User.builder()
                    .email("moderador@savorsync.com")
                    .username("moderador_pqrs")
                    .fullName("Moderador Oficial SavorSync")
                    .password(passwordEncoder.encode(moderatorPassword))
                    .role(User.Role.moderador)
                    .bio("Moderador Oficial de la Plataforma, Administración de Usuarios y PQRS")
                    .isActive(true)
                    .emailVerified(true)
                    .build();

            userRepository.save(moderador);
            System.out.println("SEEDER: Usuario Moderador inicializado de forma segura.");
        }
    }
}
