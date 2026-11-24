package co.edu.umb.foodies.backend.model;

import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;
import java.util.HashSet;
import java.util.Set;
import java.util.UUID;

@Entity
@Table(name = "publicaciones")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Post {

    @Id
    @Column(length = 36, nullable = false, updatable = false)
    private String id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "cliente_id", nullable = false)
    private User user;

    @Column(name = "nombre_restaurante", nullable = false, length = 150)
    private String restaurantName;

    @Column(name = "direccion_restaurante", length = 255)
    private String restaurantAddress;

    @Column(columnDefinition = "TEXT", nullable = false)
    private String contenido;

    @Column(name = "calificacion", nullable = false)
    private Double rating;

    @Column(name = "url_imagen", length = 500)
    private String imageUrl;

    @Column(name = "conteo_likes")
    private Integer likesCount;

    @Column(name = "conteo_comentarios")
    private Integer commentsCount;

    @Column(name = "es_publica")
    private Boolean isPublic;

    public enum PostStatus {
        borrador, publicada, oculta, en_revision
    }

    @Enumerated(EnumType.STRING)
    @Column(name = "estado")
    private PostStatus status;

    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    @ManyToMany
    @JoinTable(
        name = "likes",
        joinColumns = @JoinColumn(name = "publicacion_id"),
        inverseJoinColumns = @JoinColumn(name = "cliente_id")
    )
    @Builder.Default
    private Set<User> likedBy = new HashSet<>();

    @PrePersist
    public void prePersist() {
        if (id == null) id = UUID.randomUUID().toString();
        if (likesCount == null) likesCount = 0;
        if (commentsCount == null) commentsCount = 0;
        if (isPublic == null) isPublic = true;
        if (status == null) status = PostStatus.publicada;
        if (likedBy == null) likedBy = new HashSet<>();
        LocalDateTime now = LocalDateTime.now();
        if (createdAt == null) createdAt = now;
        updatedAt = now;
    }

    @PreUpdate
    public void preUpdate() {
        updatedAt = LocalDateTime.now();
    }
}
