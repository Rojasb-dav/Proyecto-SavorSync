package co.edu.umb.foodies.backend.model;

import com.fasterxml.jackson.annotation.JsonAlias;
import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDate;
import java.time.LocalTime;
import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "reservas")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Reservation {

    public enum ReservationStatus {
        pendiente, confirmada, cancelada, completada
    }

    @Id
    @Column(length = 36, nullable = false, updatable = false)
    private String id;

    @JsonProperty("restaurantId")
    @JsonAlias({"restaurante_id", "restaurant_id", "restaurantId"})
    @Column(name = "restaurante_id", length = 36, nullable = false)
    private String restaurantId;

    @JsonProperty("clienteId")
    @JsonAlias({"userId", "cliente_id", "user_id", "clienteId"})
    @Column(name = "cliente_id", length = 36, nullable = false)
    private String clienteId;

    @JsonProperty("numPersonas")
    @JsonAlias({"guests", "num_personas", "numPersonas"})
    @Column(name = "num_personas", nullable = false)
    private Integer numPersonas;

    @JsonProperty("fechaReserva")
    @JsonAlias({"date", "fecha_reserva", "fechaReserva"})
    @Column(name = "fecha_reserva", nullable = false)
    private LocalDate fechaReserva;

    @JsonProperty("horaReserva")
    @JsonAlias({"time", "hora_reserva", "horaReserva"})
    @Column(name = "hora_reserva", nullable = false)
    private LocalTime horaReserva;

    @JsonProperty("estado")
    @JsonAlias({"status", "estado"})
    @Enumerated(EnumType.STRING)
    @Column(name = "estado", nullable = false)
    private ReservationStatus estado;

    @JsonProperty("notas")
    @JsonAlias({"specialNotes", "special_notes", "notas"})
    @Column(name = "notas", columnDefinition = "TEXT")
    private String notas;

    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    @PrePersist
    public void prePersist() {
        if (id == null) id = UUID.randomUUID().toString();
        if (numPersonas == null) numPersonas = 2;
        if (estado == null) estado = ReservationStatus.pendiente;
        LocalDateTime now = LocalDateTime.now();
        if (createdAt == null) createdAt = now;
        updatedAt = now;
    }

    @PreUpdate
    public void preUpdate() {
        updatedAt = LocalDateTime.now();
    }
}
