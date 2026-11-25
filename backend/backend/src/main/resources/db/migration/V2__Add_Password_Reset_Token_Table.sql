-- ================================================================
-- TABLA ADITIVA DE RECUPERACIÓN DE CONTRASEÑAS (P0.7)
-- ================================================================

CREATE TABLE tokens_recuperacion (
    id         CHAR(36)     NOT NULL,
    email      VARCHAR(191) NOT NULL,
    code       VARCHAR(255) NOT NULL,
    expires_at TIMESTAMP    NOT NULL,
    created_at TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id)
);

CREATE TRIGGER before_insert_tokens_recuperacion
    BEFORE INSERT ON tokens_recuperacion FOR EACH ROW
    SET NEW.id = IF(NEW.id IS NULL OR NEW.id = '', UUID(), NEW.id);
