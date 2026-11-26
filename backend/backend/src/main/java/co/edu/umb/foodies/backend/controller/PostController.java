package co.edu.umb.foodies.backend.controller;

import co.edu.umb.foodies.backend.dto.CommentDTO;
import co.edu.umb.foodies.backend.dto.PostDTO;
import co.edu.umb.foodies.backend.service.PostService;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/posts")
@RequiredArgsConstructor
public class PostController {

    private final PostService postService;

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
        return ResponseEntity.status(HttpStatus.CREATED).body(postService.createPost(postDTO, request.getUserPrincipal().getName()));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deletePost(@PathVariable String id, HttpServletRequest request) {
        String userId = getUserIdFromRequest(request);
        postService.deletePost(id, userId);
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/{postId}/comments")
    public ResponseEntity<List<CommentDTO>> getComments(@PathVariable String postId, HttpServletRequest request) {
        return ResponseEntity.ok(postService.getComments(postId, getUserIdFromRequest(request)));
    }

    @PostMapping("/{postId}/comments")
    public ResponseEntity<CommentDTO> addComment(@PathVariable String postId, @RequestBody Map<String, Object> body, HttpServletRequest request) {
        String userId = request.getUserPrincipal().getName();

        String content = body.get("content") != null ? body.get("content").toString() : "";
        if (content.isBlank() && body.get("contenido") != null) {
            content = body.get("contenido").toString();
        }

        String parentId = body.get("parentId") == null ? null : body.get("parentId").toString();
        if (parentId != null && (parentId.isBlank() || parentId.length() > 36)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Identificador de comentario padre inválido.");
        }
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(postService.addComment(postId, userId, content, parentId));
    }

    @PostMapping("/{postId}/like")
    public ResponseEntity<Void> toggleLike(@PathVariable String postId, HttpServletRequest request) {
        postService.toggleLike(postId, request.getUserPrincipal().getName());
        return ResponseEntity.ok().build();
    }

    private String getUserIdFromRequest(HttpServletRequest request) {
        var principal = request == null ? null : request.getUserPrincipal();
        return principal == null ? null : principal.getName();
    }
}
