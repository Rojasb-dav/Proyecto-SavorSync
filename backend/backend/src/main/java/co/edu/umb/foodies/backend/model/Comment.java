package co.edu.umb.foodies.backend.model;

import com.fasterxml.jackson.annotation.JsonAlias;
import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.persistence.*;
import lombok.*;
import lombok.EqualsAndHashCode;

import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "comentarios")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
@EqualsAndHashCode(onlyExplicitlyIncluded = true)
public class Comment {

    public enum CommentStatus {
        activo, oculto, eliminado
    }

    @Id
    @EqualsAndHashCode.Include
    @Column(length = 36, columnDefinition = "CHAR(36)", nullable = false, updatable = false)
    private String id;

    @JsonProperty("postId")
    @JsonAlias({"publicacion_id", "postId", "post_id"})
    @Column(name = "publicacion_id", length = 36, columnDefinition = "CHAR(36)", nullable = false, updatable = false)
    private String postId;

    @JsonProperty("clienteId")
    @JsonAlias({"cliente_id", "authorId", "author_id", "userId", "user_id", "clienteId"})
    @Column(name = "cliente_id", length = 36, columnDefinition = "CHAR(36)", nullable = false)
    private String clienteId;

    @JsonProperty("parentId")
    @JsonAlias({"parent_id", "parentId"})
    @Column(name = "parent_id", length = 36, columnDefinition = "CHAR(36)", updatable = false)
    private String parentId;

    @JsonProperty("content")
    @JsonAlias({"contenido", "content"})
    @Column(name = "contenido", nullable = false, length = 200)
    private String content;

    @JsonProperty("status")
    @JsonAlias({"estado", "status"})
    @Column(name = "estado", columnDefinition = "ENUM('activo','oculto','eliminado')")
    @Builder.Default
    private String status = "activo";

    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    @PrePersist
    public void prePersist() {
        if (id == null) id = UUID.randomUUID().toString();
        if (status == null) status = "activo";
        LocalDateTime now = LocalDateTime.now();
        if (createdAt == null) createdAt = now;
        updatedAt = now;
    }

    @PreUpdate
    public void preUpdate() {
        updatedAt = LocalDateTime.now();
    }
}
