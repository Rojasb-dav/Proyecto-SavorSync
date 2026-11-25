package co.edu.umb.foodies.backend.controller;

import co.edu.umb.foodies.backend.service.UserService;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/follows")
@RequiredArgsConstructor
public class FollowController {

    private final UserService userService;

    @PostMapping("/{userId}")
    public ResponseEntity<Void> follow(@PathVariable String userId, HttpServletRequest request) {
        userService.follow(request.getUserPrincipal().getName(), userId);
        return ResponseEntity.ok().build();
    }

    @DeleteMapping("/{userId}")
    public ResponseEntity<Void> unfollow(@PathVariable String userId, HttpServletRequest request) {
        userService.unfollow(request.getUserPrincipal().getName(), userId);
        return ResponseEntity.ok().build();
    }

}
