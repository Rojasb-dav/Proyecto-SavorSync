package co.edu.umb.foodies.backend.service;

import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Map;
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
        int attached = jdbc.update("""
                UPDATE cloudinary_assets
                SET attached_at = CURRENT_TIMESTAMP,
                    reference_type = ?,
                    reference_id = ?
                WHERE owner_type = ?
                  AND owner_id = ?
                  AND CAST(secure_url AS BINARY) = CAST(? AS BINARY)
                  AND attached_at IS NULL
                """,
                referenceType, referenceId, ownerType, ownerId, secureUrl);
        if (attached == 1) return true;
        if (attached > 1) return false;

        List<Map<String, Object>> existing = jdbc.queryForList("""
                SELECT id
                FROM cloudinary_assets
                WHERE owner_type = ?
                  AND owner_id = ?
                  AND CAST(secure_url AS BINARY) = CAST(? AS BINARY)
                  AND reference_type = ?
                  AND reference_id = ?
                  AND attached_at IS NOT NULL
                """, new Object[]{ownerType, ownerId, secureUrl, referenceType, referenceId});
        return existing.size() == 1;
    }
}
