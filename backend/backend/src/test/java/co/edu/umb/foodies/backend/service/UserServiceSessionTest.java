package co.edu.umb.foodies.backend.service;

import co.edu.umb.foodies.backend.dto.response.UserResponse;
import co.edu.umb.foodies.backend.model.User;
import co.edu.umb.foodies.backend.repository.AuthSessionRepository;
import co.edu.umb.foodies.backend.repository.NotificationRepository;
import co.edu.umb.foodies.backend.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class UserServiceSessionTest {

    @Mock private UserRepository users;
    @Mock private NotificationRepository notifications;
    @Mock private AuthSessionRepository sessions;

    private UserService service;
    private User user;

    @BeforeEach
    void setUp() {
        service = new UserService(users, notifications, sessions);
        user = User.builder()
                .id(UUID.randomUUID().toString())
                .role(User.Role.foodie)
                .build();
        when(users.findByIdForUpdate(user.getId())).thenReturn(Optional.of(user));
        when(users.save(user)).thenReturn(user);
    }

    @Test
    void suspendingAccountRevokesAllItsSessions() {
        user.setIsActive(true);

        UserResponse response = service.toggleUserStatus(user.getId());

        assertThat(response.getIsActive()).isFalse();
        verify(users).save(user);
        verify(sessions).revokeAllByUserId(user.getId());
    }

    @Test
    void reactivatingAccountDoesNotRestoreOldSessions() {
        user.setIsActive(false);

        UserResponse response = service.toggleUserStatus(user.getId());

        assertThat(response.getIsActive()).isTrue();
        verify(users).save(user);
        verifyNoInteractions(sessions);
    }
}
