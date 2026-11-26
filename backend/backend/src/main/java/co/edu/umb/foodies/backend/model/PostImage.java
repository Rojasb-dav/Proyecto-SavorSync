package co.edu.umb.foodies.backend.model;

import jakarta.persistence.*;
import lombok.*;
import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "imagenes_publicacion")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class PostImage {

    @Id
    @Column(length = 36, columnDefinition = "CHAR(36)", nullable = false, updatable = false)
    private String id;

    @Column(name = "publicacion_id", length = 36, columnDefinition = "CHAR(36)", nullable = false)
    private String postId;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "publicacion_id", insertable = false, updatable = false)
    private Post post;

    @Column(name = "cliente_id", length = 36, columnDefinition = "CHAR(36)", nullable = false)
    private String clientId;

    @Column(name = "url", nullable = false, length = 500)
    private String url;

    @Column(name = "cloudinary_id", length = 255)
    private String cloudinaryId;

    @Column(name = "orden", columnDefinition = "TINYINT")
    @Builder.Default
    private Integer orderIndex = 0;

    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;

    @PrePersist
    public void prePersist() {
        if (id == null) id = UUID.randomUUID().toString();
        if (orderIndex == null) orderIndex = 0;
        if (createdAt == null) createdAt = LocalDateTime.now();
    }
}
