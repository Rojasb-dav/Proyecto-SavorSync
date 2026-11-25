package co.edu.umb.foodies.backend.model;

import jakarta.persistence.*;
import lombok.*;
import java.time.LocalTime;
import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "horarios_restaurante")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class RestaurantSchedule {

    @Id
    @Column(length = 36, columnDefinition = "CHAR(36)", nullable = false, updatable = false)
    private String id;

    @Column(name = "restaurante_id", length = 36, columnDefinition = "CHAR(36)", nullable = false)
    private String restaurantId;

    @Column(name = "dia_semana", nullable = false, columnDefinition = "TINYINT")
    private Integer dayOfWeek;

    @Column(name = "hora_apertura")
    private LocalTime openingTime;

    @Column(name = "hora_cierre")
    private LocalTime closingTime;

    @Column(name = "cerrado")
    @Builder.Default
    private Boolean isClosed = false;

    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    @PrePersist
    public void prePersist() {
        if (id == null) id = UUID.randomUUID().toString();
        if (isClosed == null) isClosed = false;
        LocalDateTime now = LocalDateTime.now();
        if (createdAt == null) createdAt = now;
        updatedAt = now;
    }

    @PreUpdate
    public void preUpdate() {
        updatedAt = LocalDateTime.now();
    }
}
