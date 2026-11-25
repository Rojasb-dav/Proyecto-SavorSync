package co.edu.umb.foodies.backend.model;

import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "tokens_recuperacion")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class PasswordResetToken {

    public enum IdentityType { client, employee }
    public enum Purpose { EMAIL_VERIFICATION, PASSWORD_RESET }

    @Id
    @Column(length = 36, columnDefinition = "CHAR(36)", nullable = false, updatable = false)
    private String id;

    @Column(name = "identity_id", length = 36, columnDefinition = "CHAR(36)")
    private String identityId;

    @Enumerated(EnumType.STRING)
    @Column(name = "identity_type", nullable = false, length = 16)
    private IdentityType identityType;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 32)
    private Purpose purpose;

    @Column(nullable = false, length = 255)
    private String code;

    @Column(nullable = false, length = 191)
    private String email;

    @Column(name = "expires_at", nullable = false)
    private LocalDateTime expiresAt;

    @Column(name = "created_at", nullable = false)
    private LocalDateTime createdAt;

    @Column(name = "failed_attempts", nullable = false)
    private int failedAttempts;

    @Column(name = "consumed_at")
    private LocalDateTime consumedAt;

    @PrePersist
    public void prePersist() {
        if (id == null) id = UUID.randomUUID().toString();
        if (createdAt == null) createdAt = LocalDateTime.now();
        if (identityType == null) identityType = IdentityType.client;
        if (purpose == null) purpose = Purpose.PASSWORD_RESET;
        if (failedAttempts < 0) failedAttempts = 0;
    }
}
