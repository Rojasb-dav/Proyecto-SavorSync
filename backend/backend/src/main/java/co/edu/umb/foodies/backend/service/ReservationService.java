package co.edu.umb.foodies.backend.service;

import co.edu.umb.foodies.backend.dto.ReservationDTO;
import co.edu.umb.foodies.backend.model.Notification;
import co.edu.umb.foodies.backend.model.Reservation;
import co.edu.umb.foodies.backend.model.Restaurant;
import co.edu.umb.foodies.backend.model.RestaurantSchedule;
import co.edu.umb.foodies.backend.model.User;
import co.edu.umb.foodies.backend.repository.NotificationRepository;
import co.edu.umb.foodies.backend.repository.ReservationRepository;
import co.edu.umb.foodies.backend.repository.RestaurantRepository;
import co.edu.umb.foodies.backend.repository.RestaurantScheduleRepository;
import co.edu.umb.foodies.backend.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class ReservationService {

    private final ReservationRepository reservationRepository;
    private final RestaurantRepository restaurantRepository;
    private final UserRepository userRepository;
    private final RestaurantScheduleRepository restaurantScheduleRepository;
    private final NotificationRepository notificationRepository;

    @Transactional(readOnly = true)
    public List<ReservationDTO> getClientReservations(String clientId) {
        return reservationRepository.findByClienteId(clientId).stream()
                .map(this::convertToDTO).collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public List<ReservationDTO> getRestaurantReservations(String restaurantId, String ownerId) {
        requireRestaurantOwner(restaurantId, ownerId);
        return reservationRepository.findByRestaurantId(restaurantId).stream()
                .map(this::convertToDTO).collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public List<ReservationDTO> getAllOwnerReservations(String ownerId) {
        return restaurantRepository.findAllByOwnerId(ownerId).stream()
                .flatMap(restaurant -> reservationRepository.findByRestaurantId(restaurant.getId()).stream())
                .map(this::convertToDTO).toList();
    }

    @Transactional
    public ReservationDTO createReservation(Reservation reservation, String clientId) {
        if (reservation.getRestaurantId() == null || reservation.getRestaurantId().isBlank()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Restaurante no especificado");
        }

        User client = userRepository.findByIdForUpdate(clientId)
                .filter(user -> user.getRole() == User.Role.foodie && Boolean.TRUE.equals(user.getIsActive())
                        && Boolean.TRUE.equals(user.getEmailVerified()))
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.FORBIDDEN,
                        "Solo una cuenta Foodie verificada puede reservar."));

        Restaurant restaurant = restaurantRepository.findByIdForUpdate(reservation.getRestaurantId())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Restaurante no encontrado"));

        if (restaurant.getStatus() != Restaurant.RestaurantStatus.activo || restaurant.getDeactivatedAt() != null) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "El restaurante no está activo para recibir reservas");
        }

        if (reservation.getFechaReserva() == null || reservation.getFechaReserva().isBefore(LocalDate.now())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "La fecha de reserva debe ser igual o posterior a hoy");
        }

        if (reservation.getHoraReserva() == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Hora de reserva no especificada");
        }

        if (reservation.getFechaReserva().equals(LocalDate.now()) && reservation.getHoraReserva().isBefore(LocalTime.now())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "La hora de la reserva ya pasó");
        }

        if (reservation.getNumPersonas() == null || reservation.getNumPersonas() < 1 || reservation.getNumPersonas() > 127) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "La reserva debe ser para entre 1 y 127 personas");
        }

        int dayOfWeek = reservation.getFechaReserva().getDayOfWeek().getValue() % 7; // Domingo=0 en el modelo
        RestaurantSchedule schedule = restaurantScheduleRepository.findByRestaurantIdAndDayOfWeek(restaurant.getId(), dayOfWeek).orElse(null);

        if (schedule != null) {
            if (Boolean.TRUE.equals(schedule.getIsClosed())) {
                throw new ResponseStatusException(HttpStatus.CONFLICT, "El restaurante se encuentra cerrado ese día");
            }
            if (schedule.getOpeningTime() != null && reservation.getHoraReserva().isBefore(schedule.getOpeningTime())) {
                throw new ResponseStatusException(HttpStatus.CONFLICT, "La reserva es anterior al horario de apertura");
            }
            if (schedule.getClosingTime() != null && reservation.getHoraReserva().isAfter(schedule.getClosingTime())) {
                throw new ResponseStatusException(HttpStatus.CONFLICT, "La reserva es posterior al horario de cierre");
            }
        }

        reservation.setId(UUID.randomUUID().toString());
        reservation.setClienteId(clientId);
        reservation.setEstado(Reservation.ReservationStatus.pendiente);
        reservation.setCreatedAt(null);

        Reservation saved = reservationRepository.save(reservation);

        notificationRepository.save(Notification.builder()
                .id(UUID.randomUUID().toString())
                .clienteId(restaurant.getOwnerId())
                .type(Notification.NotificationType.reserva)
                .title("¡Nueva solicitud de reserva! 📅")
                .body(client.getFullName() + " ha solicitado una mesa para " + saved.getNumPersonas()
                        + " personas el " + saved.getFechaReserva() + " a las " + saved.getHoraReserva())
                .read(false)
                .channel(Notification.Channel.in_app)
                .createdAt(LocalDateTime.now())
                .build());

        return convertToDTO(saved);
    }

    @Transactional
    public ReservationDTO updateStatus(String reservationId, Reservation.ReservationStatus newStatus, String ownerId) {
        if (newStatus == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Estado inválido");
        }
        userRepository.findByIdForUpdate(ownerId)
                .filter(owner -> owner.getRole() == User.Role.restaurant_admin
                        && Boolean.TRUE.equals(owner.getIsActive()) && Boolean.TRUE.equals(owner.getEmailVerified()))
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.FORBIDDEN, "Propietario no habilitado"));
        String restaurantId = reservationRepository.findRestaurantId(reservationId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Reserva no encontrada"));
        Restaurant restaurant = restaurantRepository.findByIdForUpdate(restaurantId)
                .filter(found -> ownerId.equals(found.getOwnerId()))
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.FORBIDDEN,
                        "No puedes gestionar reservas de este restaurante"));
        if (restaurant.getDeactivatedAt() != null && newStatus != Reservation.ReservationStatus.cancelada
                && newStatus != Reservation.ReservationStatus.completada) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "El restaurante está desactivado");
        }
        Reservation r = reservationRepository.findByIdForUpdate(reservationId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Reserva no encontrada"));

        // Restringir transiciones inválidas
        if (r.getEstado() == Reservation.ReservationStatus.completada || r.getEstado() == Reservation.ReservationStatus.cancelada) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "No se puede modificar una reserva que ya está " + r.getEstado());
        }

        Reservation.ReservationStatus oldStatus = r.getEstado();
        r.setEstado(newStatus);
        Reservation saved = reservationRepository.save(r);

        // Notificar al foodie del cambio
        if (oldStatus != newStatus) {
            notificationRepository.save(Notification.builder()
                    .id(UUID.randomUUID().toString())
                    .clienteId(r.getClienteId())
                    .type(Notification.NotificationType.reserva)
                    .title("Estado de reserva actualizado")
                    .body(restaurant.getName() + " ha marcado tu reserva del " + r.getFechaReserva() + " como " + newStatus)
                    .read(false)
                    .channel(Notification.Channel.in_app)
                    .createdAt(LocalDateTime.now())
                    .build());
        }

        return convertToDTO(saved);
    }

    private ReservationDTO convertToDTO(Reservation r) {
        Restaurant rest = (r.getRestaurantId() != null) ? restaurantRepository.findById(r.getRestaurantId()).orElse(null) : null;
        User user = (r.getClienteId() != null) ? userRepository.findById(r.getClienteId()).orElse(null) : null;
        return ReservationDTO.from(r, rest, user);
    }

    private void requireRestaurantOwner(String restaurantId, String ownerId) {
        if (restaurantId == null || restaurantRepository.findById(restaurantId)
                .filter(r -> ownerId.equals(r.getOwnerId()))
                .isEmpty()) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "No puedes gestionar reservas de este restaurante");
        }
    }
}
