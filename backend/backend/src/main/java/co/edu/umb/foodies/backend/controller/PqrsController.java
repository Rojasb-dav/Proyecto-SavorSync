package co.edu.umb.foodies.backend.controller;

import co.edu.umb.foodies.backend.model.Pqrs;
import co.edu.umb.foodies.backend.repository.PqrsRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/pqrs")
@RequiredArgsConstructor
public class PqrsController {

    private final PqrsRepository pqrsRepository;

    @GetMapping
    public ResponseEntity<List<Pqrs>> getAllPqrs(@RequestParam(required = false) String userId) {
        if (userId != null && !userId.isBlank()) {
            return ResponseEntity.ok(pqrsRepository.findByClienteId(userId));
        }
        return ResponseEntity.ok(pqrsRepository.findAll());
    }

    @PostMapping
    public ResponseEntity<Pqrs> createPqrs(@RequestBody Pqrs pqrs) {
        return ResponseEntity.ok(pqrsRepository.save(pqrs));
    }

    @PutMapping("/{id}")
    public ResponseEntity<Pqrs> updatePqrsStatus(@PathVariable String id, @RequestBody Pqrs body) {
        return pqrsRepository.findById(id).map(p -> {
            if (body.getEstado() != null) p.setEstado(body.getEstado());
            if (body.getRespuesta() != null) p.setRespuesta(body.getRespuesta());
            return ResponseEntity.ok(pqrsRepository.save(p));
        }).orElse(ResponseEntity.notFound().build());
    }
}
