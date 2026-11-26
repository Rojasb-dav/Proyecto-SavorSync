package co.edu.umb.foodies.backend.controller;

import co.edu.umb.foodies.backend.dto.ReservationDTO;
import co.edu.umb.foodies.backend.model.Reservation;
import co.edu.umb.foodies.backend.service.ReservationService;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/reservations")
@RequiredArgsConstructor
public class ReservationController {

    private final ReservationService reservations;

    @GetMapping
    public ResponseEntity<List<ReservationDTO>> getReservations(
            @RequestParam(required = false) String userId,
            @RequestParam(required = false) String restaurantId,
            HttpServletRequest request) {

        String actor = request.getUserPrincipal().getName();
        if (restaurantId != null && !restaurantId.isBlank()) {
            requireRestaurantAdmin(request);
            return ResponseEntity.ok(reservations.getRestaurantReservations(restaurantId, actor));
        }
        if (userId == null && request.isUserInRole("RESTAURANT_ADMIN")) {
            return ResponseEntity.ok(reservations.getAllOwnerReservations(actor));
        }
        if (userId != null && !userId.isBlank() && !actor.equals(userId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "No puedes consultar reservas ajenas");
        }
        return ResponseEntity.ok(reservations.getClientReservations(actor));
    }

    @PostMapping
    public ResponseEntity<ReservationDTO> createReservation(@RequestBody Reservation reservation, HttpServletRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(reservations.createReservation(reservation, request.getUserPrincipal().getName()));
    }

    @PutMapping("/{id}")
    public ResponseEntity<ReservationDTO> updateStatus(@PathVariable String id, @RequestBody Map<String, Object> body,
                                                       HttpServletRequest request) {
        requireRestaurantAdmin(request);
        Object raw = body.get("estado") != null ? body.get("estado") : body.get("status");
        Reservation.ReservationStatus status = parseStatus(raw == null ? null : raw.toString());
        return ResponseEntity.ok(reservations.updateStatus(id, status, request.getUserPrincipal().getName()));
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

    private void requireRestaurantAdmin(HttpServletRequest request) {
        if (!request.isUserInRole("RESTAURANT_ADMIN")) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "No puedes gestionar reservas de este restaurante");
        }
    }
}
