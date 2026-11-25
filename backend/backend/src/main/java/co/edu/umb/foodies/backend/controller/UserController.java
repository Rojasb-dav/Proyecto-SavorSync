package co.edu.umb.foodies.backend.controller;

import co.edu.umb.foodies.backend.dto.request.UpdateProfileRequest;
import co.edu.umb.foodies.backend.dto.response.UserResponse;
import co.edu.umb.foodies.backend.service.UserService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/users")
@RequiredArgsConstructor
public class UserController {

    private final UserService userService;

    @GetMapping
    public ResponseEntity<List<UserResponse>> getAllUsers(HttpServletRequest request) {
        String authUserId = getUserIdFromRequest(request);
        return ResponseEntity.ok(userService.getAllUsers(authUserId));
    }

    @GetMapping("/{id}")
    public ResponseEntity<UserResponse> getById(@PathVariable String id, HttpServletRequest request) {
        String authUserId = getUserIdFromRequest(request);
        return ResponseEntity.ok(userService.getById(id, authUserId));
    }

    @GetMapping("/username/{username}")
    public ResponseEntity<UserResponse> getByUsername(@PathVariable String username, HttpServletRequest request) {
        String authUserId = getUserIdFromRequest(request);
        return ResponseEntity.ok(userService.getByUsername(username, authUserId));
    }

    @PutMapping("/{id}")
    public ResponseEntity<UserResponse> update(@PathVariable String id,
                                               @Valid @RequestBody UpdateProfileRequest req,
                                               HttpServletRequest request) {
        String authUserId = getUserIdFromRequest(request);
        if (authUserId == null || authUserId.isBlank()) {
            authUserId = id;
        }
        return ResponseEntity.ok(userService.updateProfile(authUserId, id, req));
    }

    @PutMapping("/{id}/avatar")
    public ResponseEntity<UserResponse> updateAvatar(@PathVariable String id,
                                                     @RequestBody Map<String, String> body,
                                                     HttpServletRequest request) {
        String authUserId = getUserIdFromRequest(request);
        if (authUserId == null || authUserId.isBlank()) {
            authUserId = id;
        }
        return ResponseEntity.ok(userService.updateAvatar(authUserId, id, body.get("avatarUrl")));
    }

    @PutMapping({"/{id}/status", "/{id}/toggle-active"})
    public ResponseEntity<UserResponse> toggleUserStatus(@PathVariable String id) {
        return ResponseEntity.ok(userService.toggleUserStatus(id));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteUser(@PathVariable String id) {
        userService.deleteUser(id);
        return ResponseEntity.noContent().build();
    }

    private String getUserIdFromRequest(HttpServletRequest request) {
        var principal = request == null ? null : request.getUserPrincipal();
        return principal == null ? null : principal.getName();
    }
}
