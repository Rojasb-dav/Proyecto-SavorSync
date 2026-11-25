package co.edu.umb.foodies.backend.model;

import jakarta.persistence.*;
import lombok.*;
import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "imagenes_restaurante")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class RestaurantImage {

    public enum ImageType {
        portada, galeria, item_menu
    }

    @Id
    @Column(length = 36, columnDefinition = "CHAR(36)", nullable = false, updatable = false)
    private String id;

    @Column(name = "restaurante_id", length = 36, columnDefinition = "CHAR(36)", nullable = false)
    private String restaurantId;

    @Column(name = "cliente_id", length = 36, columnDefinition = "CHAR(36)", nullable = false)
    private String clientId;

    @Column(name = "url", nullable = false, length = 500)
    private String url;

    @Column(name = "cloudinary_id", length = 255)
    private String cloudinaryId;

    @Enumerated(EnumType.STRING)
    @Column(name = "tipo", nullable = false, columnDefinition = "ENUM('portada','galeria','item_menu')")
    @Builder.Default
    private ImageType type = ImageType.galeria;

    @Column(name = "orden", columnDefinition = "TINYINT")
    @Builder.Default
    private Integer orderIndex = 0;

    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;

    @PrePersist
    public void prePersist() {
        if (id == null) id = UUID.randomUUID().toString();
        if (type == null) type = ImageType.galeria;
        if (orderIndex == null) orderIndex = 0;
        if (createdAt == null) createdAt = LocalDateTime.now();
    }
}
