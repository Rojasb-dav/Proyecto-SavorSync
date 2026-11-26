package co.edu.umb.foodies.backend.service;

import co.edu.umb.foodies.backend.model.Employee;
import co.edu.umb.foodies.backend.repository.EmployeeRepository;
import jakarta.validation.Validation;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.http.HttpStatus;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

class FirstAdminProvisioningTest {
    @Test
    void createsAnUnverifiedAdminAndRefusesAnExistingAdminOrIdentityCollision() {
        var employees = mock(EmployeeRepository.class);
        var identities = mock(AccountIdentityRegistry.class);
        var encoder = new BCryptPasswordEncoder();
        var identity = new FirstAdminProvisioning.Identity("Admin@example.test", "admin.fixture", "Synthetic admin");
        var password = "synthetic-strong-password".toCharArray();
        try (var factory = Validation.buildDefaultValidatorFactory()) {
            var provisioning = new FirstAdminProvisioning(employees, identities, encoder, factory.getValidator());
            provisioning.create(identity, password);
            var saved = ArgumentCaptor.forClass(Employee.class);
            verify(employees).saveAndFlush(saved.capture());
            var admin = saved.getValue();
            assertThat(admin.getRole()).isEqualTo(Employee.Role.admin_sistema);
            assertThat(admin.getEmailVerified()).isFalse();
            assertThat(encoder.matches(java.nio.CharBuffer.wrap(password), admin.getPassword())).isTrue();
            verify(identities).register("employee", admin.getId(), "admin@example.test", "admin.fixture");
            when(employees.existsByRole(Employee.Role.admin_sistema)).thenReturn(true);
            assertThatThrownBy(() -> provisioning.create(identity, password))
                    .isInstanceOf(IllegalStateException.class);
            when(employees.existsByRole(Employee.Role.admin_sistema)).thenReturn(false);
            doThrow(new ResponseStatusException(HttpStatus.CONFLICT)).when(identities)
                    .register(eq("employee"), anyString(), eq("admin@example.test"), eq("admin.fixture"));
            assertThatThrownBy(() -> provisioning.create(identity, password))
                    .isInstanceOf(ResponseStatusException.class);
            verify(employees, times(1)).saveAndFlush(any());
        }
    }
}
