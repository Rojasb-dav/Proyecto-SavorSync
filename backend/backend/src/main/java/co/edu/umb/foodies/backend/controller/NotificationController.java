package co.edu.umb.foodies.backend.controller;

import co.edu.umb.foodies.backend.model.Notification;
import co.edu.umb.foodies.backend.repository.NotificationRepository;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/notifications")
@RequiredArgsConstructor
public class NotificationController {

    private final NotificationRepository notificationRepository;

    @GetMapping
    public ResponseEntity<List<Notification>> getNotifications(@RequestParam(required = false) String userId,
                                                                  HttpServletRequest request) {
        String owner = request.getUserPrincipal().getName();
        if (userId != null && !owner.equals(userId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "No puedes consultar notificaciones ajenas");
        }
        return ResponseEntity.ok(notificationRepository.findByClienteId(owner));
    }

    @PostMapping
    public ResponseEntity<Notification> createNotification(@RequestBody Notification notification) {
        notification.setId(null);
        return ResponseEntity.status(HttpStatus.CREATED).body(notificationRepository.save(notification));
    }

    @Transactional
    @PutMapping("/{id}/read")
    public ResponseEntity<Notification> markRead(@PathVariable String id, HttpServletRequest request) {
        String owner = request.getUserPrincipal().getName();
        return notificationRepository.findByIdAndClienteId(id, owner).map(n -> {
            n.setRead(true);
            return ResponseEntity.ok(n);
        }).orElse(ResponseEntity.notFound().build());
    }

    @Transactional
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteNotification(@PathVariable String id, HttpServletRequest request) {
        String owner = request.getUserPrincipal().getName();
        var notification = notificationRepository.findByIdAndClienteId(id, owner)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Notificación no encontrada"));
        notificationRepository.delete(notification);
        return ResponseEntity.noContent().build();
    }
}
