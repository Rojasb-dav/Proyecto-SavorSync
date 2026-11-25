package co.edu.umb.foodies.backend.controller;

import co.edu.umb.foodies.backend.dto.request.EmailVerificationRequest;
import co.edu.umb.foodies.backend.dto.request.ForgotPasswordRequest;
import co.edu.umb.foodies.backend.dto.request.LoginRequest;
import co.edu.umb.foodies.backend.dto.request.RegisterRequest;
import co.edu.umb.foodies.backend.dto.request.ResetPasswordRequest;
import co.edu.umb.foodies.backend.dto.response.AuthResponse;
import co.edu.umb.foodies.backend.dto.response.RegistrationResponse;
import co.edu.umb.foodies.backend.dto.response.UserResponse;
import co.edu.umb.foodies.backend.model.Pqrs;
import co.edu.umb.foodies.backend.security.jwt.JwtUtil;
import co.edu.umb.foodies.backend.service.AuthService;
import co.edu.umb.foodies.backend.service.IdentityService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.RequiredArgsConstructor;
import org.springframework.http.CacheControl;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.web.server.ResponseStatusException;

import java.util.Map;

@RestController
@RequestMapping("/api/v1/auth")
@RequiredArgsConstructor
public class AuthController {

    private final AuthService authService;
    private final IdentityService identityService;

    @PostMapping("/register")
    public ResponseEntity<RegistrationResponse> register(@Valid @RequestBody RegisterRequest request,
                                                          HttpServletRequest httpRequest) {
        return ResponseEntity.status(HttpStatus.ACCEPTED).cacheControl(CacheControl.noStore())
                .body(authService.register(request, httpRequest));
    }

    @PostMapping("/moderators")
    public ResponseEntity<UserResponse> createModerator(@Valid @RequestBody RegisterRequest request,
                                                         HttpServletRequest httpRequest) {
        return ResponseEntity.status(HttpStatus.CREATED).cacheControl(CacheControl.noStore())
                .body(authService.createModerator(request, httpRequest));
    }

    @PostMapping("/email/verification")
    public ResponseEntity<RegistrationResponse> sendEmailVerification(
            @Valid @RequestBody EmailVerificationRequest request,
            HttpServletRequest httpRequest) {
        if (request.isVerifyRequest()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "Usa la operación de verificación para validar un código.");
        }
        return ResponseEntity.accepted().cacheControl(CacheControl.noStore())
                .body(authService.requestEmailVerification(request, httpRequest));
    }

    @PostMapping("/email/verify")
    public ResponseEntity<AuthResponse> verifyEmail(@Valid @RequestBody EmailVerificationRequest request,
                                                     HttpServletRequest httpRequest) {
        if (!request.isVerifyRequest()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "Se requieren el identificador del desafío y el código de seis dígitos.");
        }
        AuthResponse response = authService.verifyEmail(request.challengeId(), request.code(), httpRequest);
        if (response == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "El código no es válido o expiró.");
        }
        return ResponseEntity.ok().cacheControl(CacheControl.noStore()).body(response);
    }

    @PostMapping("/restaurant-admin/request")
    public ResponseEntity<Pqrs> requestRestaurantAdmin(@AuthenticationPrincipal String userId,
                                                        @Valid @RequestBody RestaurantAdminRequest request) {
        return ResponseEntity.status(HttpStatus.ACCEPTED).cacheControl(CacheControl.noStore())
                .body(identityService.requestRestaurantAdmin(userId, request.description()));
    }

    @PostMapping("/restaurant-admin/requests/{id}/approve")
    public ResponseEntity<UserResponse> approveRestaurantAdmin(@PathVariable String id) {
        return ResponseEntity.ok().cacheControl(CacheControl.noStore())
                .body(identityService.approveRestaurantAdmin(id));
    }

    @PostMapping("/login")
    public ResponseEntity<AuthResponse> login(@Valid @RequestBody LoginRequest request,
                                              HttpServletRequest httpRequest) {
        return ResponseEntity.ok().cacheControl(CacheControl.noStore())
                .body(authService.login(request, httpRequest));
    }

    @GetMapping("/me")
    public ResponseEntity<UserResponse> currentUser(@AuthenticationPrincipal String userId) {
        return ResponseEntity.ok().cacheControl(CacheControl.noStore())
                .body(authService.currentUser(userId));
    }

    @PostMapping("/logout")
    public ResponseEntity<Map<String, String>> logout(
            @RequestHeader(HttpHeaders.AUTHORIZATION) String authorization) {
        authService.logout(JwtUtil.bearerToken(authorization));
        return ResponseEntity.ok().cacheControl(CacheControl.noStore())
                .body(Map.of("message", "Sesión cerrada"));
    }

    @PostMapping("/forgot-password")
    public ResponseEntity<Map<String, String>> forgotPassword(
            @Valid @RequestBody ForgotPasswordRequest request,
            HttpServletRequest httpRequest) {
        authService.forgotPassword(request.email(), httpRequest);
        return ResponseEntity.accepted().cacheControl(CacheControl.noStore())
                .body(Map.of("message", "Si el correo existe, se enviará un código."));
    }

    @PostMapping("/reset-password")
    public ResponseEntity<Map<String, String>> resetPassword(
            @Valid @RequestBody ResetPasswordRequest request) {
        if (!authService.resetPassword(request.email(), request.code(), request.newPassword())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "El código no es válido, expiró o la contraseña no cumple los requisitos.");
        }
        return ResponseEntity.ok().cacheControl(CacheControl.noStore())
                .body(Map.of("message", "Contraseña actualizada. Inicia sesión nuevamente."));
    }

    public record RestaurantAdminRequest(
            @NotBlank @Size(max = 2000) String description
    ) {}
}