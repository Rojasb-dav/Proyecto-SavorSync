-- Operator procedure. Run in batch mode without --force against a fresh V1–V5 destination.
-- The input is a restored copy named savorsync_legacy_source. Never run against the live source.
SET SESSION sql_mode = 'STRICT_ALL_TABLES,NO_ZERO_DATE,NO_ZERO_IN_DATE,NO_ENGINE_SUBSTITUTION';
SET SESSION time_zone = '+00:00';
SET SESSION foreign_key_checks = 1;

CREATE TEMPORARY TABLE savorsync_copy_gate (
    reason VARCHAR(100) NOT NULL,
    compatible BOOLEAN NOT NULL CHECK (compatible = TRUE)
);

START TRANSACTION;
INSERT INTO savorsync_copy_gate VALUES
    ('distinct destination', DATABASE() IS NOT NULL AND DATABASE() <> 'savorsync_legacy_source'),
    ('successful Flyway V1 through V5', (SELECT COUNT(DISTINCT version) = 5
       FROM flyway_schema_history WHERE version IN ('1','2','3','4','5') AND success = 1)),
    ('destination has no failed migration', NOT EXISTS (SELECT 1 FROM flyway_schema_history WHERE success = 0)),
    ('destination is fresh', NOT EXISTS (SELECT 1 FROM clientes)
        AND NOT EXISTS (SELECT 1 FROM empleados)
        AND NOT EXISTS (SELECT 1 FROM account_identity_registry));
INSERT INTO savorsync_copy_gate VALUES
    ('source has the twelve expected tables', (SELECT COUNT(*) = 12 FROM information_schema.tables
      WHERE table_schema = 'savorsync_legacy_source' AND table_type = 'BASE TABLE'
        AND table_name IN ('clientes','comentarios','likes','menu_restaurantes','notificaciones_cliente',
          'pqrs','publicaciones','reservas','restaurantes','seguidores','sesiones_cliente','tokens_recuperacion'))),
    ('comments fit 200 characters', NOT EXISTS (
      SELECT 1 FROM savorsync_legacy_source.comentarios WHERE CHAR_LENGTH(contenido) > 200)),
    ('ratings are integral and on the academic scale', NOT EXISTS (
      SELECT 1 FROM savorsync_legacy_source.publicaciones
      WHERE calificacion <> FLOOR(calificacion) OR calificacion NOT BETWEEN 1 AND 5)),
    ('reservations have a compatible party size', NOT EXISTS (
      SELECT 1 FROM savorsync_legacy_source.reservas WHERE num_personas NOT BETWEEN 1 AND 127)),
    ('restaurant fields and price range are compatible', NOT EXISTS (
      SELECT 1 FROM savorsync_legacy_source.restaurantes
       WHERE owner_id IS NULL OR direccion IS NULL OR ciudad IS NULL OR categoria IS NULL
          OR (rango_precio IS NOT NULL AND rango_precio NOT BETWEEN 1 AND 4))),
    ('legacy notification types have an exact mapping', NOT EXISTS (
      SELECT 1 FROM savorsync_legacy_source.notificaciones_cliente WHERE tipo IN ('menu','system'))),
    ('recovery email fits 191 characters', NOT EXISTS (
      SELECT 1 FROM savorsync_legacy_source.tokens_recuperacion WHERE CHAR_LENGTH(email) > 191)),
    ('primary IDs are not changed by CHAR padding', NOT EXISTS (
      SELECT 1 FROM savorsync_legacy_source.clientes WHERE TRIM(id) = '' OR BINARY id <> BINARY TRIM(id)
      UNION ALL SELECT 1 FROM savorsync_legacy_source.publicaciones WHERE TRIM(id) = '' OR BINARY id <> BINARY TRIM(id)
      UNION ALL SELECT 1 FROM savorsync_legacy_source.restaurantes WHERE TRIM(id) = '' OR BINARY id <> BINARY TRIM(id)
      UNION ALL SELECT 1 FROM savorsync_legacy_source.menu_restaurantes WHERE TRIM(id) = '' OR BINARY id <> BINARY TRIM(id)
      UNION ALL SELECT 1 FROM savorsync_legacy_source.comentarios WHERE TRIM(id) = '' OR BINARY id <> BINARY TRIM(id)
      UNION ALL SELECT 1 FROM savorsync_legacy_source.reservas WHERE TRIM(id) = '' OR BINARY id <> BINARY TRIM(id)
      UNION ALL SELECT 1 FROM savorsync_legacy_source.pqrs WHERE TRIM(id) = '' OR BINARY id <> BINARY TRIM(id)
      UNION ALL SELECT 1 FROM savorsync_legacy_source.notificaciones_cliente WHERE TRIM(id) = '' OR BINARY id <> BINARY TRIM(id)
      UNION ALL SELECT 1 FROM savorsync_legacy_source.sesiones_cliente WHERE TRIM(id) = '' OR BINARY id <> BINARY TRIM(id)
      UNION ALL SELECT 1 FROM savorsync_legacy_source.tokens_recuperacion WHERE TRIM(id) = '' OR BINARY id <> BINARY TRIM(id)));

-- This insert also checks normalized email and username uniqueness under the target collation.
INSERT INTO account_identity_registry (identity_type, identity_id, email_normalized, username_normalized, requested_role)
SELECT CASE WHEN rol IN ('moderador','admin_sistema') THEN 'employee' ELSE 'client' END,
       id, LOWER(TRIM(email)), LOWER(TRIM(username)),
       CASE WHEN rol IN ('moderador','admin_sistema') THEN 'employee' ELSE rol END
FROM savorsync_legacy_source.clientes;

INSERT INTO clientes (id,email,username,password,full_name,rol,avatar_url,bio,phone,is_active,email_verified,created_at,updated_at)
SELECT id,email,username,password,full_name,rol,avatar_url,bio,phone,is_active,email_verified,created_at,updated_at
FROM savorsync_legacy_source.clientes WHERE rol IN ('foodie','restaurant_admin');
INSERT INTO empleados (id,email,username,password,full_name,cargo,is_active,email_verified,created_at,updated_at)
SELECT id,email,username,password,full_name,rol,is_active,FALSE,created_at,updated_at
FROM savorsync_legacy_source.clientes WHERE rol IN ('moderador','admin_sistema');

INSERT INTO restaurantes (id,owner_id,nombre,descripcion,direccion,ciudad,latitud,longitud,telefono,email,
                           sitio_web,categoria,rango_precio,rating_promedio,total_resenas,estado,created_at,updated_at)
SELECT id,owner_id,nombre,descripcion,direccion,ciudad,latitud,longitud,telefono,email,
       sitio_web,categoria,rango_precio,rating_promedio,total_resenas,COALESCE(estado,'pendiente'),created_at,updated_at
FROM savorsync_legacy_source.restaurantes;

INSERT INTO publicaciones (id,cliente_id,restaurante_id,contenido,calificacion,conteo_likes,
                           conteo_comentarios,es_publica,estado,created_at,updated_at)
SELECT p.id,p.cliente_id,
       (SELECT CASE WHEN COUNT(*) = 1 THEN MIN(r.id) ELSE NULL END
        FROM savorsync_legacy_source.restaurantes r
        WHERE BINARY r.nombre = BINARY p.nombre_restaurante
          AND BINARY r.direccion = BINARY p.direccion_restaurante),
       p.contenido,p.calificacion,p.conteo_likes,p.conteo_comentarios,
       COALESCE(p.es_publica,FALSE),COALESCE(p.estado,'borrador'),p.created_at,p.updated_at
FROM savorsync_legacy_source.publicaciones p;

INSERT INTO imagenes_publicacion (id,publicacion_id,cliente_id,url,orden,created_at)
SELECT UUID(),id,cliente_id,url_imagen,0,created_at
FROM savorsync_legacy_source.publicaciones WHERE url_imagen IS NOT NULL AND TRIM(url_imagen) <> '';

INSERT INTO comentarios (id,publicacion_id,cliente_id,contenido,estado,created_at,updated_at)
SELECT id,publicacion_id,cliente_id,contenido,COALESCE(estado,'oculto'),created_at,updated_at
FROM savorsync_legacy_source.comentarios;
UPDATE comentarios c JOIN savorsync_legacy_source.comentarios s ON BINARY c.id = BINARY s.id
SET c.parent_id = s.parent_id, c.updated_at = s.updated_at WHERE s.parent_id IS NOT NULL;

INSERT INTO likes (id,cliente_id,publicacion_id,created_at)
SELECT UUID(),cliente_id,publicacion_id,NULL FROM savorsync_legacy_source.likes;
INSERT INTO seguidores (id,seguidor_id,seguido_id,created_at)
SELECT UUID(),seguidor_id,seguido_id,NULL FROM savorsync_legacy_source.seguidores;

INSERT INTO menu_restaurante (id,restaurante_id,nombre,descripcion,categoria,precio,disponible,orden,created_at,updated_at)
SELECT id,restaurante_id,nombre,descripcion,categoria,precio,disponible,orden,created_at,updated_at
FROM savorsync_legacy_source.menu_restaurantes;
INSERT INTO reservas (id,restaurante_id,cliente_id,num_personas,fecha_reserva,hora_reserva,estado,notas,created_at,updated_at)
SELECT id,restaurante_id,cliente_id,num_personas,fecha_reserva,hora_reserva,estado,notas,created_at,updated_at
FROM savorsync_legacy_source.reservas;

INSERT INTO pqrs (id,cliente_id,empleado_id,tipo,asunto,descripcion,estado,respuesta,fecha_gestion,fecha_cierre,created_at,updated_at)
SELECT id,cliente_id,empleado_id,tipo,asunto,descripcion,estado,respuesta,fecha_gestion,fecha_cierre,created_at,updated_at
FROM savorsync_legacy_source.pqrs;
INSERT INTO notificaciones_cliente (id,cliente_id,tipo,titulo,mensaje,leida,canal,created_at)
SELECT id,cliente_id,
       CASE tipo WHEN 'comment' THEN 'comentario' WHEN 'follow' THEN 'seguidor'
                 WHEN 'reservation' THEN 'reserva' ELSE tipo END,
       titulo,mensaje,leida,COALESCE(canal,'in_app'),created_at
FROM savorsync_legacy_source.notificaciones_cliente;

-- Historical credentials are unusable. Do not copy bearer tokens or plaintext recovery codes.
INSERT INTO sesiones_cliente (id,cliente_id,session_token,plataforma,ip_address,expires_at,activa,created_at,updated_at)
SELECT s.id,s.cliente_id,CONCAT('legacy:',SHA2(s.id,256)),s.plataforma,s.ip_address,s.expires_at,FALSE,s.created_at,s.updated_at
FROM savorsync_legacy_source.sesiones_cliente s JOIN clientes c ON BINARY c.id = BINARY s.cliente_id;
INSERT INTO sesiones_empleado (id,empleado_id,session_token,plataforma,ip_address,expires_at,activa,created_at,updated_at)
SELECT s.id,s.cliente_id,CONCAT('legacy:',SHA2(s.id,256)),
       CASE e.cargo WHEN 'admin_sistema' THEN 'web_admin' ELSE 'web_moderacion' END,
       s.ip_address,s.expires_at,FALSE,s.created_at,s.updated_at
FROM savorsync_legacy_source.sesiones_cliente s JOIN empleados e ON BINARY e.id = BINARY s.cliente_id;
INSERT INTO tokens_recuperacion (id,email,code,expires_at,created_at,identity_id,identity_type,purpose,failed_attempts,consumed_at)
SELECT t.id,t.email,'legacy-invalidated',t.expires_at,NULL,r.identity_id,COALESCE(r.identity_type,'client'),
       'PASSWORD_RESET',0,CURRENT_TIMESTAMP
FROM savorsync_legacy_source.tokens_recuperacion t
LEFT JOIN account_identity_registry r ON r.email_normalized = LOWER(TRIM(t.email)) COLLATE utf8mb4_unicode_ci;

INSERT INTO savorsync_copy_gate VALUES
    ('all sessions accounted for', (SELECT COUNT(*) FROM savorsync_legacy_source.sesiones_cliente)
       = (SELECT COUNT(*) FROM sesiones_cliente) + (SELECT COUNT(*) FROM sesiones_empleado)),
    ('all accounts accounted for', (SELECT COUNT(*) FROM savorsync_legacy_source.clientes)
       = (SELECT COUNT(*) FROM clientes) + (SELECT COUNT(*) FROM empleados));
COMMIT;
