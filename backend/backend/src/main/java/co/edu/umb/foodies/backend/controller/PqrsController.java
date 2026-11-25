package co.edu.umb.foodies.backend.controller;

import co.edu.umb.foodies.backend.model.Notification;
import co.edu.umb.foodies.backend.model.Pqrs;
import co.edu.umb.foodies.backend.repository.NotificationRepository;
import co.edu.umb.foodies.backend.repository.PqrsRepository;
import co.edu.umb.foodies.backend.service.IdentityService;
import org.springframework.transaction.annotation.Transactional;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/pqrs")
@RequiredArgsConstructor
public class PqrsController {

    private final PqrsRepository pqrsRepository;
    private final NotificationRepository notificationRepository;

    @GetMapping
    public ResponseEntity<List<Pqrs>> getAllPqrs(@RequestParam(required = false) String userId,
                                                  HttpServletRequest request) {
        if (request.isUserInRole("MODERADOR") || request.isUserInRole("ADMIN_SISTEMA")) {
            return ResponseEntity.ok(userId == null || userId.isBlank()
                    ? pqrsRepository.findAll() : pqrsRepository.findByClienteId(userId));
        }
        String owner = request.getUserPrincipal().getName();
        if (userId != null && !userId.isBlank() && !owner.equals(userId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "No puedes consultar PQRS ajenas");
        }
        return ResponseEntity.ok(pqrsRepository.findByClienteId(owner));
    }

    @PostMapping
    public ResponseEntity<Pqrs> createPqrs(@RequestBody Pqrs pqrs, HttpServletRequest request) {
        if (IdentityService.isRestaurantRequest(pqrs.getAsunto())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Usa la solicitud de restaurante desde tu perfil");
        }
        var created = Pqrs.builder()
                .clienteId(request.getUserPrincipal().getName())
                .tipo(pqrs.getTipo())
                .asunto(pqrs.getAsunto())
                .descripcion(pqrs.getDescripcion())
                .estado(Pqrs.PqrsStatus.recibida)
                .build();
        return ResponseEntity.status(HttpStatus.CREATED).body(pqrsRepository.save(created));
    }

    @Transactional
    @PutMapping("/{id}")
    public ResponseEntity<Pqrs> updatePqrsStatus(@PathVariable String id, @RequestBody Pqrs body,
                                                 HttpServletRequest request) {
        return pqrsRepository.findByIdForUpdate(id).map(p -> {
            if (IdentityService.isRestaurantRequest(p.getAsunto()) && !request.isUserInRole("ADMIN_SISTEMA")) {
                throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Esta solicitud requiere administración del sistema");
            }

            Pqrs.PqrsStatus oldStatus = p.getEstado();
            if (body.getEstado() != null) p.setEstado(body.getEstado());
            if (body.getRespuesta() != null) p.setRespuesta(body.getRespuesta());

            if (p.getEstado() != oldStatus && (p.getEstado() == Pqrs.PqrsStatus.resuelta || p.getEstado() == Pqrs.PqrsStatus.en_gestion)) {
                p.setEmpleadoId(request.getUserPrincipal().getName());
                p.setFechaGestion(LocalDateTime.now());
                if (p.getEstado() == Pqrs.PqrsStatus.resuelta) {
                    p.setFechaCierre(LocalDateTime.now());
                }

                try {
                    Notification n = Notification.builder()
                            .id(UUID.randomUUID().toString())
                            .clienteId(p.getClienteId())
                            .type(Notification.NotificationType.pqrs)
                            .title("Actualización de PQRS: " + p.getEstado())
                            .body("Tu caso '" + p.getAsunto() + "' ha sido " + p.getEstado() + ". Respuesta: " + (p.getRespuesta() != null ? p.getRespuesta() : "En gestión interna."))
                            .read(false)
                            .channel(Notification.Channel.in_app)
                            .createdAt(LocalDateTime.now())
                            .build();
                    notificationRepository.save(n);
                } catch (Exception e) {
                    System.err.println("WARN: Fallo al notificar PQRS: " + e.getMessage());
                }
            }

            return ResponseEntity.ok(pqrsRepository.save(p));
        }).orElse(ResponseEntity.notFound().build());
    }
}
