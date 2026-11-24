package co.edu.umb.foodies.backend.controller;

import co.edu.umb.foodies.backend.model.Reservation;
import co.edu.umb.foodies.backend.repository.ReservationRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/reservations")
@RequiredArgsConstructor
public class ReservationController {

    private final ReservationRepository reservationRepository;

    @GetMapping
    public ResponseEntity<List<Reservation>> getReservations(
            @RequestParam(required = false) String userId,
            @RequestParam(required = false) String restaurantId) {

        if (userId != null && !userId.isBlank()) {
            return ResponseEntity.ok(reservationRepository.findByClienteId(userId));
        }
        if (restaurantId != null && !restaurantId.isBlank()) {
            return ResponseEntity.ok(reservationRepository.findByRestaurantId(restaurantId));
        }
        return ResponseEntity.ok(reservationRepository.findAll());
    }

    @PostMapping
    public ResponseEntity<Reservation> createReservation(@RequestBody Reservation reservation) {
        if (reservation.getEstado() == null) {
            reservation.setEstado(Reservation.ReservationStatus.pendiente);
        }
        return ResponseEntity.ok(reservationRepository.save(reservation));
    }

    @Transactional
    @PutMapping("/{id}")
    public ResponseEntity<Reservation> updateStatus(@PathVariable String id, @RequestBody Map<String, Object> body) {
        return reservationRepository.findById(id).map(r -> {
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

            return ResponseEntity.ok(reservationRepository.save(r));
        }).orElse(ResponseEntity.notFound().build());
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
}
