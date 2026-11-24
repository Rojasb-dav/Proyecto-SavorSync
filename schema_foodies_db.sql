-- ================================================================
-- SAVORSYNC DATABASE SCHEMA - AIVEN MYSQL / LOCAL
-- ================================================================

CREATE DATABASE IF NOT EXISTS foodies_db;
USE foodies_db;

-- ================================================================
-- 1. TABLA DE CLIENTES / USUARIOS
-- ================================================================

CREATE TABLE IF NOT EXISTS clientes (
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

CREATE TRIGGER IF NOT EXISTS before_insert_clientes
  BEFORE INSERT ON clientes FOR EACH ROW
  SET NEW.id = IF(NEW.id IS NULL OR NEW.id = '', UUID(), NEW.id);

-- ================================================================
-- 2. TABLA DE LIKES
-- ================================================================

CREATE TABLE IF NOT EXISTS likes (
  id             CHAR(36) NOT NULL,
  cliente_id     CHAR(36) NOT NULL,
  publicacion_id CHAR(36) NOT NULL,
  created_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_like (cliente_id, publicacion_id)
);

-- ================================================================
-- 3. TABLA DE COMENTARIOS
-- ================================================================

CREATE TABLE IF NOT EXISTS comentarios (
  id             CHAR(36)     NOT NULL,
  publicacion_id CHAR(36)     NOT NULL,
  cliente_id     CHAR(36)     NOT NULL,
  parent_id      CHAR(36)     DEFAULT NULL,
  contenido      VARCHAR(2000) NOT NULL,
  estado         VARCHAR(50)  DEFAULT 'activo',
  created_at     TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
  updated_at     TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
                              ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id)
);

-- ================================================================
-- 4. TABLA DE SEGUIDORES
-- ================================================================

CREATE TABLE IF NOT EXISTS seguidores (
  seguidor_id CHAR(36) NOT NULL,
  seguido_id  CHAR(36) NOT NULL,
  PRIMARY KEY (seguidor_id, seguido_id)
);

-- ================================================================
-- 5. TABLA DE NOTIFICACIONES
-- ================================================================

CREATE TABLE IF NOT EXISTS notificaciones_cliente (
  id             CHAR(36)     NOT NULL,
  cliente_id     CHAR(36)     NOT NULL,
  tipo           ENUM('like','comentario','seguidor',
                      'respuesta_resena','promocion','reserva','pqrs')
                              NOT NULL,
  titulo         VARCHAR(200) NOT NULL,
  mensaje        TEXT,
  leida          BOOLEAN      DEFAULT FALSE,
  canal          ENUM('push','email','in_app') NOT NULL DEFAULT 'in_app',
  created_at     TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id)
);
