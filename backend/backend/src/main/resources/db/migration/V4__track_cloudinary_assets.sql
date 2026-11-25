-- Track server-validated Cloudinary uploads so unassociated assets can be reviewed safely.
-- This migration is additive. It does not delete external media or change existing references.
CREATE TABLE cloudinary_assets (
    id CHAR(36) NOT NULL,
    owner_type VARCHAR(16) NOT NULL,
    owner_id CHAR(36) NOT NULL,
    public_id VARCHAR(191) NOT NULL,
    secure_url VARCHAR(512) NOT NULL,
    uploaded_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    attached_at TIMESTAMP NULL,
    reference_type VARCHAR(32) NULL,
    reference_id CHAR(36) NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_cloudinary_assets_public_id (public_id),
    KEY idx_cloudinary_assets_orphan_review (attached_at, uploaded_at),
    KEY idx_cloudinary_assets_owner (owner_type, owner_id, uploaded_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
