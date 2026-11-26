package co.edu.umb.foodies.backend.service;

import co.edu.umb.foodies.backend.model.Employee;
import co.edu.umb.foodies.backend.repository.EmployeeRepository;
import jakarta.validation.Validator;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.RequiredArgsConstructor;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.nio.CharBuffer;
import java.nio.charset.StandardCharsets;
import java.util.Locale;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class FirstAdminProvisioning {
    private final EmployeeRepository employees;
    private final AccountIdentityRegistry identities;
    private final PasswordEncoder passwords;
    private final Validator validator;

    public record Identity(@NotBlank @Email @Size(max = 191) String email,
                           @NotBlank @Pattern(regexp = "[a-zA-Z0-9_.-]{3,50}") String username,
                           @NotBlank @Size(max = 100) String fullName) {}

    @Transactional
    public void create(Identity identity, char[] password) {
        if (!validator.validate(identity).isEmpty()) {
            throw new IllegalArgumentException("Identidad administrativa inválida.");
        }
        if (password.length < 16 || StandardCharsets.UTF_8.encode(CharBuffer.wrap(password)).remaining() > 72
                || CharBuffer.wrap(password).chars().allMatch(Character::isWhitespace)) {
            throw new IllegalArgumentException("La contraseña debe tener al menos 16 caracteres y como máximo 72 bytes.");
        }
        if (employees.existsByRole(Employee.Role.admin_sistema)) {
            throw new IllegalStateException("Ya existe una cuenta admin_sistema.");
        }
        String id = UUID.randomUUID().toString();
        String email = identity.email().toLowerCase(Locale.ROOT);
        identities.register("employee", id, email, identity.username());
        employees.saveAndFlush(Employee.builder().id(id).email(email).username(identity.username())
                .fullName(identity.fullName()).password(passwords.encode(CharBuffer.wrap(password)))
                .role(Employee.Role.admin_sistema).isActive(true).emailVerified(false).build());
    }
}
