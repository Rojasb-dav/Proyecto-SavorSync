package co.edu.umb.foodies.backend.service;

import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

@Service
@RequiredArgsConstructor
public class CloudinaryAssetRegistry {

    private final JdbcTemplate jdbc;

    @Transactional
    public void recordUpload(String ownerType, String ownerId, CloudinaryService.UploadResult upload) {
        jdbc.update("""
                INSERT INTO cloudinary_assets
                  (id, owner_type, owner_id, public_id, secure_url)
                VALUES (?, ?, ?, ?, ?)
                """,
                UUID.randomUUID().toString(),
                ownerType,
                ownerId,
                upload.publicId(),
                upload.secureUrl());
    }

    @Transactional
    public boolean attachIfOwned(
            String ownerType,
            String ownerId,
            String secureUrl,
            String referenceType,
            String referenceId) {
        if (secureUrl == null || secureUrl.isBlank()) return false;
        return jdbc.update("""
                UPDATE cloudinary_assets
                SET attached_at = CURRENT_TIMESTAMP,
                    reference_type = ?,
                    reference_id = ?
                WHERE owner_type = ?
                  AND owner_id = ?
                  AND secure_url = ?
                  AND attached_at IS NULL
                """,
                referenceType, referenceId, ownerType, ownerId, secureUrl) == 1;
    }
}
