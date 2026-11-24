package co.edu.umb.foodies.backend.controller;

import co.edu.umb.foodies.backend.dto.PostDTO;
import co.edu.umb.foodies.backend.model.Comment;
import co.edu.umb.foodies.backend.model.Notification;
import co.edu.umb.foodies.backend.repository.CommentRepository;
import co.edu.umb.foodies.backend.repository.NotificationRepository;
import co.edu.umb.foodies.backend.repository.PostRepository;
import co.edu.umb.foodies.backend.repository.UserRepository;
import co.edu.umb.foodies.backend.service.PostService;
import co.edu.umb.foodies.backend.security.jwt.JwtUtil;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/posts")
@RequiredArgsConstructor
public class PostController {

    private final PostService postService;
    private final CommentRepository commentRepository;
    private final NotificationRepository notificationRepository;
    private final PostRepository postRepository;
    private final UserRepository userRepository;
    private final JwtUtil jwtUtil;

    @GetMapping
    public ResponseEntity<List<PostDTO>> getAllPosts(HttpServletRequest request) {
        String userId = getUserIdFromRequest(request);
        return ResponseEntity.ok(postService.getAllPosts(userId));
    }

    @GetMapping("/user/{userId}")
    public ResponseEntity<List<PostDTO>> getUserPosts(@PathVariable String userId, HttpServletRequest request) {
        String currentUserId = getUserIdFromRequest(request);
        return ResponseEntity.ok(postService.getUserPosts(userId, currentUserId));
    }

    @PostMapping
    public ResponseEntity<PostDTO> createPost(@RequestBody PostDTO postDTO, HttpServletRequest request) {
        String userId = getUserIdFromRequest(request);
        if (userId == null || userId.isBlank()) {
            userId = postDTO.getUserId();
        }
        return ResponseEntity.ok(postService.createPost(postDTO, userId));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deletePost(@PathVariable String id, HttpServletRequest request) {
        String userId = getUserIdFromRequest(request);
        postService.deletePost(id, userId);
        return ResponseEntity.ok().build();
    }

    @GetMapping("/{postId}/comments")
    public ResponseEntity<List<Comment>> getComments(@PathVariable String postId) {
        return ResponseEntity.ok(commentRepository.findByPostId(postId));
    }

    @PostMapping("/{postId}/comments")
    public ResponseEntity<Comment> addComment(@PathVariable String postId, @RequestBody Map<String, Object> body, HttpServletRequest request) {
        String userId = getUserIdFromRequest(request);
        String content = body.get("content") != null ? body.get("content").toString() : "";
        if (content.isBlank() && body.get("contenido") != null) {
            content = body.get("contenido").toString();
        }

        String authorId = userId != null ? userId : (body.get("authorId") != null ? body.get("authorId").toString() : "anon");

        Comment comment = Comment.builder()
                .postId(postId)
                .clienteId(authorId)
                .content(content)
                .status(Comment.CommentStatus.activo)
                .build();

        Comment savedComment = commentRepository.save(comment);

        try {
            postRepository.findById(postId).ifPresent(post -> {
                if (!post.getUser().getId().equals(authorId)) {
                    String commenterName = "Un usuario";
                    if (userId != null) {
                        commenterName = userRepository.findById(userId).map(u -> "@" + u.getUsername()).orElse("Un usuario");
                    }
                    notificationRepository.save(Notification.builder()
                            .clienteId(post.getUser().getId())
                            .type(Notification.NotificationType.comment)
                            .title("Nuevo comentario en tu reseña 💬")
                            .body(commenterName + " comentó: \"" + savedComment.getContent() + "\"")
                            .read(false)
                            .build());
                }
            });
        } catch (Exception e) {
            System.err.println("WARN: Fallo al notificar comentario: " + e.getMessage());
        }

        return ResponseEntity.ok(savedComment);
    }

    @PostMapping("/{postId}/like")
    public ResponseEntity<Void> toggleLike(@PathVariable String postId, HttpServletRequest request) {
        String userId = getUserIdFromRequest(request);
        postService.toggleLike(postId, userId);
        return ResponseEntity.ok().build();
    }

    private String getUserIdFromRequest(HttpServletRequest request) {
        String header = request.getHeader("Authorization");
        if (header != null && header.startsWith("Bearer ")) {
            return jwtUtil.getUserId(header.substring(7));
        }
        return null;
    }
}
