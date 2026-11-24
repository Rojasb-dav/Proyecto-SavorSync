package co.edu.umb.foodies.backend.controller;

import co.edu.umb.foodies.backend.service.CloudinaryService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.server.ResponseStatusException;

import java.io.IOException;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/files")
public class FileController {

    @Autowired
    private CloudinaryService cloudinaryService;

    @PostMapping("/upload")
    public ResponseEntity<Map<String, String>> uploadFile(@RequestParam("file") MultipartFile file) throws IOException {
        if (file == null || file.isEmpty()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "El archivo proporcionado está vacío.");
        }

        // FALLO-27 Fix: Validación de tamaño (Max 10MB) y tipo MIME permitido
        if (file.getSize() > 10 * 1024 * 1024) {
            throw new ResponseStatusException(HttpStatus.PAYLOAD_TOO_LARGE, "El archivo excede el tamaño máximo permitido (10 MB).");
        }

        String contentType = file.getContentType();
        if (contentType != null && !contentType.startsWith("image/") && !contentType.startsWith("application/octet-stream")) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Formato de archivo no soportado. Sólo se permiten imágenes.");
        }

        String fileUrl = cloudinaryService.uploadFile(file);
        return ResponseEntity.ok(Map.of("url", fileUrl));
    }
}
