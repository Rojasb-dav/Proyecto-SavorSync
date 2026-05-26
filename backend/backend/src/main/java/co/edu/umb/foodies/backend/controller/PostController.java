package co.edu.umb.foodies.backend.controller;

import co.edu.umb.foodies.backend.dto.PostDTO;
import co.edu.umb.foodies.backend.service.PostService;
import co.edu.umb.foodies.backend.security.jwt.JwtUtil;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.bind.annotation.DeleteMapping;

import java.util.List;

@RestController
@RequestMapping("/api/posts")
@RequiredArgsConstructor
public class PostController {

    private final PostService postService;
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
        return ResponseEntity.ok(postService.createPost(postDTO, userId));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deletePost(@PathVariable String id, HttpServletRequest request) {
        String userId = getUserIdFromRequest(request);
        postService.deletePost(id, userId);
        return ResponseEntity.ok().build();
    }

    private String getUserIdFromRequest(HttpServletRequest request) {
        String token = request.getHeader("Authorization").substring(7);
        return jwtUtil.getUserId(token);
    }
}
