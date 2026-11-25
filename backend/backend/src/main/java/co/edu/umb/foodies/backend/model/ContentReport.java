package co.edu.umb.foodies.backend.model;

import jakarta.persistence.*;
import lombok.*;
import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "reportes_contenido")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ContentReport {

    public enum ContentType {
        publicacion, comentario, restaurante
    }

    public enum ReportStatus {
        pendiente, revisado, resuelto
    }

    @Id
    @Column(length = 36, columnDefinition = "CHAR(36)", nullable = false, updatable = false)
    private String id;

    @Column(name = "reporter_id", length = 36, columnDefinition = "CHAR(36)", nullable = false)
    private String reporterId;

    @Enumerated(EnumType.STRING)
    @Column(name = "tipo_contenido", nullable = false, columnDefinition = "ENUM('publicacion','comentario','restaurante')")
    private ContentType contentType;

    @Column(name = "contenido_id", length = 36, columnDefinition = "CHAR(36)", nullable = false)
    private String contentId;

    @Column(name = "motivo", nullable = false, length = 100)
    private String reason;

    @Column(name = "descripcion", columnDefinition = "TEXT")
    private String description;

    @Enumerated(EnumType.STRING)
    @Column(name = "estado", columnDefinition = "ENUM('pendiente','revisado','resuelto')")
    @Builder.Default
    private ReportStatus status = ReportStatus.pendiente;

    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    @PrePersist
    public void prePersist() {
        if (id == null) id = UUID.randomUUID().toString();
        if (status == null) status = ReportStatus.pendiente;
        LocalDateTime now = LocalDateTime.now();
        if (createdAt == null) createdAt = now;
        updatedAt = now;
    }

    @PreUpdate
    public void preUpdate() {
        updatedAt = LocalDateTime.now();
    }
}
