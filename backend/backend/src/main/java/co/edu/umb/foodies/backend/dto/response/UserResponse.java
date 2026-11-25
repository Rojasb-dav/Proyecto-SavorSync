package co.edu.umb.foodies.backend.dto.response;

import co.edu.umb.foodies.backend.model.Employee;
import co.edu.umb.foodies.backend.model.User;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class UserResponse {
    private String id;
    private String email;
    private String username;
    private String fullName;
    private String role;
    private String avatarUrl;
    private String bio;
    private String phone;
    private Boolean isActive;
    private Boolean emailVerified;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
    private int followersCount;
    private int followingCount;
    private int postsCount;
    private Boolean isFollowing;

    public static UserResponse from(User u) {
        return from(u, null);
    }

    public static UserResponse from(Employee e) {
        if (e == null) return null;
        return UserResponse.builder()
                .id(e.getId())
                .email(e.getEmail())
                .username(e.getUsername())
                .fullName(e.getFullName())
                .role(e.getRole() != null ? e.getRole().name() : null)
                .isActive(e.getIsActive())
                .emailVerified(true)
                .createdAt(e.getCreatedAt())
                .updatedAt(e.getUpdatedAt())
                .build();
    }

    public static UserResponse from(User u, String currentUserId) {
        if (u == null) return null;

        // P1.9 Fix: Proteger email y teléfono si el que consulta no es el dueño ni un empleado admin
        boolean isOwnerOrAdmin = currentUserId != null && currentUserId.equals(u.getId());
        String safeEmail = isOwnerOrAdmin ? u.getEmail() : null;
        String safePhone = isOwnerOrAdmin ? u.getPhone() : null;

        boolean isFollowing = false;
        try {
            if (currentUserId != null && u.getFollowers() != null) {
                isFollowing = u.getFollowers().stream()
                        .anyMatch(follower -> follower != null && currentUserId.equals(follower.getId()));
            }
        } catch (Exception ignored) {}

        int followersCount = 0;
        try {
            if (u.getFollowers() != null) {
                followersCount = u.getFollowers().size();
            }
        } catch (Exception ignored) {}

        int followingCount = 0;
        try {
            if (u.getFollowing() != null) {
                followingCount = u.getFollowing().size();
            }
        } catch (Exception ignored) {}

        int postsCount = 0;
        try {
            if (u.getPosts() != null) {
                postsCount = u.getPosts().size();
            }
        } catch (Exception ignored) {}

        return UserResponse.builder()
                .id(u.getId())
                .email(safeEmail)
                .username(u.getUsername())
                .fullName(u.getFullName())
                .role(u.getRole() != null ? u.getRole().name() : null)
                .avatarUrl(u.getAvatarUrl())
                .bio(u.getBio())
                .phone(safePhone)
                .isActive(u.getIsActive())
                .emailVerified(u.getEmailVerified())
                .createdAt(u.getCreatedAt())
                .updatedAt(u.getUpdatedAt())
                .followersCount(followersCount)
                .followingCount(followingCount)
                .postsCount(postsCount)
                .isFollowing(currentUserId != null ? isFollowing : null)
                .build();
    }
}
