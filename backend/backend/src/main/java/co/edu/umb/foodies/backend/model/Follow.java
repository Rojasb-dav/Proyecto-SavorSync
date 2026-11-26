package co.edu.umb.foodies.backend.model;

import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "seguidores", uniqueConstraints =
        @UniqueConstraint(name = "uq_seguimiento", columnNames = {"seguidor_id", "seguido_id"}))
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Follow {

    @Id
    @Column(length = 36, columnDefinition = "CHAR(36)", updatable = false)
    private String id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "seguidor_id", nullable = false, updatable = false)
    private User follower;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "seguido_id", nullable = false, updatable = false)
    private User followed;

    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;

    public Follow(User follower, User followed) {
        this.id = UUID.randomUUID().toString();
        this.follower = follower;
        this.followed = followed;
        this.createdAt = LocalDateTime.now();
    }
}
