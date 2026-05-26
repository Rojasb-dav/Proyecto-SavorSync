package co.edu.umb.foodies.backend.controller;

import co.edu.umb.foodies.backend.dto.request.LoginRequest;
import co.edu.umb.foodies.backend.dto.request.RegisterRequest;
import co.edu.umb.foodies.backend.dto.response.AuthResponse;
import co.edu.umb.foodies.backend.service.AuthService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/auth")
@RequiredArgsConstructor
public class AuthController {

    private final AuthService authService;

    @PostMapping("/register")
    public ResponseEntity<AuthResponse> register(@Valid @RequestBody RegisterRequest req,
                                                 HttpServletRequest httpReq) {
        return ResponseEntity.ok(authService.register(req, httpReq));
    }

    @PostMapping("/login")
    public ResponseEntity<AuthResponse> login(@Valid @RequestBody LoginRequest req,
                                              HttpServletRequest httpReq) {
        return ResponseEntity.ok(authService.login(req, httpReq));
    }

    @PostMapping("/logout")
    public ResponseEntity<Map<String, String>> logout(HttpServletRequest httpReq) {
        String header = httpReq.getHeader("Authorization");
        String token = (header != null && header.startsWith("Bearer ")) ? header.substring(7) : null;
        authService.logout(token);
        return ResponseEntity.ok(Map.of("message", "Sesión cerrada"));
    }
}
