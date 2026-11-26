-- Authoritative extension to the immutable V1 academic schema.
-- Gate legacy rows before the first non-transactional ALTER.
CREATE TEMPORARY TABLE v6_integrity_gate (
    rule_name VARCHAR(100) PRIMARY KEY,
    passed BOOLEAN NOT NULL CHECK (passed = TRUE)
);

INSERT INTO v6_integrity_gate VALUES
    ('restaurant owner role', NOT EXISTS (
        SELECT 1 FROM restaurantes r JOIN clientes c ON c.id = r.owner_id
        WHERE c.rol <> 'restaurant_admin'
    )),
    ('no self follows', NOT EXISTS (SELECT 1 FROM seguidores WHERE seguidor_id = seguido_id)),
    ('comment parent in same post', NOT EXISTS (
        SELECT 1 FROM comentarios c JOIN comentarios p ON p.id = c.parent_id
        WHERE c.publicacion_id <> p.publicacion_id
    )),
    ('report target exists', NOT EXISTS (
        SELECT 1 FROM reportes_contenido r
        LEFT JOIN publicaciones p ON r.tipo_contenido = 'publicacion' AND r.contenido_id = p.id
        LEFT JOIN comentarios c ON r.tipo_contenido = 'comentario' AND r.contenido_id = c.id
        LEFT JOIN restaurantes t ON r.tipo_contenido = 'restaurante' AND r.contenido_id = t.id
        WHERE p.id IS NULL AND c.id IS NULL AND t.id IS NULL
    ));

INSERT INTO v6_integrity_gate (rule_name, passed)
WITH RECURSIVE ancestry AS (
    SELECT id AS descendant, parent_id AS ancestor FROM comentarios WHERE parent_id IS NOT NULL
    UNION DISTINCT
    SELECT a.descendant, p.parent_id FROM ancestry a
    JOIN comentarios p ON p.id = a.ancestor WHERE p.parent_id IS NOT NULL
)
SELECT 'acyclic comment ancestry', NOT EXISTS (SELECT 1 FROM ancestry WHERE descendant = ancestor);
DROP TEMPORARY TABLE v6_integrity_gate;

ALTER TABLE restaurantes
    ADD COLUMN deactivated_at TIMESTAMP NULL,
    ADD CONSTRAINT ck_restaurant_deactivated CHECK (deactivated_at IS NULL OR estado <=> 'suspendido');

ALTER TABLE publicaciones
    ADD COLUMN deleted_at TIMESTAMP NULL;

ALTER TABLE seguidores
    ADD CONSTRAINT ck_follow_distinct_accounts CHECK (seguidor_id <> seguido_id);

ALTER TABLE comentarios
    ADD UNIQUE KEY uq_comment_post_id (publicacion_id, id),
    DROP FOREIGN KEY comentarios_ibfk_3,
    ADD CONSTRAINT fk_comment_parent_same_post FOREIGN KEY (publicacion_id, parent_id)
        REFERENCES comentarios(publicacion_id, id),
    ADD CONSTRAINT ck_comment_not_self_parent CHECK (id <> parent_id);

-- Reparenting or changing the post of an existing comment could introduce a cycle.
DELIMITER $$
CREATE TRIGGER before_update_comment_relationship
BEFORE UPDATE ON comentarios FOR EACH ROW
BEGIN
    IF NOT (NEW.id <=> OLD.id AND NEW.parent_id <=> OLD.parent_id
            AND NEW.publicacion_id <=> OLD.publicacion_id) THEN
        SIGNAL SQLSTATE '23000' SET MESSAGE_TEXT = 'Comment relationships are immutable';
    END IF;
END$$

CREATE TRIGGER before_insert_restaurant_owner
BEFORE INSERT ON restaurantes FOR EACH ROW
BEGIN
    DECLARE owner_role VARCHAR(32);
    SELECT rol INTO owner_role FROM clientes WHERE id = NEW.owner_id FOR SHARE;
    IF NOT (owner_role <=> 'restaurant_admin') THEN
        SIGNAL SQLSTATE '23000' SET MESSAGE_TEXT = 'Restaurant owner must be a restaurant administrator';
    END IF;
END$$

CREATE TRIGGER before_update_restaurant_owner
BEFORE UPDATE ON restaurantes FOR EACH ROW
BEGIN
    IF NOT (NEW.owner_id <=> OLD.owner_id) THEN
        SIGNAL SQLSTATE '23000' SET MESSAGE_TEXT = 'Restaurant ownership is immutable';
    END IF;
END$$

CREATE TRIGGER before_update_restaurant_owner_role
BEFORE UPDATE ON clientes FOR EACH ROW
BEGIN
    IF OLD.rol = 'restaurant_admin' AND NEW.rol <> OLD.rol
            AND EXISTS (SELECT 1 FROM restaurantes WHERE owner_id = OLD.id) THEN
        SIGNAL SQLSTATE '23000' SET MESSAGE_TEXT = 'Account owns restaurants';
    END IF;
END$$
CREATE TRIGGER after_deactivate_employee
AFTER UPDATE ON empleados FOR EACH ROW
BEGIN
    IF OLD.is_active AND NOT NEW.is_active THEN
        UPDATE sesiones_empleado SET activa = FALSE, updated_at = CURRENT_TIMESTAMP
        WHERE empleado_id = NEW.id AND activa;
    END IF;
END$$

CREATE TRIGGER before_insert_live_client_session
BEFORE INSERT ON sesiones_cliente FOR EACH ROW
BEGIN
    DECLARE allowed BOOLEAN;
    IF NEW.activa THEN
        SELECT is_active AND email_verified INTO allowed FROM clientes WHERE id = NEW.cliente_id FOR SHARE;
        IF NOT (allowed <=> TRUE) THEN
            SIGNAL SQLSTATE '23000' SET MESSAGE_TEXT = 'Client session requires an active verified account';
        END IF;
    END IF;
END$$

CREATE TRIGGER before_insert_live_employee_session
BEFORE INSERT ON sesiones_empleado FOR EACH ROW
BEGIN
    DECLARE allowed BOOLEAN;
    IF NEW.activa THEN
        SELECT is_active AND email_verified INTO allowed FROM empleados WHERE id = NEW.empleado_id FOR SHARE;
        IF NOT (allowed <=> TRUE) THEN
            SIGNAL SQLSTATE '23000' SET MESSAGE_TEXT = 'Employee session requires an active verified account';
        END IF;
    END IF;
END$$

CREATE TRIGGER before_insert_active_challenge_identity
BEFORE INSERT ON tokens_recuperacion FOR EACH ROW
BEGIN
    IF NEW.consumed_at IS NULL AND NOT EXISTS (
        SELECT 1 FROM account_identity_registry a
        WHERE a.identity_type = NEW.identity_type AND a.identity_id = NEW.identity_id
          AND a.email_normalized = NEW.email
    ) THEN
        SIGNAL SQLSTATE '23000' SET MESSAGE_TEXT = 'Active challenge requires a registered identity';
    END IF;
END$$
DELIMITER ;

ALTER TABLE reportes_contenido
    ADD COLUMN report_post_id CHAR(36)
        GENERATED ALWAYS AS (IF(tipo_contenido = 'publicacion', contenido_id, NULL)) STORED,
    ADD COLUMN report_comment_id CHAR(36)
        GENERATED ALWAYS AS (IF(tipo_contenido = 'comentario', contenido_id, NULL)) STORED,
    ADD COLUMN report_restaurant_id CHAR(36)
        GENERATED ALWAYS AS (IF(tipo_contenido = 'restaurante', contenido_id, NULL)) STORED,
    ADD CONSTRAINT fk_report_post FOREIGN KEY (report_post_id) REFERENCES publicaciones(id),
    ADD CONSTRAINT fk_report_comment FOREIGN KEY (report_comment_id) REFERENCES comentarios(id),
    ADD CONSTRAINT fk_report_restaurant FOREIGN KEY (report_restaurant_id) REFERENCES restaurantes(id);

-- Existing counters predate serialized writes. Recount from authoritative rows.
UPDATE publicaciones p
SET conteo_likes = (SELECT COUNT(*) FROM likes l WHERE l.publicacion_id = p.id),
    conteo_comentarios = (SELECT COUNT(*) FROM comentarios c
                         WHERE c.publicacion_id = p.id AND c.estado = 'activo');
