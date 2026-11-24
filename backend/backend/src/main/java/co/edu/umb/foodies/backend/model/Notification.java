package co.edu.umb.foodies.backend.model;

import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "notificaciones_cliente")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Notification {

    public enum NotificationType {
        like, comment, follow, reservation, system, menu
    }

    public enum Channel {
        in_app, email, push
    }

    @Id
    @Column(length = 36, nullable = false, updatable = false)
    private String id;

    @Column(name = "cliente_id", length = 36, nullable = false)
    private String clienteId;

    @Enumerated(EnumType.STRING)
    @Column(name = "tipo", nullable = false)
    private NotificationType type;

    @Column(name = "titulo", nullable = false, length = 200)
    private String title;

    @Column(name = "mensaje", columnDefinition = "TEXT", nullable = false)
    private String body;

    @Column(name = "leida", nullable = false)
    private Boolean read;

    @Enumerated(EnumType.STRING)
    @Column(name = "canal")
    private Channel channel;

    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;

    @PrePersist
    public void prePersist() {
        if (id == null) id = UUID.randomUUID().toString();
        if (read == null) read = false;
        if (type == null) type = NotificationType.system;
        if (channel == null) channel = Channel.in_app;
        if (createdAt == null) createdAt = LocalDateTime.now();
    }
}
