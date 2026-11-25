-- Additive P0 identity challenge metadata. V2 is intentionally immutable.
ALTER TABLE tokens_recuperacion
    ADD COLUMN identity_id CHAR(36) NULL,
    ADD COLUMN identity_type VARCHAR(16) NOT NULL DEFAULT 'client',
    ADD COLUMN purpose VARCHAR(32) NOT NULL DEFAULT 'PASSWORD_RESET',
    ADD COLUMN failed_attempts INT NOT NULL DEFAULT 0,
    ADD COLUMN consumed_at TIMESTAMP NULL;

UPDATE tokens_recuperacion t
JOIN clientes c ON LOWER(c.email) = LOWER(t.email)
SET t.identity_id = c.id, t.identity_type = 'client'
WHERE t.identity_id IS NULL;

UPDATE tokens_recuperacion t
JOIN empleados e ON LOWER(e.email) = LOWER(t.email)
SET t.identity_id = e.id, t.identity_type = 'employee'
WHERE t.identity_id IS NULL;

-- Legacy codes do not match the six-digit purpose-bound challenge contract.
UPDATE tokens_recuperacion SET consumed_at = CURRENT_TIMESTAMP WHERE consumed_at IS NULL;

ALTER TABLE tokens_recuperacion
    ADD COLUMN active_identity_id CHAR(36)
        GENERATED ALWAYS AS (CASE WHEN consumed_at IS NULL THEN identity_id ELSE NULL END) STORED,
    ADD UNIQUE KEY uk_security_challenge_active
        (identity_type, purpose, active_identity_id),
    ADD KEY idx_security_challenge_lookup
        (identity_id, purpose, consumed_at, expires_at);

ALTER TABLE empleados
    ADD COLUMN email_verified BOOLEAN NOT NULL DEFAULT FALSE;

CREATE TABLE auth_rate_limits (
    bucket_key CHAR(64) NOT NULL,
    window_started_at TIMESTAMP NOT NULL,
    request_count INT NOT NULL DEFAULT 0,
    last_requested_at TIMESTAMP NULL,
    PRIMARY KEY (bucket_key)
);

-- Enforce email and username uniqueness across the two legacy identity tables.
-- If legacy records collide after normalization, this migration fails without modifying
-- either account table so an owner can resolve the collision from a backed-up copy.
CREATE TABLE account_identity_registry (
    identity_type VARCHAR(16) NOT NULL,
    identity_id CHAR(36) NOT NULL,
    email_normalized VARCHAR(191) NOT NULL,
    username_normalized VARCHAR(50) NOT NULL,
    PRIMARY KEY (identity_type, identity_id),
    UNIQUE KEY uk_account_identity_email (email_normalized),
    UNIQUE KEY uk_account_identity_username (username_normalized)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO account_identity_registry
    (identity_type, identity_id, email_normalized, username_normalized)
SELECT 'client', id, LOWER(TRIM(email)), LOWER(TRIM(username)) FROM clientes
UNION ALL
SELECT 'employee', id, LOWER(TRIM(email)), LOWER(TRIM(username)) FROM empleados;
