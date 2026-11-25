package co.edu.umb.foodies.backend.identity;

import co.edu.umb.foodies.backend.controller.PqrsController;
import co.edu.umb.foodies.backend.model.Pqrs;
import co.edu.umb.foodies.backend.model.User;
import co.edu.umb.foodies.backend.repository.ClientSessionRepository;
import co.edu.umb.foodies.backend.repository.NotificationRepository;
import co.edu.umb.foodies.backend.repository.PqrsRepository;
import co.edu.umb.foodies.backend.repository.UserRepository;
import co.edu.umb.foodies.backend.service.AccountIdentityRegistry;
import co.edu.umb.foodies.backend.service.IdentityService;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.web.server.ResponseStatusException;

import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;
import static org.mockito.Mockito.verifyNoInteractions;

class IdentityWorkflowTest {

    @Test
    void verifiedFoodieCanCreateOnePendingRestaurantRequest() {
        User user = foodie(true);
        UserRepository users = mock(UserRepository.class);
        PqrsRepository pqrs = mock(PqrsRepository.class);
        ClientSessionRepository sessions = mock(ClientSessionRepository.class);
        AccountIdentityRegistry identities = mock(AccountIdentityRegistry.class);
        when(identities.requestedRole("client", user.getId())).thenReturn("restaurant_admin");
        when(users.findByIdForUpdate(user.getId())).thenReturn(Optional.of(user));
        when(pqrs.findFirstByClienteIdAndAsuntoAndEstadoIn(
                eq(user.getId()), eq(IdentityService.RESTAURANT_REQUEST_SUBJECT), any()))
                .thenReturn(Optional.empty());
        when(pqrs.save(any(Pqrs.class))).thenAnswer(invocation -> invocation.getArgument(0));

        IdentityService service = new IdentityService(users, pqrs, sessions, identities);
        Pqrs created = service.requestRestaurantAdmin(user.getId(), "Request details");

        assertEquals(user.getId(), created.getClienteId());
        assertEquals(IdentityService.RESTAURANT_REQUEST_SUBJECT, created.getAsunto());
        assertEquals(Pqrs.PqrsStatus.recibida, created.getEstado());
        assertEquals("Request details", created.getDescripcion());
        assertEquals(User.Role.foodie, user.getRole());
        verify(pqrs).save(any(Pqrs.class));
    }

    @Test
    void unverifiedFoodieCannotRequestRestaurantAdminPrivileges() {
        User user = foodie(false);
        UserRepository users = mock(UserRepository.class);
        PqrsRepository pqrs = mock(PqrsRepository.class);
        when(users.findByIdForUpdate(user.getId())).thenReturn(Optional.of(user));

        assertThrows(ResponseStatusException.class,
                () -> new IdentityService(users, pqrs, mock(ClientSessionRepository.class),
                        mock(AccountIdentityRegistry.class))
                        .requestRestaurantAdmin(user.getId(), "Request details"));
        verifyNoInteractions(pqrs);
    }

    @Test
    void restaurantRequestApprovalChangesRoleAndRevokesOnlyOwnedSessions() {
        User user = foodie(true);
        Pqrs request = restaurantRequest(user.getId());
        UserRepository users = mock(UserRepository.class);
        PqrsRepository pqrs = mock(PqrsRepository.class);
        ClientSessionRepository sessions = mock(ClientSessionRepository.class);
        AccountIdentityRegistry identities = mock(AccountIdentityRegistry.class);
        when(identities.requestedRole("client", user.getId())).thenReturn("restaurant_admin");
        when(pqrs.findByIdForUpdate("request-id")).thenReturn(Optional.of(request));
        when(users.findByIdForUpdate(user.getId())).thenReturn(Optional.of(user));

        var result = new IdentityService(users, pqrs, sessions, identities).approveRestaurantAdmin("request-id");

        assertEquals("restaurant_admin", result.getRole());
        assertEquals(Pqrs.PqrsStatus.resuelta, request.getEstado());
        assertNotNull(request.getFechaCierre());
        verify(users).save(user);
        verify(sessions).revokeActiveByUserId(user.getId());
        verify(sessions, never()).findAll();
    }

    @Test
    void restaurantRequestCannotBeApprovedForAlreadyPromotedAccount() {
        User user = foodie(true);
        user.setRole(User.Role.restaurant_admin);
        UserRepository users = mock(UserRepository.class);
        PqrsRepository pqrs = mock(PqrsRepository.class);
        ClientSessionRepository sessions = mock(ClientSessionRepository.class);
        when(pqrs.findByIdForUpdate("request-id")).thenReturn(Optional.of(restaurantRequest(user.getId())));
        when(users.findByIdForUpdate(user.getId())).thenReturn(Optional.of(user));

        assertThrows(ResponseStatusException.class,
                () -> new IdentityService(users, pqrs, sessions,
                        mock(AccountIdentityRegistry.class)).approveRestaurantAdmin("request-id"));
        verify(sessions, never()).revokeActiveByUserId(any());
    }

    @Test
    void genericPqrsUpdateCannotCloseRestaurantRoleRequest() {
        PqrsRepository pqrs = mock(PqrsRepository.class);
        when(pqrs.findByIdForUpdate("request-id"))
                .thenReturn(Optional.of(restaurantRequest("user-id")));

        PqrsController controller = new PqrsController(pqrs, mock(NotificationRepository.class));
        assertThrows(ResponseStatusException.class,
                () -> controller.updatePqrsStatus("request-id",
                        Pqrs.builder().estado(Pqrs.PqrsStatus.resuelta).build(),
                        new MockHttpServletRequest()));
    }

    private static Pqrs restaurantRequest(String userId) {
        return Pqrs.builder()
                .id("request-id")
                .clienteId(userId)
                .tipo(Pqrs.PqrsType.peticion)
                .asunto(IdentityService.RESTAURANT_REQUEST_SUBJECT)
                .descripcion("Request")
                .estado(Pqrs.PqrsStatus.recibida)
                .build();
    }

    private static User foodie(boolean verified) {
        return User.builder()
                .id("user-id")
                .email("foodie@example.test")
                .username("foodie")
                .password("hash")
                .fullName("Foodie")
                .role(User.Role.foodie)
                .isActive(true)
                .emailVerified(verified)
                .build();
    }
}
