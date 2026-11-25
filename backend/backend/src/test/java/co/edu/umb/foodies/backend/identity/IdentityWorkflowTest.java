package co.edu.umb.foodies.backend.identity;

import co.edu.umb.foodies.backend.model.Pqrs;
import co.edu.umb.foodies.backend.model.User;
import co.edu.umb.foodies.backend.controller.PqrsController;
import co.edu.umb.foodies.backend.repository.AuthSessionRepository;
import co.edu.umb.foodies.backend.repository.PqrsRepository;
import co.edu.umb.foodies.backend.repository.UserRepository;
import co.edu.umb.foodies.backend.service.identity.EmailVerificationService;
import co.edu.umb.foodies.backend.service.identity.IdentityService;
import org.junit.jupiter.api.Test;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

class IdentityWorkflowTest {
    @Test
    void verifiedFoodieCanCreateOnePendingRestaurantRequest() {
        User user = foodie();
        var users = mock(UserRepository.class);
        var pqrs = mock(PqrsRepository.class);
        var sessions = mock(AuthSessionRepository.class);
        var verification = mock(EmailVerificationService.class);
        when(users.findByIdForUpdate(user.getId())).thenReturn(Optional.of(user));
        when(pqrs.findFirstByClienteIdAndAsuntoAndEstadoIn(
                eq(user.getId()), eq(IdentityService.RESTAURANT_REQUEST_SUBJECT), any()))
                .thenReturn(Optional.empty());
        when(pqrs.save(any(Pqrs.class))).thenAnswer(invocation -> invocation.getArgument(0));

        var service = new IdentityService(users, pqrs, sessions, verification);
        Pqrs created = service.requestRestaurantAdmin(user.getId(), "signed-code", "Request details");

        assertEquals(user.getId(), created.getClienteId());
        assertEquals(IdentityService.RESTAURANT_REQUEST_SUBJECT, created.getAsunto());
        assertEquals(Pqrs.PqrsStatus.recibida, created.getEstado());
        assertEquals("Request details", created.getDescripcion());
        assertTrue(user.getEmailVerified());
        verify(verification).requireProof(user, "signed-code");
        verify(pqrs).save(any(Pqrs.class));
    }

    @Test
    void restaurantRequestApprovalChangesRoleAndRevokesOldSessions() {
        User user = foodie();
        user.setEmailVerified(true);
        Pqrs request = Pqrs.builder()
                .id("request-id")
                .clienteId(user.getId())
                .tipo(Pqrs.PqrsType.peticion)
                .asunto(IdentityService.RESTAURANT_REQUEST_SUBJECT)
                .descripcion("Request")
                .estado(Pqrs.PqrsStatus.recibida)
                .build();
        var users = mock(UserRepository.class);
        var pqrs = mock(PqrsRepository.class);
        var sessions = mock(AuthSessionRepository.class);
        var verification = mock(EmailVerificationService.class);
        when(pqrs.findByIdForUpdate("request-id")).thenReturn(Optional.of(request));
        when(users.findByIdForUpdate(user.getId())).thenReturn(Optional.of(user));

        var result = new IdentityService(users, pqrs, sessions, verification)
                .approveRestaurantAdmin("request-id");

        assertEquals("restaurant_admin", result.getRole());
        assertEquals(Pqrs.PqrsStatus.resuelta, request.getEstado());
        assertNotNull(request.getFechaCierre());
        verify(sessions).revokeAllByUserId(user.getId());
    }

    @Test
    void restaurantRequestCannotBeApprovedForInactiveOrAlreadyPromotedAccount() {
        User user = foodie();
        user.setRole(User.Role.moderador);
        Pqrs request = Pqrs.builder()
                .id("request-id")
                .clienteId(user.getId())
                .tipo(Pqrs.PqrsType.peticion)
                .asunto(IdentityService.RESTAURANT_REQUEST_SUBJECT)
                .descripcion("Request")
                .estado(Pqrs.PqrsStatus.recibida)
                .build();
        var users = mock(UserRepository.class);
        var pqrs = mock(PqrsRepository.class);
        var sessions = mock(AuthSessionRepository.class);
        var verification = mock(EmailVerificationService.class);
        when(pqrs.findByIdForUpdate("request-id")).thenReturn(Optional.of(request));
        when(users.findByIdForUpdate(user.getId())).thenReturn(Optional.of(user));

        assertThrows(ResponseStatusException.class,
                () -> new IdentityService(users, pqrs, sessions, verification)
                        .approveRestaurantAdmin("request-id"));
        verify(sessions, never()).revokeAllByUserId(any());
    }

    @Test
    void genericPqrsUpdateCannotCloseRestaurantRoleRequest() {
        Pqrs request = Pqrs.builder()
                .id("request-id")
                .clienteId("user-id")
                .tipo(Pqrs.PqrsType.peticion)
                .asunto(IdentityService.RESTAURANT_REQUEST_SUBJECT)
                .descripcion("Request")
                .estado(Pqrs.PqrsStatus.recibida)
                .build();
        var pqrs = mock(PqrsRepository.class);
        when(pqrs.findByIdForUpdate("request-id")).thenReturn(Optional.of(request));

        var controller = new PqrsController(pqrs);
        assertThrows(ResponseStatusException.class,
                () -> controller.updatePqrsStatus("request-id",
                        Pqrs.builder().estado(Pqrs.PqrsStatus.resuelta).build()));
        assertEquals(Pqrs.PqrsStatus.recibida, request.getEstado());
    }

    private static User foodie() {
        return User.builder()
                .id("user-id")
                .email("foodie@example.test")
                .username("foodie")
                .password("hash")
                .fullName("Foodie")
                .role(User.Role.foodie)
                .isActive(true)
                .emailVerified(false)
                .build();
    }
}