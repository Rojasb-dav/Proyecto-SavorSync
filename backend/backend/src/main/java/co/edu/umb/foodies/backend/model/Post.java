package co.edu.umb.foodies.backend.model;

import jakarta.persistence.*;
import lombok.*;
import lombok.EqualsAndHashCode;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Entity
@Table(name = "publicaciones")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
@EqualsAndHashCode(onlyExplicitlyIncluded = true)
public class Post {

    @Id
    @EqualsAndHashCode.Include
    @Column(length = 36, columnDefinition = "CHAR(36)", nullable = false, updatable = false)
    private String id;

    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "cliente_id", nullable = false, columnDefinition = "CHAR(36)")
    private User user;

    @Column(name = "restaurante_id", length = 36, columnDefinition = "CHAR(36)")
    private String restaurantId;

    @Column(columnDefinition = "TEXT", nullable = false)
    private String contenido;

    @Column(name = "calificacion", nullable = false, columnDefinition = "TINYINT")
    private Double rating;

    @Column(name = "conteo_likes")
    @Builder.Default
    private Integer likesCount = 0;

    @Column(name = "conteo_comentarios")
    @Builder.Default
    private Integer commentsCount = 0;

    @Column(name = "es_publica")
    @Builder.Default
    private Boolean isPublic = true;

    public enum PostStatus {
        borrador, publicada, oculta, en_revision
    }

    @Enumerated(EnumType.STRING)
    @Column(name = "estado", columnDefinition = "ENUM('borrador','publicada','oculta','en_revision')")
    @Builder.Default
    private PostStatus status = PostStatus.publicada;

    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    @OneToMany(mappedBy = "postId", cascade = CascadeType.ALL, orphanRemoval = true, fetch = FetchType.EAGER)
    @Builder.Default
    private List<PostImage> images = new ArrayList<>();

    @PrePersist
    public void prePersist() {
        if (id == null) id = UUID.randomUUID().toString();
        if (likesCount == null) likesCount = 0;
        if (commentsCount == null) commentsCount = 0;
        if (isPublic == null) isPublic = true;
        if (status == null) status = PostStatus.publicada;
        if (images == null) images = new ArrayList<>();
        LocalDateTime now = LocalDateTime.now();
        if (createdAt == null) createdAt = now;
        updatedAt = now;
    }

    @PreUpdate
    public void preUpdate() {
        updatedAt = LocalDateTime.now();
    }
}
