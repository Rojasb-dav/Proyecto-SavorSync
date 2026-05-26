package co.edu.umb.foodies.backend.dto;

import lombok.*;

import java.time.LocalDateTime;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class PostDTO {
    private String id;
    private String userId;
    private String username;
    private String fullName;
    private String userAvatarUrl;
    private String restaurantName;
    private String restaurantAddress;
    private String content;
    private Double rating;
    private String imageUrl;
    private int likesCount;
    private int commentsCount;
    private boolean likedByMe;
    private boolean savedByMe;
    private LocalDateTime createdAt;
}
