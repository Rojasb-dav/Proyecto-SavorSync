package co.edu.umb.foodies.backend.service;

import co.edu.umb.foodies.backend.dto.response.UserResponse;
import co.edu.umb.foodies.backend.model.Pqrs;
import co.edu.umb.foodies.backend.model.User;
import co.edu.umb.foodies.backend.repository.ClientSessionRepository;
import co.edu.umb.foodies.backend.repository.PqrsRepository;
import co.edu.umb.foodies.backend.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.time.LocalDateTime;
import java.util.List;

@Service
@RequiredArgsConstructor
public class IdentityService {
    public static final String RESTAURANT_REQUEST_SUBJECT = "Solicitud de administración de restaurante";
    private static final List<Pqrs.PqrsStatus> OPEN_STATES = List.of(
            Pqrs.PqrsStatus.recibida, Pqrs.PqrsStatus.en_gestion);

    private final UserRepository users;
    private final PqrsRepository pqrs;
    private final ClientSessionRepository sessions;
    private final AccountIdentityRegistry identities;

    @Transactional
    public Pqrs requestRestaurantAdmin(String userId, String description) {
        User user = activeUserForUpdate(userId);
        requireFoodie(user);
        if (!Boolean.TRUE.equals(user.getEmailVerified())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN,
                    "Verifica tu correo antes de solicitar permisos de restaurante.");
        }
        requireRequestedRestaurantAdmin(userId);

        return pqrs.findFirstByClienteIdAndAsuntoAndEstadoIn(
                        userId, RESTAURANT_REQUEST_SUBJECT, OPEN_STATES)
                .orElseGet(() -> pqrs.save(Pqrs.builder()
                        .clienteId(userId)
                        .tipo(Pqrs.PqrsType.peticion)
                        .asunto(RESTAURANT_REQUEST_SUBJECT)
                        .descripcion(description.trim())
                        .estado(Pqrs.PqrsStatus.recibida)
                        .build()));
    }

    @Transactional
    public UserResponse approveRestaurantAdmin(String requestId) {
        Pqrs request = pqrs.findByIdForUpdate(requestId)
                .filter(ticket -> isRestaurantRequest(ticket.getAsunto())
                        && ticket.getTipo() == Pqrs.PqrsType.peticion)
                .orElseThrow(() -> new ResponseStatusException(
                        HttpStatus.NOT_FOUND, "Solicitud no encontrada"));
        if (!OPEN_STATES.contains(request.getEstado())) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "La solicitud ya fue atendida");
        }

        User user = activeUserForUpdate(request.getClienteId());
        requireFoodie(user);
        requireRequestedRestaurantAdmin(user.getId());
        if (!Boolean.TRUE.equals(user.getEmailVerified())) {
            throw new ResponseStatusException(HttpStatus.CONFLICT,
                    "La cuenta debe verificar su correo antes de la aprobación.");
        }

        user.setRole(User.Role.restaurant_admin);
        users.save(user);
        sessions.revokeActiveByUserId(user.getId());

        LocalDateTime now = LocalDateTime.now();
        request.setEstado(Pqrs.PqrsStatus.resuelta);
        request.setRespuesta("Solicitud aprobada. Vuelve a iniciar sesión desde la aplicación web.");
        request.setFechaGestion(now);
        request.setFechaCierre(now);
        return UserResponse.fromSelf(user);
    }

    public static boolean isRestaurantRequest(String subject) {
        return subject != null && RESTAURANT_REQUEST_SUBJECT.equalsIgnoreCase(subject.trim());
    }

    private User activeUserForUpdate(String userId) {
        User user = users.findByIdForUpdate(userId).orElseThrow(IdentityService::invalidSession);
        requireActive(user);
        return user;
    }

    private static void requireActive(User user) {
        if (!Boolean.TRUE.equals(user.getIsActive())) throw invalidSession();
    }

    private void requireRequestedRestaurantAdmin(String userId) {
        if (!"restaurant_admin".equals(identities.requestedRole("client", userId))) {
            throw new ResponseStatusException(
                    HttpStatus.FORBIDDEN, "Esta cuenta no solicitó el tipo de cuenta restaurante.");
        }
    }

    private static void requireFoodie(User user) {
        if (user.getRole() != User.Role.foodie) {
            throw new ResponseStatusException(
                    HttpStatus.CONFLICT, "La cuenta no es elegible para esta solicitud");
        }
    }

    private static ResponseStatusException invalidSession() {
        return new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Sesión inválida");
    }
}