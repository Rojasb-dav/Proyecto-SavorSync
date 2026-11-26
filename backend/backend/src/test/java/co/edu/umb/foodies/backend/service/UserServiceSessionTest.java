package co.edu.umb.foodies.backend.service;

import co.edu.umb.foodies.backend.model.ClientSession;
import co.edu.umb.foodies.backend.model.User;
import co.edu.umb.foodies.backend.repository.ClientSessionRepository;
import co.edu.umb.foodies.backend.repository.NotificationRepository;
import co.edu.umb.foodies.backend.repository.FollowRepository;
import co.edu.umb.foodies.backend.repository.RestaurantRepository;
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
    @Mock private AccountIdentityRegistry identities;
    @Mock private CloudinaryAssetRegistry assetRegistry;
    @Mock private FollowRepository follows;
    @Mock private RestaurantRepository restaurants;

    private UserService service;
    private User target;

    @BeforeEach
    void setUp() {
        service = new UserService(users, notificationRepository, clientSessionRepository, identities, assetRegistry, follows, restaurants);
        target = User.builder()
                .id(UUID.randomUUID().toString())
                .role(User.Role.foodie)
                .isActive(true)
                .build();
    }

    @Test
    void suspendingUserRevokesOnlySessionsOwnedByThatUser() {
        when(users.findByIdForUpdate(target.getId())).thenReturn(Optional.of(target));
        when(users.save(target)).thenReturn(target);

        service.toggleUserStatus(target.getId());

        assertThat(target.getIsActive()).isFalse();
        verify(restaurants).suspendOwnedRestaurants(target.getId());
        verify(clientSessionRepository).revokeActiveByUserId(target.getId());
    }
}