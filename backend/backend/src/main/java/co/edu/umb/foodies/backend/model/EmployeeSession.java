package co.edu.umb.foodies.backend.model;

import jakarta.persistence.*;
import java.time.Instant;
import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "sesiones_empleado")
public class EmployeeSession {

    public enum Platform {
        web_admin, web_moderacion
    }

    @Id
    @Column(length = 36, columnDefinition = "CHAR(36)", nullable = false, updatable = false)
    private String id;

    @Column(name = "empleado_id", length = 36, columnDefinition = "CHAR(36)", nullable = false)
    private String employeeId;

    @Column(name = "session_token", nullable = false, length = 191)
    private String sessionToken;

    @Enumerated(EnumType.STRING)
    @Column(name = "plataforma", nullable = false, columnDefinition = "ENUM('web_admin','web_moderacion')")
    private Platform platform;

    @Column(name = "ip_address", length = 45)
    private String ipAddress;

    @Column(name = "expires_at", nullable = false)
    private Instant expiresAt;

    @Column(name = "activa", nullable = false)
    private Boolean isActive;

    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    public EmployeeSession() {}

    public EmployeeSession(String id, String employeeId, String sessionToken, Platform platform, String ipAddress, Instant expiresAt, Boolean isActive, LocalDateTime createdAt, LocalDateTime updatedAt) {
        this.id = id;
        this.employeeId = employeeId;
        this.sessionToken = sessionToken;
        this.platform = platform;
        this.ipAddress = ipAddress;
        this.expiresAt = expiresAt;
        this.isActive = isActive;
        this.createdAt = createdAt;
        this.updatedAt = updatedAt;
    }

    public static EmployeeSessionBuilder builder() {
        return new EmployeeSessionBuilder();
    }

    public static class EmployeeSessionBuilder {
        private String id;
        private String employeeId;
        private String sessionToken;
        private Platform platform;
        private String ipAddress;
        private Instant expiresAt;
        private Boolean isActive;
        private LocalDateTime createdAt;
        private LocalDateTime updatedAt;

        public EmployeeSessionBuilder id(String id) { this.id = id; return this; }
        public EmployeeSessionBuilder employeeId(String employeeId) { this.employeeId = employeeId; return this; }
        public EmployeeSessionBuilder sessionToken(String sessionToken) { this.sessionToken = sessionToken; return this; }
        public EmployeeSessionBuilder platform(Platform platform) { this.platform = platform; return this; }
        public EmployeeSessionBuilder ipAddress(String ipAddress) { this.ipAddress = ipAddress; return this; }
        public EmployeeSessionBuilder expiresAt(Instant expiresAt) { this.expiresAt = expiresAt; return this; }
        public EmployeeSessionBuilder isActive(Boolean isActive) { this.isActive = isActive; return this; }
        public EmployeeSessionBuilder createdAt(LocalDateTime createdAt) { this.createdAt = createdAt; return this; }
        public EmployeeSessionBuilder updatedAt(LocalDateTime updatedAt) { this.updatedAt = updatedAt; return this; }

        public EmployeeSession build() {
            return new EmployeeSession(id, employeeId, sessionToken, platform, ipAddress, expiresAt, isActive, createdAt, updatedAt);
        }
    }

    public String getId() { return id; }
    public void setId(String id) { this.id = id; }

    public String getEmployeeId() { return employeeId; }
    public void setEmployeeId(String employeeId) { this.employeeId = employeeId; }

    public String getSessionToken() { return sessionToken; }
    public void setSessionToken(String sessionToken) { this.sessionToken = sessionToken; }

    public Platform getPlatform() { return platform; }
    public void setPlatform(Platform platform) { this.platform = platform; }

    public String getIpAddress() { return ipAddress; }
    public void setIpAddress(String ipAddress) { this.ipAddress = ipAddress; }

    public Instant getExpiresAt() { return expiresAt; }
    public void setExpiresAt(Instant expiresAt) { this.expiresAt = expiresAt; }

    public Boolean getIsActive() { return isActive; }
    public void setIsActive(Boolean isActive) { this.isActive = isActive; }

    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }

    public LocalDateTime getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(LocalDateTime updatedAt) { this.updatedAt = updatedAt; }

    @PrePersist
    public void prePersist() {
        if (id == null) id = UUID.randomUUID().toString();
        if (isActive == null) isActive = true;
        if (platform == null) platform = Platform.web_admin;
        LocalDateTime now = LocalDateTime.now();
        if (createdAt == null) createdAt = now;
        updatedAt = now;
    }

    @PreUpdate
    public void preUpdate() {
        updatedAt = LocalDateTime.now();
    }
}
