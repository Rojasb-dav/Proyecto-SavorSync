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
        return ResponseEntity.ok(reservationRepository.save(reservation));
    }

    @Transactional
    @PutMapping("/{id}")
    public ResponseEntity<Reservation> updateStatus(@PathVariable String id, @RequestBody Map<String, Object> body) {
        return reservationRepository.findById(id).map(r -> {
            String statusStr = body.get("estado") != null ? body.get("estado").toString() : null;
            if (statusStr == null && body.get("status") != null) {
                statusStr = body.get("status").toString();
            }
            if (statusStr != null) {
                try {
                    r.setEstado(Reservation.ReservationStatus.valueOf(statusStr.trim().toLowerCase()));
                } catch (Exception ignored) {}
            }
            return ResponseEntity.ok(reservationRepository.save(r));
        }).orElse(ResponseEntity.notFound().build());
    }
}
