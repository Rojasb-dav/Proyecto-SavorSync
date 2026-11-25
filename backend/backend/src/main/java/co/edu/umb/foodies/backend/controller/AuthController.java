package co.edu.umb.foodies.backend.controller;

import co.edu.umb.foodies.backend.dto.request.LoginRequest;
import co.edu.umb.foodies.backend.dto.request.RegisterRequest;
import co.edu.umb.foodies.backend.dto.response.AuthResponse;
import co.edu.umb.foodies.backend.dto.response.UserResponse;
import co.edu.umb.foodies.backend.security.jwt.JwtUtil;
import co.edu.umb.foodies.backend.service.AuthService;
import co.edu.umb.foodies.backend.service.IdentityService;
import co.edu.umb.foodies.backend.model.Pqrs;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import org.springframework.http.HttpStatus;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.CacheControl;
import org.springframework.http.HttpHeaders;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/v1/auth")
@RequiredArgsConstructor
public class AuthController {

    private final AuthService authService;
    private final IdentityService identityService;

    @PostMapping("/register")
    public ResponseEntity<AuthResponse> register(@Valid @RequestBody RegisterRequest req,
                                                 HttpServletRequest httpReq) {
        return ResponseEntity.ok().cacheControl(CacheControl.noStore()).body(authService.register(req, httpReq));
    }

    @PostMapping("/moderators")
    public ResponseEntity<UserResponse> createModerator(@Valid @RequestBody RegisterRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).cacheControl(CacheControl.noStore())
                .body(authService.createModerator(request));
    }

    @PostMapping("/email/verification")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void sendEmailVerification(@AuthenticationPrincipal String userId) {
        identityService.sendVerification(userId);
    }

    @PostMapping("/email/verify")
    public ResponseEntity<UserResponse> verifyEmail(@AuthenticationPrincipal String userId,
                                                     @Valid @RequestBody EmailCode request) {
        return ResponseEntity.ok().cacheControl(CacheControl.noStore())
                .body(identityService.verifyEmail(userId, request.code().trim()));
    }

    @PostMapping("/restaurant-admin/request")
    public ResponseEntity<Pqrs> requestRestaurantAdmin(@AuthenticationPrincipal String userId,
                                                        @Valid @RequestBody RestaurantAdminRequest request) {
        return ResponseEntity.ok().cacheControl(CacheControl.noStore())
                .body(identityService.requestRestaurantAdmin(userId, request.code().trim(), request.description()));
    }

    @PostMapping("/restaurant-admin/requests/{id}/approve")
    public ResponseEntity<UserResponse> approveRestaurantAdmin(@PathVariable String id) {
        return ResponseEntity.ok().cacheControl(CacheControl.noStore())
                .body(identityService.approveRestaurantAdmin(id));
    }

    public record EmailCode(@NotBlank @Size(max = 40) String code) {}

    public record RestaurantAdminRequest(@NotBlank @Size(max = 40) String code,
                                         @NotBlank @Size(max = 2000) String description) {}

    @PostMapping("/login")
    public ResponseEntity<AuthResponse> login(@Valid @RequestBody LoginRequest req,
                                              HttpServletRequest httpReq) {
        return ResponseEntity.ok().cacheControl(CacheControl.noStore()).body(authService.login(req, httpReq));
    }

    @GetMapping("/me")
    public ResponseEntity<UserResponse> currentUser(@AuthenticationPrincipal String userId) {
        return ResponseEntity.ok().cacheControl(CacheControl.noStore()).body(authService.currentUser(userId));
    }

    @PostMapping("/logout")
    public ResponseEntity<Map<String, String>> logout(@RequestHeader(HttpHeaders.AUTHORIZATION) String authorization) {
        authService.logout(JwtUtil.bearerToken(authorization));
        return ResponseEntity.ok(Map.of("message", "Sesión cerrada"));
    }

    @PostMapping("/forgot-password")
    public ResponseEntity<Map<String, String>> forgotPassword(@RequestBody Map<String, String> req) {
        authService.forgotPassword(req.get("email"));
        return ResponseEntity.ok(Map.of("message", "Si el correo existe, se envió un código de 6 dígitos"));
    }

    @PostMapping("/reset-password")
    public ResponseEntity<Map<String, String>> resetPassword(@RequestBody Map<String, String> req) {
        authService.resetPassword(req.get("email"), req.get("code"), req.get("newPassword"));
        return ResponseEntity.ok(Map.of("message", "Contraseña actualizada con éxito"));
    }
}
