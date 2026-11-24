package co.edu.umb.foodies.backend.controller;

import co.edu.umb.foodies.backend.model.Reservation;
import co.edu.umb.foodies.backend.repository.ReservationRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

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

    @PutMapping("/{id}")
    public ResponseEntity<Reservation> updateStatus(@PathVariable String id, @RequestBody Reservation body) {
        return reservationRepository.findById(id).map(r -> {
            r.setEstado(body.getEstado());
            return ResponseEntity.ok(reservationRepository.save(r));
        }).orElse(ResponseEntity.notFound().build());
    }
}
