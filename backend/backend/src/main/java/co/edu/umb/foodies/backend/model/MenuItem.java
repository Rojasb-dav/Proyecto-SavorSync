package co.edu.umb.foodies.backend.model;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "menu_restaurante")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class MenuItem {

    @Id
    @Column(length = 36, columnDefinition = "CHAR(36)", nullable = false, updatable = false)
    private String id;

    @Column(name = "restaurante_id", length = 36, columnDefinition = "CHAR(36)", nullable = false)
    private String restaurantId;

    @Column(name = "nombre", nullable = false, length = 100)
    private String name;

    @Column(name = "descripcion", columnDefinition = "TEXT")
    private String description;

    @Column(name = "categoria", length = 50)
    private String category;

    @Column(name = "precio", precision = 10, scale = 2, nullable = false)
    private BigDecimal price;

    @Column(name = "disponible", nullable = false)
    private Boolean isAvailable;

    @Column(name = "orden")
    private Integer order;

    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    @PrePersist
    public void prePersist() {
        if (id == null) id = UUID.randomUUID().toString();
        if (isAvailable == null) isAvailable = true;
        if (category == null) category = "Platos Fuertes";
        if (order == null) order = 0;
        LocalDateTime now = LocalDateTime.now();
        if (createdAt == null) createdAt = now;
        updatedAt = now;
    }

    @PreUpdate
    public void preUpdate() {
        updatedAt = LocalDateTime.now();
    }
}
