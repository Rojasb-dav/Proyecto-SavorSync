package co.edu.umb.foodies.backend.dto.response;

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

    public static UserResponse from(User u, String currentUserId) {
        boolean isFollowing = false;
        if (currentUserId != null && u.getFollowers() != null) {
            isFollowing = u.getFollowers().stream()
                    .anyMatch(follower -> follower.getId().equals(currentUserId));
        }

        return UserResponse.builder()
                .id(u.getId())
                .email(u.getEmail())
                .username(u.getUsername())
                .fullName(u.getFullName())
                .role(u.getRole() != null ? u.getRole().name() : null)
                .avatarUrl(u.getAvatarUrl())
                .bio(u.getBio())
                .phone(u.getPhone())
                .isActive(u.getIsActive())
                .emailVerified(u.getEmailVerified())
                .createdAt(u.getCreatedAt())
                .updatedAt(u.getUpdatedAt())
                .followersCount(u.getFollowers() != null ? u.getFollowers().size() : 0)
                .followingCount(u.getFollowing() != null ? u.getFollowing().size() : 0)
                .postsCount(u.getPosts() != null ? u.getPosts().size() : 0)
                .isFollowing(currentUserId != null ? isFollowing : null)
                .build();
    }
}
