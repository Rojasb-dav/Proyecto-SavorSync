package co.edu.umb.foodies.backend.controller;

import co.edu.umb.foodies.backend.model.Reservation;
import co.edu.umb.foodies.backend.repository.ReservationRepository;
import co.edu.umb.foodies.backend.security.jwt.JwtUtil;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/reservations")
@RequiredArgsConstructor
public class ReservationController {

    private final ReservationRepository reservationRepository;
    private final JwtUtil jwtUtil;

    @GetMapping
    public ResponseEntity<List<Reservation>> getReservations(
            @RequestParam(required = false) String userId,
            @RequestParam(required = false) String restaurantId,
            HttpServletRequest request) {

        String authUserId = getUserIdFromRequest(request);
        String targetUserId = (userId != null && !userId.isBlank()) ? userId : authUserId;

        if (targetUserId != null && !targetUserId.isBlank()) {
            return ResponseEntity.ok(reservationRepository.findByClienteId(targetUserId));
        }
        if (restaurantId != null && !restaurantId.isBlank()) {
            return ResponseEntity.ok(reservationRepository.findByRestaurantId(restaurantId));
        }
        return ResponseEntity.ok(reservationRepository.findAll());
    }

    @PostMapping
    public ResponseEntity<Reservation> createReservation(@RequestBody Reservation reservation, HttpServletRequest request) {
        String authUserId = getUserIdFromRequest(request);
        if (authUserId != null && !authUserId.isBlank()) {
            reservation.setClienteId(authUserId);
        } else if (reservation.getClienteId() == null || reservation.getClienteId().isBlank()) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Debes iniciar sesión para realizar una reserva");
        }

        reservation.setEstado(Reservation.ReservationStatus.pendiente);
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

    private String getUserIdFromRequest(HttpServletRequest request) {
        if (request == null) return null;
        String header = request.getHeader("Authorization");
        if (header != null && header.startsWith("Bearer ")) {
            return jwtUtil.getUserId(header.substring(7));
        }
        return null;
    }
}
