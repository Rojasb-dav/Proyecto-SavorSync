package co.edu.umb.foodies.backend.controller;

import co.edu.umb.foodies.backend.security.jwt.JwtUtil;
import co.edu.umb.foodies.backend.service.UserService;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/follows")
@RequiredArgsConstructor
public class FollowController {

    private final UserService userService;
    private final JwtUtil jwtUtil;

    @PostMapping("/{userId}")
    public ResponseEntity<Void> follow(@PathVariable String userId, HttpServletRequest request) {
        String followerId = getUserIdFromRequest(request);
        userService.follow(followerId, userId);
        return ResponseEntity.ok().build();
    }

    @DeleteMapping("/{userId}")
    public ResponseEntity<Void> unfollow(@PathVariable String userId, HttpServletRequest request) {
        String followerId = getUserIdFromRequest(request);
        userService.unfollow(followerId, userId);
        return ResponseEntity.ok().build();
    }

    private String getUserIdFromRequest(HttpServletRequest request) {
        String token = request.getHeader("Authorization").substring(7);
        return jwtUtil.getUserId(token);
    }
}
