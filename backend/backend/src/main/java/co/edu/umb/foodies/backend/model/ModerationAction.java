package co.edu.umb.foodies.backend.model;

import jakarta.persistence.*;
import lombok.*;
import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "acciones_moderacion")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ModerationAction {

    public enum ActionType {
        aprobado, oculto, eliminado, advertido, baneado
    }

    @Id
    @Column(length = 36, nullable = false, updatable = false)
    private String id;

    @Column(name = "empleado_id", length = 36, nullable = false)
    private String employeeId;

    @Column(name = "reporte_id", length = 36, nullable = false)
    private String reportId;

    @Enumerated(EnumType.STRING)
    @Column(name = "accion", nullable = false)
    private ActionType action;

    @Column(name = "notas", columnDefinition = "TEXT")
    private String notes;

    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;

    @PrePersist
    public void prePersist() {
        if (id == null) id = UUID.randomUUID().toString();
        if (createdAt == null) createdAt = LocalDateTime.now();
    }
}
