package co.edu.umb.foodies.backend.service;

import com.cloudinary.Cloudinary;
import com.cloudinary.utils.ObjectUtils;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import java.io.IOException;
import java.net.URI;
import java.util.UUID;
import java.util.List;
import java.util.Map;

@Service
public class CloudinaryService {

    private final Cloudinary cloudinary;

    private final String assetFolder;

    public CloudinaryService(Cloudinary cloudinary, @Value("${CLOUDINARY_ASSET_FOLDER:foodies}") String assetFolder) {
        if (!assetFolder.matches("[A-Za-z0-9_-]+(?:/[A-Za-z0-9_-]+)*")) {
            throw new IllegalArgumentException("La carpeta multimedia configurada no es válida.");
        }
        this.cloudinary = cloudinary;
        this.assetFolder = assetFolder;
    }

    public UploadResult uploadFile(byte[] validatedImage, String validatedFormat) {
        final Map<?, ?> result;
        try {
            result = cloudinary.uploader().upload(validatedImage, ObjectUtils.asMap(
                    "resource_type", "image",
                    "asset_folder", assetFolder,
                    "public_id", UUID.randomUUID().toString(),
                    "tags", "savorsync_backend_v33",
                    "allowed_formats", List.of("jpg", "png"),
                    "use_filename", false,
                    "unique_filename", true,
                    "overwrite", false
            ));
        } catch (IOException | RuntimeException providerUnavailable) {
            throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE,
                    "El servicio multimedia no está disponible. Intenta nuevamente.");
        }

        Object secureUrl = result.get("secure_url");
        Object publicId = result.get("public_id");
        if (!(secureUrl instanceof String url) || !isHttps(url)
                || !(publicId instanceof String id) || id.isBlank()) {
            throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE,
                    "El servicio multimedia no confirmó la carga.");
        }
        return new UploadResult(url, id, validatedFormat);
    }

    public void deleteUploadedAsset(String publicId) {
        try {
            cloudinary.uploader().destroy(publicId, ObjectUtils.asMap("resource_type", "image"));
        } catch (IOException | RuntimeException ignored) {
            // The upload failed to persist locally; the orphan remains discoverable by public_id.
        }
    }

    private static boolean isHttps(String value) {
        try {
            URI uri = URI.create(value);
            return "https".equalsIgnoreCase(uri.getScheme()) && uri.getHost() != null && uri.getUserInfo() == null;
        } catch (IllegalArgumentException invalidUri) {
            return false;
        }
    }

    public record UploadResult(String secureUrl, String publicId, String format) {}
}