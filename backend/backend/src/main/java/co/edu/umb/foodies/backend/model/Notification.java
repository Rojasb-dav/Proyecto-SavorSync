package co.edu.umb.foodies.backend.model;

import com.fasterxml.jackson.annotation.JsonAlias;
import com.fasterxml.jackson.annotation.JsonProperty;
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
        like,
        comentario,
        seguidor,
        respuesta_resena,
        promocion,
        reserva,
        pqrs
    }

    public enum Channel {
        push, email, in_app
    }

    @Id
    @Column(length = 36, nullable = false, updatable = false)
    private String id;

    @JsonProperty("clienteId")
    @JsonAlias({"userId", "cliente_id", "targetUserId", "clienteId"})
    @Column(name = "cliente_id", length = 36, nullable = false)
    private String clienteId;

    @JsonProperty("type")
    @JsonAlias({"tipo", "type"})
    @Enumerated(EnumType.STRING)
    @Column(name = "tipo", nullable = false)
    private NotificationType type;

    @JsonProperty("title")
    @JsonAlias({"titulo", "title"})
    @Column(name = "titulo", nullable = false, length = 200)
    private String title;

    @JsonProperty("body")
    @JsonAlias({"mensaje", "body"})
    @Column(name = "mensaje", columnDefinition = "TEXT", nullable = false)
    private String body;

    @JsonProperty("read")
    @JsonAlias({"leida", "read"})
    @Column(name = "leida", nullable = false)
    @Builder.Default
    private Boolean read = false;

    @Enumerated(EnumType.STRING)
    @Column(name = "canal")
    @Builder.Default
    private Channel channel = Channel.in_app;

    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;

    @PrePersist
    public void prePersist() {
        if (id == null) id = UUID.randomUUID().toString();
        if (read == null) read = false;
        if (type == null) type = NotificationType.like;
        if (channel == null) channel = Channel.in_app;
        if (createdAt == null) createdAt = LocalDateTime.now();
    }
}
