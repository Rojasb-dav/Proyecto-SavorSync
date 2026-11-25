package co.edu.umb.foodies.backend.service;

import com.cloudinary.Cloudinary;
import com.cloudinary.utils.ObjectUtils;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import java.io.IOException;
import java.util.List;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class CloudinaryService {

    private final Cloudinary cloudinary;

    public UploadResult uploadFile(byte[] validatedImage, String validatedFormat) {
        final Map<?, ?> result;
        try {
            result = cloudinary.uploader().upload(validatedImage, ObjectUtils.asMap(
                    "resource_type", "image",
                    "allowed_formats", List.of("jpg", "png"),
                    "use_filename", false,
                    "unique_filename", true,
                    "overwrite", false
            ));
        } catch (IOException providerUnavailable) {
            throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE,
                    "El servicio multimedia no está disponible. Intenta nuevamente.");
        }

        Object secureUrl = result.get("secure_url");
        Object publicId = result.get("public_id");
        if (!(secureUrl instanceof String url) || url.isBlank()
                || !(publicId instanceof String id) || id.isBlank()) {
            throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE,
                    "El servicio multimedia no confirmó la carga.");
        }
        return new UploadResult(url, id, validatedFormat);
    }

    public void deleteUploadedAsset(String publicId) {
        try {
            cloudinary.uploader().destroy(publicId, ObjectUtils.asMap("resource_type", "image"));
        } catch (IOException ignored) {
            // The upload failed to persist locally; the orphan remains discoverable by public_id.
        }
    }

    public record UploadResult(String secureUrl, String publicId, String format) {}
}