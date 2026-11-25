package co.edu.umb.foodies.backend.model;

import jakarta.persistence.*;
import lombok.*;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "analiticas_restaurante")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class RestaurantAnalytics {

    @Id
    @Column(length = 36, nullable = false, updatable = false)
    private String id;

    @Column(name = "restaurante_id", length = 36, nullable = false)
    private String restaurantId;

    @Column(name = "fecha", nullable = false)
    private LocalDate date;

    @Column(name = "visitas_perfil")
    @Builder.Default
    private Integer profileViews = 0;

    @Column(name = "total_likes")
    @Builder.Default
    private Integer totalLikes = 0;

    @Column(name = "total_comentarios")
    @Builder.Default
    private Integer totalComments = 0;

    @Column(name = "total_resenas")
    @Builder.Default
    private Integer totalReviews = 0;

    @Column(name = "rating_promedio", precision = 3, scale = 2)
    @Builder.Default
    private BigDecimal averageRating = BigDecimal.ZERO;

    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    @PrePersist
    public void prePersist() {
        if (id == null) id = UUID.randomUUID().toString();
        if (profileViews == null) profileViews = 0;
        if (totalLikes == null) totalLikes = 0;
        if (totalComments == null) totalComments = 0;
        if (totalReviews == null) totalReviews = 0;
        if (averageRating == null) averageRating = BigDecimal.ZERO;
        LocalDateTime now = LocalDateTime.now();
        if (createdAt == null) createdAt = now;
        updatedAt = now;
    }

    @PreUpdate
    public void preUpdate() {
        updatedAt = LocalDateTime.now();
    }
}
