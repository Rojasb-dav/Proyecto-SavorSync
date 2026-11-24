package co.edu.umb.foodies.backend.dto;

import co.edu.umb.foodies.backend.model.Reservation;
import co.edu.umb.foodies.backend.model.Restaurant;
import co.edu.umb.foodies.backend.model.User;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDate;
import java.time.LocalTime;
import java.time.LocalDateTime;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ReservationDTO {
    private String id;
    private String restaurantId;
    private String restaurantName;
    private String clienteId;
    private String clienteNombre;
    private Integer numPersonas;
    private LocalDate fechaReserva;
    private LocalTime horaReserva;
    private String estado;
    private String notas;
    private LocalDateTime createdAt;

    public static ReservationDTO from(Reservation r, Restaurant rest, User user) {
        if (r == null) return null;
        return ReservationDTO.builder()
                .id(r.getId())
                .restaurantId(r.getRestaurantId())
                .restaurantName(rest != null ? rest.getName() : "Restaurante Bogotá")
                .clienteId(r.getClienteId())
                .clienteNombre(user != null ? user.getFullName() : "Comensal")
                .numPersonas(r.getNumPersonas())
                .fechaReserva(r.getFechaReserva())
                .horaReserva(r.getHoraReserva())
                .estado(r.getEstado() != null ? r.getEstado().name() : "pendiente")
                .notas(r.getNotas())
                .createdAt(r.getCreatedAt())
                .build();
    }
}
