package co.edu.umb.foodies.backend.dto;

import co.edu.umb.foodies.backend.model.Comment;
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
public class CommentDTO {
    private String id;
    private String postId;
    private String authorId;
    private String authorName;
    private String authorAvatarUrl;
    private String content;
    private LocalDateTime createdAt;

    public static CommentDTO from(Comment comment, User user) {
        if (comment == null) return null;
        return CommentDTO.builder()
                .id(comment.getId())
                .postId(comment.getPostId())
                .authorId(comment.getClienteId() != null ? comment.getClienteId() : "")
                .authorName(user != null && user.getUsername() != null ? user.getUsername() : "Usuario")
                .authorAvatarUrl(user != null ? user.getAvatarUrl() : null)
                .content(comment.getContent() != null ? comment.getContent() : "")
                .createdAt(comment.getCreatedAt() != null ? comment.getCreatedAt() : LocalDateTime.now())
                .build();
    }
}
