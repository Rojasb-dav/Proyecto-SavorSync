package co.edu.umb.foodies.backend.model;

import jakarta.persistence.*;
import lombok.*;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "promociones_restaurante")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class RestaurantPromotion {

    public enum DiscountType {
        porcentaje, fijo
    }

    @Id
    @Column(length = 36, nullable = false, updatable = false)
    private String id;

    @Column(name = "restaurante_id", length = 36, nullable = false)
    private String restaurantId;

    @Column(name = "titulo", nullable = false, length = 100)
    private String title;

    @Column(name = "descripcion", columnDefinition = "TEXT")
    private String description;

    @Enumerated(EnumType.STRING)
    @Column(name = "tipo_descuento")
    @Builder.Default
    private DiscountType discountType = DiscountType.porcentaje;

    @Column(name = "valor_descuento", nullable = false)
    private BigDecimal discountValue;

    @Column(name = "fecha_inicio", nullable = false)
    private LocalDate startDate;

    @Column(name = "fecha_fin", nullable = false)
    private LocalDate endDate;

    @Column(name = "activa")
    @Builder.Default
    private Boolean isActive = true;

    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    @PrePersist
    public void prePersist() {
        if (id == null) id = UUID.randomUUID().toString();
        if (discountType == null) discountType = DiscountType.porcentaje;
        if (isActive == null) isActive = true;
        LocalDateTime now = LocalDateTime.now();
        if (createdAt == null) createdAt = now;
        updatedAt = now;
    }

    @PreUpdate
    public void preUpdate() {
        updatedAt = LocalDateTime.now();
    }
}
