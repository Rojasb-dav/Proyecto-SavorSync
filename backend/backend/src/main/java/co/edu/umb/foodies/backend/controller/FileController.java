package co.edu.umb.foodies.backend.controller;

import co.edu.umb.foodies.backend.service.CloudinaryAssetRegistry;
import co.edu.umb.foodies.backend.service.CloudinaryService;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.dao.DataAccessException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.server.ResponseStatusException;

import javax.imageio.ImageIO;
import javax.imageio.ImageReader;
import javax.imageio.stream.ImageInputStream;
import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.util.Iterator;
import java.util.Map;
import java.util.Set;

@RestController
@RequestMapping("/api/v1/files")
@RequiredArgsConstructor
public class FileController {

    private static final long MAX_BYTES = 10L * 1024 * 1024;
    private static final long MAX_PIXELS = 12_000_000L;
    private static final Set<String> ALLOWED_FORMATS = Set.of("jpeg", "jpg", "png");

    private final CloudinaryService cloudinaryService;
    private final CloudinaryAssetRegistry assetRegistry;

    @PostMapping("/upload")
    public ResponseEntity<Map<String, String>> uploadFile(
            @RequestParam("file") MultipartFile file,
            HttpServletRequest request) throws IOException {
        if (file == null || file.isEmpty() || file.getSize() <= 0) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Selecciona una imagen válida.");
        }
        if (file.getSize() > MAX_BYTES) {
            throw new ResponseStatusException(HttpStatus.PAYLOAD_TOO_LARGE,
                    "La imagen excede el tamaño máximo de 10 MB.");
        }

        byte[] bytes = file.getBytes();
        String detectedFormat = validateImage(bytes);
        String declaredType = file.getContentType();
        if (declaredType != null && !declaredType.isBlank()) {
            String normalizedType = declaredType.trim().toLowerCase(java.util.Locale.ROOT);
            String expectedType = "png".equals(detectedFormat) ? "image/png" : "image/jpeg";
            if (!"application/octet-stream".equals(normalizedType)
                    && !expectedType.equals(normalizedType)
                    && !("jpeg".equals(detectedFormat) && "image/jpg".equals(normalizedType))) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                        "El tipo declarado no coincide con el contenido de la imagen.");
            }
        }

        if (request.getUserPrincipal() == null) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Debes iniciar sesión.");
        }
        String ownerType = request.isUserInRole("FOODIE") || request.isUserInRole("RESTAURANT_ADMIN")
                ? "client" : "employee";
        String ownerId = request.getUserPrincipal().getName();

        CloudinaryService.UploadResult uploaded = cloudinaryService.uploadFile(bytes, detectedFormat);
        try {
            assetRegistry.recordUpload(ownerType, ownerId, uploaded);
        } catch (DataAccessException persistenceFailure) {
            cloudinaryService.deleteUploadedAsset(uploaded.publicId());
            throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE,
                    "No se pudo registrar la imagen. Intenta nuevamente.");
        }
        return ResponseEntity.status(HttpStatus.CREATED).body(Map.of(
                "url", uploaded.secureUrl(),
                "publicId", uploaded.publicId()
        ));
    }

    private static String validateImage(byte[] bytes) throws IOException {
        try (ImageInputStream input = ImageIO.createImageInputStream(new ByteArrayInputStream(bytes))) {
            if (input == null) throw invalidImage();
            Iterator<ImageReader> readers = ImageIO.getImageReaders(input);
            if (!readers.hasNext()) throw invalidImage();

            ImageReader reader = readers.next();
            try {
                reader.setInput(input, true, true);
                String format = reader.getFormatName().toLowerCase(java.util.Locale.ROOT);
                if (!ALLOWED_FORMATS.contains(format)) throw invalidImage();

                int width = reader.getWidth(0);
                int height = reader.getHeight(0);
                if (width <= 0 || height <= 0 || (long) width * height > MAX_PIXELS) {
                    throw new ResponseStatusException(HttpStatus.PAYLOAD_TOO_LARGE,
                            "La resolución de la imagen excede el máximo permitido.");
                }

                BufferedImage decoded = reader.read(0);
                if (decoded == null || decoded.getWidth() != width || decoded.getHeight() != height) {
                    throw invalidImage();
                }
                return "jpg".equals(format) ? "jpeg" : format;
            } finally {
                reader.dispose();
            }
        } catch (IOException | IllegalArgumentException exception) {
            throw invalidImage();
        }
    }

    private static ResponseStatusException invalidImage() {
        return new ResponseStatusException(HttpStatus.BAD_REQUEST,
                "El archivo no contiene una imagen JPEG o PNG válida.");
    }
}