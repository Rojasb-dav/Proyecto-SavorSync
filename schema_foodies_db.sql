-- ================================================================
-- FOODIES DATABASE — V.3 (SavorSync 3NF)
-- ================================================================

DROP DATABASE IF EXISTS foodies_db;
CREATE DATABASE foodies_db
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;
USE foodies_db;

-- ================================================================
-- 1. TABLA DE CLIENTES
-- ================================================================

CREATE TABLE clientes (
  id            CHAR(36)      NOT NULL,
  email         VARCHAR(191)  UNIQUE NOT NULL,
  username      VARCHAR(50)   UNIQUE NOT NULL,
  password      VARCHAR(255)  NOT NULL,
  full_name     VARCHAR(100)  NOT NULL,
  rol           ENUM('foodie','restaurant_admin','moderador','admin_sistema') NOT NULL DEFAULT 'foodie',
  avatar_url    VARCHAR(500),
  bio           TEXT,
  phone         VARCHAR(20),
  is_active     BOOLEAN       DEFAULT TRUE,
  email_verified BOOLEAN      DEFAULT FALSE,
  created_at    TIMESTAMP     DEFAULT CURRENT_TIMESTAMP,
  updated_at    TIMESTAMP     DEFAULT CURRENT_TIMESTAMP
                              ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id)
);

CREATE TRIGGER before_insert_clientes
  BEFORE INSERT ON clientes FOR EACH ROW
  SET NEW.id = IF(NEW.id IS NULL OR NEW.id = '', UUID(), NEW.id);

-- ================================================================
-- 2. TABLA DE EMPLEADOS
-- ================================================================

CREATE TABLE empleados (
  id                CHAR(36)     NOT NULL,
  email             VARCHAR(191) UNIQUE NOT NULL,
  username          VARCHAR(50)  UNIQUE NOT NULL,
  password          VARCHAR(255) NOT NULL,
  full_name         VARCHAR(100) NOT NULL,
  cargo             ENUM('moderador','admin_sistema') NOT NULL,
  is_active         BOOLEAN      DEFAULT TRUE,
  fecha_vinculacion DATE,
  created_at        TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
  updated_at        TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
                                 ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id)
);

CREATE TRIGGER before_insert_empleados
  BEFORE INSERT ON empleados FOR EACH ROW
  SET NEW.id = IF(NEW.id IS NULL OR NEW.id = '', UUID(), NEW.id);

-- ================================================================
-- 3. TABLA DE RESTAURANTES
-- ================================================================

CREATE TABLE restaurantes (
  id               CHAR(36)       NOT NULL,
  owner_id         CHAR(36)       NOT NULL,
  nombre           VARCHAR(100)   NOT NULL,
  descripcion      TEXT,
  direccion        VARCHAR(255)   NOT NULL,
  ciudad           VARCHAR(100)   NOT NULL,
  latitud          DECIMAL(10,8),
  longitud         DECIMAL(11,8),
  telefono         VARCHAR(20),
  email            VARCHAR(191),
  sitio_web        VARCHAR(255),
  categoria        VARCHAR(50)    NOT NULL,
  rango_precio     TINYINT        CHECK (rango_precio BETWEEN 1 AND 4),
  rating_promedio  DECIMAL(3,2)   DEFAULT 0.00,
  total_resenas    INTEGER        DEFAULT 0,
  estado           ENUM('borrador','pendiente','activo','suspendido')
                   DEFAULT 'borrador',
  aprobado_por     CHAR(36)       NULL,
  fecha_aprobacion TIMESTAMP      NULL,
  created_at       TIMESTAMP      DEFAULT CURRENT_TIMESTAMP,
  updated_at       TIMESTAMP      DEFAULT CURRENT_TIMESTAMP
                   ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  FOREIGN KEY (owner_id) REFERENCES clientes(id),
  FOREIGN KEY (aprobado_por) REFERENCES empleados(id)
);

CREATE TRIGGER before_insert_restaurantes
  BEFORE INSERT ON restaurantes FOR EACH ROW
  SET NEW.id = IF(NEW.id IS NULL OR NEW.id = '', UUID(), NEW.id);

-- ================================================================
-- 4. TABLA INTERMEDIA CLIENTE–RESTAURANTE (favoritos)
-- ================================================================

CREATE TABLE cliente_restaurante_favorito (
  id             CHAR(36)  NOT NULL,
  cliente_id     CHAR(36)  NOT NULL,
  restaurante_id CHAR(36)  NOT NULL,
  created_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_favorito (cliente_id, restaurante_id),
  FOREIGN KEY (cliente_id)     REFERENCES clientes(id),
  FOREIGN KEY (restaurante_id) REFERENCES restaurantes(id)
);

CREATE TRIGGER before_insert_cliente_restaurante_favorito
  BEFORE INSERT ON cliente_restaurante_favorito FOR EACH ROW
  SET NEW.id = IF(NEW.id IS NULL OR NEW.id = '', UUID(), NEW.id);

-- ================================================================
-- 5. TABLA DE SEGUIDORES (3FN)
-- ================================================================

CREATE TABLE seguidores (
  id           CHAR(36)  NOT NULL,
  seguidor_id  CHAR(36)  NOT NULL,
  seguido_id   CHAR(36)  NOT NULL,
  created_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_seguimiento (seguidor_id, seguido_id),
  FOREIGN KEY (seguidor_id) REFERENCES clientes(id),
  FOREIGN KEY (seguido_id)  REFERENCES clientes(id)
);

CREATE TRIGGER before_insert_seguidores
  BEFORE INSERT ON seguidores FOR EACH ROW
  SET NEW.id = IF(NEW.id IS NULL OR NEW.id = '', UUID(), NEW.id);

-- ================================================================
-- 6. TABLA DE PUBLICACIONES
-- ================================================================

CREATE TABLE publicaciones (
  id              CHAR(36)   NOT NULL,
  cliente_id      CHAR(36)   NOT NULL,
  restaurante_id  CHAR(36),
  contenido       TEXT       NOT NULL,
  calificacion    TINYINT    CHECK (calificacion BETWEEN 1 AND 5),
  conteo_likes    INTEGER    DEFAULT 0,
  conteo_comentarios INTEGER DEFAULT 0,
  es_publica      BOOLEAN    DEFAULT TRUE,
  estado          ENUM('borrador','publicada','oculta','en_revision')
                             DEFAULT 'publicada',
  created_at      TIMESTAMP  DEFAULT CURRENT_TIMESTAMP,
  updated_at      TIMESTAMP  DEFAULT CURRENT_TIMESTAMP
                             ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  FOREIGN KEY (cliente_id)     REFERENCES clientes(id),
  FOREIGN KEY (restaurante_id) REFERENCES restaurantes(id)
);

CREATE TRIGGER before_insert_publicaciones
  BEFORE INSERT ON publicaciones FOR EACH ROW
  SET NEW.id = IF(NEW.id IS NULL OR NEW.id = '', UUID(), NEW.id);

-- ================================================================
-- 7. TABLA DE COMENTARIOS
-- ================================================================

CREATE TABLE comentarios (
  id           CHAR(36)     NOT NULL,
  publicacion_id CHAR(36)   NOT NULL,
  cliente_id   CHAR(36)     NOT NULL,
  parent_id    CHAR(36)     DEFAULT NULL,
  contenido    VARCHAR(200) NOT NULL,
  estado       ENUM('activo','oculto','eliminado') DEFAULT 'activo',
  created_at   TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
  updated_at   TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
                            ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  FOREIGN KEY (publicacion_id) REFERENCES publicaciones(id),
  FOREIGN KEY (cliente_id)     REFERENCES clientes(id),
  FOREIGN KEY (parent_id)      REFERENCES comentarios(id)
);

CREATE TRIGGER before_insert_comentarios
  BEFORE INSERT ON comentarios FOR EACH ROW
  SET NEW.id = IF(NEW.id IS NULL OR NEW.id = '', UUID(), NEW.id);

-- ================================================================
-- 8. TABLA DE LIKES
-- ================================================================

CREATE TABLE likes (
  id             CHAR(36)  NOT NULL,
  cliente_id     CHAR(36)  NOT NULL,
  publicacion_id CHAR(36)  NOT NULL,
  created_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_like (cliente_id, publicacion_id),
  FOREIGN KEY (cliente_id)     REFERENCES clientes(id),
  FOREIGN KEY (publicacion_id) REFERENCES publicaciones(id)
);

CREATE TRIGGER before_insert_likes
  BEFORE INSERT ON likes FOR EACH ROW
  SET NEW.id = IF(NEW.id IS NULL OR NEW.id = '', UUID(), NEW.id);

-- ================================================================
-- 9. TABLA DE IMÁGENES DE PUBLICACIONES
-- ================================================================

CREATE TABLE imagenes_publicacion (
  id             CHAR(36)     NOT NULL,
  publicacion_id CHAR(36)     NOT NULL,
  cliente_id     CHAR(36)     NOT NULL,
  url            VARCHAR(500) NOT NULL,
  cloudinary_id  VARCHAR(255),
  orden          TINYINT      DEFAULT 0,
  created_at     TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  FOREIGN KEY (publicacion_id) REFERENCES publicaciones(id) ON DELETE CASCADE,
  FOREIGN KEY (cliente_id)     REFERENCES clientes(id)
);

CREATE TRIGGER before_insert_imagenes_publicacion

  BEFORE INSERT ON imagenes_publicacion FOR EACH ROW
  SET NEW.id = IF(NEW.id IS NULL OR NEW.id = '', UUID(), NEW.id);

-- ================================================================
-- 10. TABLA DE IMÁGENES DE RESTAURANTES
-- ================================================================

CREATE TABLE imagenes_restaurante (
  id             CHAR(36)     NOT NULL,
  restaurante_id CHAR(36)     NOT NULL,
  cliente_id     CHAR(36)     NOT NULL,
  url            VARCHAR(500) NOT NULL,
  cloudinary_id  VARCHAR(255),
  tipo           ENUM('portada','galeria','item_menu')
                              NOT NULL DEFAULT 'galeria',
  orden          TINYINT      DEFAULT 0,
  created_at     TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  FOREIGN KEY (restaurante_id) REFERENCES restaurantes(id) ON DELETE CASCADE,
  FOREIGN KEY (cliente_id)     REFERENCES clientes(id)
);

CREATE TRIGGER before_insert_imagenes_restaurante
  BEFORE INSERT ON imagenes_restaurante FOR EACH ROW
  SET NEW.id = IF(NEW.id IS NULL OR NEW.id = '', UUID(), NEW.id);

-- ================================================================
-- 11. TABLA DE MENÚ DEL RESTAURANTE
-- ================================================================

CREATE TABLE menu_restaurante (
  id             CHAR(36)      NOT NULL,
  restaurante_id CHAR(36)      NOT NULL,
  nombre         VARCHAR(100)  NOT NULL,
  descripcion    TEXT,
  categoria      VARCHAR(50),
  precio         DECIMAL(10,2) NOT NULL,
  disponible     BOOLEAN       DEFAULT TRUE,
  orden          INTEGER       DEFAULT 0,
  created_at     TIMESTAMP     DEFAULT CURRENT_TIMESTAMP,
  updated_at     TIMESTAMP     DEFAULT CURRENT_TIMESTAMP
                               ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  FOREIGN KEY (restaurante_id) REFERENCES restaurantes(id)
);

CREATE TRIGGER before_insert_menu_restaurante
  BEFORE INSERT ON menu_restaurante FOR EACH ROW
  SET NEW.id = IF(NEW.id IS NULL OR NEW.id = '', UUID(), NEW.id);

-- ================================================================
-- 12. TABLA DE HORARIOS DEL RESTAURANTE
-- ================================================================

CREATE TABLE horarios_restaurante (
  id             CHAR(36)  NOT NULL,
  restaurante_id CHAR(36)  NOT NULL,
  dia_semana     TINYINT   NOT NULL CHECK (dia_semana BETWEEN 0 AND 6),
  hora_apertura  TIME,
  hora_cierre    TIME,
  cerrado        BOOLEAN   DEFAULT FALSE,
  created_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                           ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_horario (restaurante_id, dia_semana),
  FOREIGN KEY (restaurante_id) REFERENCES restaurantes(id)
);

CREATE TRIGGER before_insert_horarios_restaurante
  BEFORE INSERT ON horarios_restaurante FOR EACH ROW
  SET NEW.id = IF(NEW.id IS NULL OR NEW.id = '', UUID(), NEW.id);

-- ================================================================
-- 13. TABLA DE PROMOCIONES DEL RESTAURANTE
-- ================================================================

CREATE TABLE promociones_restaurante (
  id              CHAR(36)      NOT NULL,
  restaurante_id  CHAR(36)      NOT NULL,
  titulo          VARCHAR(100)  NOT NULL,
  descripcion     TEXT,
  tipo_descuento  ENUM('porcentaje','fijo') DEFAULT 'porcentaje',
  valor_descuento DECIMAL(10,2) NOT NULL,
  fecha_inicio    DATE          NOT NULL,
  fecha_fin       DATE          NOT NULL,
  activa          BOOLEAN       DEFAULT TRUE,
  created_at      TIMESTAMP     DEFAULT CURRENT_TIMESTAMP,
  updated_at      TIMESTAMP     DEFAULT CURRENT_TIMESTAMP
                                ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  FOREIGN KEY (restaurante_id) REFERENCES restaurantes(id)
);

CREATE TRIGGER before_insert_promociones_restaurante
  BEFORE INSERT ON promociones_restaurante FOR EACH ROW
  SET NEW.id = IF(NEW.id IS NULL OR NEW.id = '', UUID(), NEW.id);

-- ================================================================
-- 14. TABLA DE RESERVAS
-- ================================================================

CREATE TABLE reservas (
  id             CHAR(36)  NOT NULL,
  restaurante_id CHAR(36)  NOT NULL,
  cliente_id     CHAR(36)  NOT NULL,
  num_personas   TINYINT   NOT NULL,
  fecha_reserva  DATE      NOT NULL,
  hora_reserva   TIME      NOT NULL,
  estado         ENUM('pendiente','confirmada','cancelada','completada')
                           DEFAULT 'pendiente',
  notas          TEXT,
  created_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                           ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  FOREIGN KEY (restaurante_id) REFERENCES restaurantes(id),
  FOREIGN KEY (cliente_id)     REFERENCES clientes(id)
);

CREATE TRIGGER before_insert_reservas
  BEFORE INSERT ON reservas FOR EACH ROW
  SET NEW.id = IF(NEW.id IS NULL OR NEW.id = '', UUID(), NEW.id);

-- ================================================================
-- 15. TABLA DE PQRS
-- ================================================================

CREATE TABLE pqrs (
  id             CHAR(36)     NOT NULL,
  cliente_id     CHAR(36)     NOT NULL,
  empleado_id    CHAR(36)     DEFAULT NULL,
  tipo           ENUM('peticion','queja','reclamo','sugerencia') NOT NULL,
  asunto         VARCHAR(150) NOT NULL,
  descripcion    TEXT         NOT NULL,
  estado         ENUM('recibida','en_gestion','resuelta','cerrada')
                              DEFAULT 'recibida',
  respuesta      TEXT,
  fecha_gestion  TIMESTAMP    NULL,
  fecha_cierre   TIMESTAMP    NULL,
  created_at     TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
  updated_at     TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
                              ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  FOREIGN KEY (cliente_id)  REFERENCES clientes(id),
  FOREIGN KEY (empleado_id) REFERENCES empleados(id)
);

CREATE TRIGGER before_insert_pqrs
  BEFORE INSERT ON pqrs FOR EACH ROW
  SET NEW.id = IF(NEW.id IS NULL OR NEW.id = '', UUID(), NEW.id);

-- ================================================================
-- 16. TABLA DE REPORTES DE CONTENIDO
-- ================================================================

CREATE TABLE reportes_contenido (
  id             CHAR(36)     NOT NULL,
  reporter_id    CHAR(36)     NOT NULL,
  tipo_contenido ENUM('publicacion','comentario','restaurante') NOT NULL,
  contenido_id   CHAR(36)     NOT NULL,
  motivo         VARCHAR(100) NOT NULL,
  descripcion    TEXT,
  estado         ENUM('pendiente','revisado','resuelto')
                              DEFAULT 'pendiente',
  created_at     TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
  updated_at     TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
                              ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  FOREIGN KEY (reporter_id) REFERENCES clientes(id)
);

CREATE TRIGGER before_insert_reportes_contenido
  BEFORE INSERT ON reportes_contenido FOR EACH ROW
  SET NEW.id = IF(NEW.id IS NULL OR NEW.id = '', UUID(), NEW.id);

-- ================================================================
-- 17. TABLA DE ACCIONES DE MODERACIÓN
-- ================================================================

CREATE TABLE acciones_moderacion (
  id             CHAR(36)  NOT NULL,
  empleado_id    CHAR(36)  NOT NULL,
  reporte_id     CHAR(36)  NOT NULL,
  accion         ENUM('aprobado','oculto','eliminado','advertido','baneado')
                           NOT NULL,
  notas          TEXT,
  created_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  FOREIGN KEY (empleado_id) REFERENCES empleados(id),
  FOREIGN KEY (reporte_id)  REFERENCES reportes_contenido(id)
);

CREATE TRIGGER before_insert_acciones_moderacion
  BEFORE INSERT ON acciones_moderacion FOR EACH ROW
  SET NEW.id = IF(NEW.id IS NULL OR NEW.id = '', UUID(), NEW.id);

-- ================================================================
-- 18. TABLA DE NOTIFICACIONES
-- ================================================================

CREATE TABLE notificaciones_cliente (
  id             CHAR(36)     NOT NULL,
  cliente_id     CHAR(36)     NOT NULL,
  tipo           ENUM('like','comentario','seguidor',
                      'respuesta_resena','promocion','reserva','pqrs')
                              NOT NULL,
  titulo         VARCHAR(200) NOT NULL,
  mensaje        TEXT,
  leida          BOOLEAN      DEFAULT FALSE,
  canal          ENUM('push','email','in_app') NOT NULL,
  created_at     TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  FOREIGN KEY (cliente_id) REFERENCES clientes(id)
);

CREATE TRIGGER before_insert_notificaciones_cliente
  BEFORE INSERT ON notificaciones_cliente FOR EACH ROW
  SET NEW.id = IF(NEW.id IS NULL OR NEW.id = '', UUID(), NEW.id);

CREATE TABLE notificaciones_empleado (
  id           CHAR(36)     NOT NULL,
  empleado_id  CHAR(36)     NOT NULL,
  tipo         ENUM('nuevo_reporte','nuevo_restaurante',
                    'escalamiento','nueva_pqrs') NOT NULL,
  titulo       VARCHAR(200) NOT NULL,
  mensaje      TEXT,
  leida        BOOLEAN      DEFAULT FALSE,
  canal        ENUM('email','in_app') NOT NULL,
  created_at   TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  FOREIGN KEY (empleado_id) REFERENCES empleados(id)
);

CREATE TRIGGER before_insert_notificaciones_empleado

  BEFORE INSERT ON notificaciones_empleado FOR EACH ROW
  SET NEW.id = IF(NEW.id IS NULL OR NEW.id = '', UUID(), NEW.id);

-- ================================================================
-- 19. TABLA DE ANALÍTICAS DEL RESTAURANTE
-- ================================================================

CREATE TABLE analiticas_restaurante (
  id                CHAR(36)     NOT NULL,
  restaurante_id    CHAR(36)     NOT NULL,
  fecha             DATE         NOT NULL,
  visitas_perfil    INTEGER      DEFAULT 0,
  total_likes       INTEGER      DEFAULT 0,
  total_comentarios INTEGER      DEFAULT 0,
  total_resenas     INTEGER      DEFAULT 0,
  rating_promedio   DECIMAL(3,2) DEFAULT 0.00,
  created_at        TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
  updated_at        TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
                                 ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_analitica (restaurante_id, fecha),
  FOREIGN KEY (restaurante_id) REFERENCES restaurantes(id)
);

CREATE TRIGGER before_insert_analiticas_restaurante
  BEFORE INSERT ON analiticas_restaurante FOR EACH ROW
  SET NEW.id = IF(NEW.id IS NULL OR NEW.id = '', UUID(), NEW.id);

-- ================================================================
-- 20. TABLA DE SESIONES DE AUTENTICACIÓN
-- ================================================================

CREATE TABLE sesiones_cliente (
  id              CHAR(36)     NOT NULL,
  cliente_id      CHAR(36)     NOT NULL,
  session_token   VARCHAR(191) UNIQUE NOT NULL,
  plataforma      ENUM('mobile','web_restaurante') NOT NULL,
  ip_address      VARCHAR(45),
  expires_at      TIMESTAMP    NOT NULL,
  activa          BOOLEAN      DEFAULT TRUE,
  created_at      TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
  updated_at      TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
                               ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  FOREIGN KEY (cliente_id) REFERENCES clientes(id)
);

CREATE TRIGGER before_insert_sesiones_cliente
  BEFORE INSERT ON sesiones_cliente FOR EACH ROW
  SET NEW.id = IF(NEW.id IS NULL OR NEW.id = '', UUID(), NEW.id);

CREATE TABLE sesiones_empleado (
  id            CHAR(36)     NOT NULL,
  empleado_id   CHAR(36)     NOT NULL,
  session_token VARCHAR(191) UNIQUE NOT NULL,

  plataforma    ENUM('web_admin','web_moderacion') NOT NULL,
  ip_address    VARCHAR(45),
  expires_at    TIMESTAMP    NOT NULL,
  activa        BOOLEAN      DEFAULT TRUE,
  created_at    TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,

  updated_at    TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
                             ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  FOREIGN KEY (empleado_id) REFERENCES empleados(id)
);

CREATE TRIGGER before_insert_sesiones_empleado
  BEFORE INSERT ON sesiones_empleado FOR EACH ROW
  SET NEW.id = IF(NEW.id IS NULL OR NEW.id = '', UUID(), NEW.id);
