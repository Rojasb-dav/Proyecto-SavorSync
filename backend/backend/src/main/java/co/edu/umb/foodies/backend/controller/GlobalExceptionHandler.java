package co.edu.umb.foodies.backend.controller;

import org.springframework.dao.DataAccessException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.server.ResponseStatusException;

import java.time.Instant;
import java.util.Map;
import java.util.stream.Collectors;

@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(ResponseStatusException.class)
    public ResponseEntity<Map<String, Object>> handleResponseStatus(ResponseStatusException exception) {
        int status = exception.getStatusCode().value();
        String code = switch (status) {
            case 400 -> "VALIDATION_ERROR";
            case 401 -> "AUTHENTICATION_REQUIRED";
            case 403 -> "FORBIDDEN";
            case 404 -> "NOT_FOUND";
            case 409 -> "CONFLICT";
            case 413 -> "PAYLOAD_TOO_LARGE";
            case 429 -> "RATE_LIMITED";
            case 503 -> "SERVICE_UNAVAILABLE";
            default -> "REQUEST_REJECTED";
        };
        return ResponseEntity.status(status).body(body(status, code,
                exception.getReason() == null ? "No se pudo procesar la solicitud." : exception.getReason()));
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<Map<String, Object>> handleValidation(MethodArgumentNotValidException exception) {
        String message = exception.getBindingResult().getFieldErrors().stream()
                .map(field -> field.getField() + ": " + field.getDefaultMessage())
                .collect(Collectors.joining(", "));
        return ResponseEntity.badRequest().body(body(400, "VALIDATION_ERROR",
                message.isBlank() ? "Los datos proporcionados no son válidos." : message));
    }

    @ExceptionHandler(DataAccessException.class)
    public ResponseEntity<Map<String, Object>> handleDatabaseUnavailable(DataAccessException exception) {
        return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE)
                .body(body(503, "SERVICE_UNAVAILABLE",
                        "El servicio de datos no está disponible. Intenta nuevamente."));
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<Map<String, Object>> handleGeneric(Exception exception) {
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(body(500, "INTERNAL_ERROR",
                        "Ocurrió un error al procesar la solicitud. Intenta nuevamente."));
    }

    private Map<String, Object> body(int status, String code, String message) {
        return Map.of(
                "timestamp", Instant.now().toString(),
                "status", status,
                "code", code,
                "message", message
        );
    }
}