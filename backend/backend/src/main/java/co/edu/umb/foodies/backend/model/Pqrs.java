package co.edu.umb.foodies.backend.model;

import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "pqrs")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Pqrs {

    public enum PqrsType {
        peticion, queja, reclamo, sugerencia
    }

    public enum PqrsStatus {
        recibida, en_gestion, resuelta, cerrada
    }

    @Id
    @Column(length = 36, nullable = false, updatable = false)
    private String id;

    @Column(name = "cliente_id", length = 36, nullable = false)
    private String clienteId;

    @Column(name = "empleado_id", length = 36)
    private String empleadoId;

    @Enumerated(EnumType.STRING)
    @Column(name = "tipo", nullable = false)
    private PqrsType tipo;

    @Column(name = "asunto", nullable = false, length = 150)
    private String asunto;

    @Column(name = "descripcion", columnDefinition = "TEXT", nullable = false)
    private String descripcion;

    @Enumerated(EnumType.STRING)
    @Column(name = "estado")
    @Builder.Default
    private PqrsStatus estado = PqrsStatus.recibida;

    @Column(name = "respuesta", columnDefinition = "TEXT")
    private String respuesta;

    @Column(name = "fecha_gestion")
    private LocalDateTime fechaGestion;

    @Column(name = "fecha_cierre")
    private LocalDateTime fechaCierre;

    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    @PrePersist
    public void prePersist() {
        if (id == null) id = UUID.randomUUID().toString();
        if (estado == null) estado = PqrsStatus.recibida;
        LocalDateTime now = LocalDateTime.now();
        if (createdAt == null) createdAt = now;
        updatedAt = now;
    }

    @PreUpdate
    public void preUpdate() {
        updatedAt = LocalDateTime.now();
    }
}
