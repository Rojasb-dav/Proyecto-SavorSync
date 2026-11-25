package co.edu.umb.foodies.backend.model;

import jakarta.persistence.*;
import lombok.*;
import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "notificaciones_empleado")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class EmployeeNotification {

    public enum NotificationType {
        nuevo_reporte, nuevo_restaurante, escalamiento, nueva_pqrs
    }

    public enum Channel {
        email, in_app
    }

    @Id
    @Column(length = 36, nullable = false, updatable = false)
    private String id;

    @Column(name = "empleado_id", length = 36, nullable = false)
    private String employeeId;

    @Enumerated(EnumType.STRING)
    @Column(name = "tipo", nullable = false)
    private NotificationType type;

    @Column(name = "titulo", nullable = false, length = 200)
    private String title;

    @Column(name = "mensaje", columnDefinition = "TEXT")
    private String message;

    @Column(name = "leida", nullable = false)
    @Builder.Default
    private Boolean read = false;

    @Enumerated(EnumType.STRING)
    @Column(name = "canal", nullable = false)
    @Builder.Default
    private Channel channel = Channel.in_app;

    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;

    @PrePersist
    public void prePersist() {
        if (id == null) id = UUID.randomUUID().toString();
        if (read == null) read = false;
        if (channel == null) channel = Channel.in_app;
        if (createdAt == null) createdAt = LocalDateTime.now();
    }
}
