package co.edu.umb.foodies.backend.controller;

import co.edu.umb.foodies.backend.dto.CommentDTO;
import co.edu.umb.foodies.backend.dto.PostDTO;
import co.edu.umb.foodies.backend.model.Comment;
import co.edu.umb.foodies.backend.model.Notification;
import co.edu.umb.foodies.backend.model.User;
import co.edu.umb.foodies.backend.repository.CommentRepository;
import co.edu.umb.foodies.backend.repository.NotificationRepository;
import co.edu.umb.foodies.backend.repository.PostRepository;
import co.edu.umb.foodies.backend.repository.UserRepository;
import co.edu.umb.foodies.backend.service.PostService;
import co.edu.umb.foodies.backend.security.jwt.JwtUtil;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;

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
    public ResponseEntity<List<CommentDTO>> getComments(@PathVariable String postId) {
        try {
            List<Comment> comments = commentRepository.findByPostId(postId);
            if (comments == null || comments.isEmpty()) {
                return ResponseEntity.ok(List.of());
            }
            List<CommentDTO> dtos = comments.stream()
                    .filter(c -> c != null)
                    .map(c -> {
                        User author = null;
                        if (c.getClienteId() != null && !c.getClienteId().isBlank()) {
                            try {
                                author = userRepository.findById(c.getClienteId()).orElse(null);
                            } catch (Exception ignored) {}
                        }
                        return CommentDTO.from(c, author);
                    })
                    .collect(Collectors.toList());
            return ResponseEntity.ok(dtos);
        } catch (Exception e) {
            System.err.println("ERROR en getComments para postId " + postId + ": " + e.getMessage());
            return ResponseEntity.ok(List.of());
        }
    }

    @PostMapping("/{postId}/comments")
    public ResponseEntity<CommentDTO> addComment(@PathVariable String postId, @RequestBody Map<String, Object> body, HttpServletRequest request) {
        try {
            String userId = getUserIdFromRequest(request);
            String content = body.get("content") != null ? body.get("content").toString() : "";
            if (content.isBlank() && body.get("contenido") != null) {
                content = body.get("contenido").toString();
            }

            String authorId = userId != null && !userId.isBlank() ? userId : (body.get("authorId") != null ? body.get("authorId").toString() : null);

            if (authorId == null || authorId.isBlank() || "anon".equalsIgnoreCase(authorId)) {
                User fallbackUser = userRepository.findAll().stream().findFirst().orElse(null);
                if (fallbackUser != null) {
                    authorId = fallbackUser.getId();
                }
            }

            if (authorId == null) {
                throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Debes iniciar sesión para comentar");
            }

            User author = userRepository.findById(authorId).orElse(null);
            if (author == null) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Usuario autor no encontrado");
            }

            Comment comment = Comment.builder()
                    .id(UUID.randomUUID().toString())
                    .postId(postId)
                    .clienteId(author.getId())
                    .content(content)
                    .status("activo")
                    .createdAt(LocalDateTime.now())
                    .updatedAt(LocalDateTime.now())
                    .build();

            Comment savedComment = commentRepository.save(comment);

            try {
                postRepository.findById(postId).ifPresent(post -> {
                    if (post.getUser() != null && !post.getUser().getId().equals(author.getId())) {
                        notificationRepository.save(Notification.builder()
                                .id(UUID.randomUUID().toString())
                                .clienteId(post.getUser().getId())
                                .type(Notification.NotificationType.comentario)
                                .title("Nuevo comentario en tu reseña 💬")
                                .body("@" + author.getUsername() + " comentó: \"" + savedComment.getContent() + "\"")
                                .read(false)
                                .channel(Notification.Channel.in_app)
                                .createdAt(LocalDateTime.now())
                                .build());
                    }
                });
            } catch (Exception e) {
                System.err.println("WARN: Fallo al notificar comentario: " + e.getMessage());
            }

            return ResponseEntity.ok(CommentDTO.from(savedComment, author));
        } catch (ResponseStatusException rse) {
            throw rse;
        } catch (Exception e) {
            System.err.println("ERROR al agregar comentario: " + e.getMessage());
            throw new ResponseStatusException(HttpStatus.INTERNAL_SERVER_ERROR, "Error al procesar comentario: " + e.getMessage());
        }
    }

    @PostMapping("/{postId}/like")
    public ResponseEntity<Void> toggleLike(@PathVariable String postId, HttpServletRequest request) {
        try {
            String userId = getUserIdFromRequest(request);
            if (userId == null || userId.isBlank()) {
                User fallbackUser = userRepository.findAll().stream().findFirst().orElse(null);
                if (fallbackUser != null) {
                    userId = fallbackUser.getId();
                }
            }
            if (userId != null && !userId.isBlank()) {
                postService.toggleLike(postId, userId);
            }
            return ResponseEntity.ok().build();
        } catch (Exception e) {
            System.err.println("ERROR al dar like: " + e.getMessage());
            return ResponseEntity.ok().build();
        }
    }

    private String getUserIdFromRequest(HttpServletRequest request) {
        String header = request.getHeader("Authorization");
        if (header != null && header.startsWith("Bearer ")) {
            return jwtUtil.getUserId(header.substring(7));
        }
        return null;
    }
}
