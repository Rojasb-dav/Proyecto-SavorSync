package co.edu.umb.foodies.backend.controller;

import co.edu.umb.foodies.backend.dto.ReservationDTO;
import co.edu.umb.foodies.backend.model.Reservation;
import co.edu.umb.foodies.backend.model.Restaurant;
import co.edu.umb.foodies.backend.model.User;
import co.edu.umb.foodies.backend.repository.ReservationRepository;
import co.edu.umb.foodies.backend.repository.RestaurantRepository;
import co.edu.umb.foodies.backend.repository.UserRepository;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/v1/reservations")
@RequiredArgsConstructor
public class ReservationController {

    private final ReservationRepository reservationRepository;
    private final RestaurantRepository restaurantRepository;
    private final UserRepository userRepository;

    @GetMapping
    public ResponseEntity<List<ReservationDTO>> getReservations(
            @RequestParam(required = false) String userId,
            @RequestParam(required = false) String restaurantId,
            HttpServletRequest request) {

        String actor = request.getUserPrincipal().getName();
        List<Reservation> list;
        if (restaurantId != null && !restaurantId.isBlank()) {
            requireRestaurantOwner(restaurantId, request);
            list = reservationRepository.findByRestaurantId(restaurantId);
        } else if (userId == null && request.isUserInRole("RESTAURANT_ADMIN")) {
            list = restaurantRepository.findAllByOwnerId(actor).stream()
                    .flatMap(restaurant -> reservationRepository.findByRestaurantId(restaurant.getId()).stream())
                    .toList();
        } else {
            if (userId != null && !userId.isBlank() && !actor.equals(userId)) {
                throw new ResponseStatusException(HttpStatus.FORBIDDEN, "No puedes consultar reservas ajenas");
            }
            list = reservationRepository.findByClienteId(actor);
        }

        List<ReservationDTO> dtos = list.stream().map(this::convertToDTO).collect(Collectors.toList());
        return ResponseEntity.ok(dtos);
    }

    @PostMapping
    public ResponseEntity<ReservationDTO> createReservation(@RequestBody Reservation reservation, HttpServletRequest request) {
        reservation.setId(null);
        reservation.setClienteId(request.getUserPrincipal().getName());

        reservation.setEstado(Reservation.ReservationStatus.pendiente);
        Reservation saved = reservationRepository.save(reservation);
        return ResponseEntity.ok(convertToDTO(saved));
    }

    @Transactional
    @PutMapping("/{id}")
    public ResponseEntity<ReservationDTO> updateStatus(@PathVariable String id, @RequestBody Map<String, Object> body,
                                                         HttpServletRequest request) {
        return reservationRepository.findById(id).map(r -> {
            requireRestaurantOwner(r.getRestaurantId(), request);
            String raw = body.get("estado") != null ? body.get("estado").toString() : null;
            if (raw == null && body.get("status") != null) {
                raw = body.get("status").toString();
            }

            Reservation.ReservationStatus parsed = parseStatus(raw);
            if (parsed != null) {
                r.setEstado(parsed);
            }
            if (r.getEstado() == null) {
                r.setEstado(Reservation.ReservationStatus.pendiente);
            }

            Reservation saved = reservationRepository.save(r);
            return ResponseEntity.ok(convertToDTO(saved));
        }).orElse(ResponseEntity.notFound().build());
    }

    private ReservationDTO convertToDTO(Reservation r) {
        Restaurant rest = (r.getRestaurantId() != null) ? restaurantRepository.findById(r.getRestaurantId()).orElse(null) : null;
        User user = (r.getClienteId() != null) ? userRepository.findById(r.getClienteId()).orElse(null) : null;
        return ReservationDTO.from(r, rest, user);
    }

    private Reservation.ReservationStatus parseStatus(String input) {
        if (input == null || input.isBlank()) return null;
        String clean = input.trim().toLowerCase();
        for (Reservation.ReservationStatus status : Reservation.ReservationStatus.values()) {
            if (status.name().equalsIgnoreCase(clean)) {
                return status;
            }
        }
        return null;
    }

    private void requireRestaurantOwner(String restaurantId, HttpServletRequest request) {
        if (!request.isUserInRole("RESTAURANT_ADMIN") || restaurantId == null
                || restaurantRepository.findById(restaurantId)
                    .filter(r -> request.getUserPrincipal().getName().equals(r.getOwnerId()))
                    .isEmpty()) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "No puedes gestionar reservas de este restaurante");
        }
    }
}
