package co.edu.umb.foodies.backend.model;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "restaurantes")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Restaurant {

    public enum RestaurantStatus {
        pendiente, activo, suspendido
    }

    @Id
    @Column(length = 36, nullable = false, updatable = false)
    private String id;

    @Column(name = "owner_id", length = 36)
    private String ownerId;

    @Column(name = "nombre", nullable = false, length = 100)
    private String name;

    @Column(name = "descripcion", columnDefinition = "TEXT")
    private String description;

    @Column(name = "direccion", length = 255)
    private String address;

    @Column(name = "ciudad", length = 100)
    private String city;

    @Column(name = "latitud", precision = 10, scale = 8)
    private BigDecimal latitude;

    @Column(name = "longitud", precision = 11, scale = 8)
    private BigDecimal longitude;

    @Column(name = "telefono", length = 20)
    private String phone;

    @Column(name = "email", length = 191)
    private String email;

    @Column(name = "sitio_web", length = 255)
    private String website;

    @Column(name = "categoria", length = 50)
    private String category;

    @Column(name = "rango_precio")
    private Integer priceRange;

    @Column(name = "rating_promedio", precision = 3, scale = 2)
    private BigDecimal ratingAverage;

    @Column(name = "total_resenas")
    private Integer reviewsCount;

    @Enumerated(EnumType.STRING)
    @Column(name = "estado")
    private RestaurantStatus status;

    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    @PrePersist
    public void prePersist() {
        if (id == null) id = UUID.randomUUID().toString();
        if (city == null) city = "Bogotá";
        if (priceRange == null) priceRange = 2;
        if (ratingAverage == null) ratingAverage = BigDecimal.valueOf(0.0);
        if (reviewsCount == null) reviewsCount = 0;
        if (status == null) status = RestaurantStatus.activo;
        LocalDateTime now = LocalDateTime.now();
        if (createdAt == null) createdAt = now;
        updatedAt = now;
    }

    @PreUpdate
    public void preUpdate() {
        updatedAt = LocalDateTime.now();
    }
}
