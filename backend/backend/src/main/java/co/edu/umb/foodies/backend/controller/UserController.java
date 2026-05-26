package co.edu.umb.foodies.backend.controller;

import co.edu.umb.foodies.backend.dto.request.UpdateProfileRequest;
import co.edu.umb.foodies.backend.dto.response.UserResponse;
import co.edu.umb.foodies.backend.service.UserService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/users")
@RequiredArgsConstructor
public class UserController {

    private final UserService userService;

    @GetMapping("/{id}")
    public ResponseEntity<UserResponse> getById(@PathVariable String id, @AuthenticationPrincipal String authUserId) {
        return ResponseEntity.ok(userService.getById(id, authUserId));
    }

    @GetMapping("/username/{username}")
    public ResponseEntity<UserResponse> getByUsername(@PathVariable String username, @AuthenticationPrincipal String authUserId) {
        return ResponseEntity.ok(userService.getByUsername(username, authUserId));
    }

    @PutMapping("/{id}")
    public ResponseEntity<UserResponse> update(@PathVariable String id,
                                               @Valid @RequestBody UpdateProfileRequest req,
                                               @AuthenticationPrincipal String authUserId) {
        return ResponseEntity.ok(userService.updateProfile(authUserId, id, req));
    }

    @PutMapping("/{id}/avatar")
    public ResponseEntity<UserResponse> updateAvatar(@PathVariable String id,
                                                     @RequestBody Map<String, String> body,
                                                     @AuthenticationPrincipal String authUserId) {
        return ResponseEntity.ok(userService.updateAvatar(authUserId, id, body.get("avatarUrl")));
    }
}
