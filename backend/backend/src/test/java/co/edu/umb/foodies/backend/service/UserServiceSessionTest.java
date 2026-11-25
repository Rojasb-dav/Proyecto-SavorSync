package co.edu.umb.foodies.backend.service;

import co.edu.umb.foodies.backend.model.ClientSession;
import co.edu.umb.foodies.backend.model.User;
import co.edu.umb.foodies.backend.repository.ClientSessionRepository;
import co.edu.umb.foodies.backend.repository.NotificationRepository;
import co.edu.umb.foodies.backend.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class UserServiceSessionTest {

    @Mock private UserRepository users;
    @Mock private NotificationRepository notificationRepository;
    @Mock private ClientSessionRepository clientSessionRepository;

    private UserService service;
    private User target;

    @BeforeEach
    void setUp() {
        service = new UserService(users, notificationRepository, clientSessionRepository);
        target = User.builder()
                .id(UUID.randomUUID().toString())
                .role(User.Role.foodie)
                .isActive(true)
                .build();
    }

    @Test
    void suspendingUserRevokesAllSessions() {
        when(users.findByIdForUpdate(target.getId())).thenReturn(Optional.of(target));
        when(users.save(target)).thenReturn(target);

        ClientSession s1 = ClientSession.builder().userId(target.getId()).isActive(true).build();
        ClientSession s2 = ClientSession.builder().userId(target.getId()).isActive(false).build();
        ClientSession s3 = ClientSession.builder().userId("otro").isActive(true).build();

        when(clientSessionRepository.findAll()).thenReturn(List.of(s1, s2, s3));

        service.toggleUserStatus(target.getId());

        assertThat(target.getIsActive()).isFalse();
        assertThat(s1.getIsActive()).isFalse();
        verify(clientSessionRepository).save(s1);
    }
}