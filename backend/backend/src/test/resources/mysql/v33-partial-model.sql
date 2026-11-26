-- Synthetic test fixture reproducing the relevant structure of the partial model.
-- All accounts, credentials and records below are fixtures.

CREATE TABLE `clientes` (
  `id` varchar(36) NOT NULL,
  `avatar_url` varchar(500) DEFAULT NULL,
  `bio` text,
  `created_at` datetime(6) DEFAULT NULL,
  `email` varchar(191) NOT NULL,
  `email_verified` bit(1) NOT NULL,
  `full_name` varchar(100) NOT NULL,
  `is_active` bit(1) NOT NULL,
  `password` varchar(255) NOT NULL,
  `phone` varchar(20) DEFAULT NULL,
  `rol` enum('admin_sistema','foodie','moderador','restaurant_admin') NOT NULL,
  `updated_at` datetime(6) DEFAULT NULL,
  `username` varchar(50) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY (`email`),
  UNIQUE KEY (`username`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `publicaciones` (
  `id` varchar(36) NOT NULL,
  `conteo_comentarios` int DEFAULT NULL,
  `contenido` text NOT NULL,
  `created_at` datetime(6) DEFAULT NULL,
  `url_imagen` varchar(500) DEFAULT NULL,
  `es_publica` bit(1) DEFAULT NULL,
  `conteo_likes` int DEFAULT NULL,
  `calificacion` double NOT NULL,
  `direccion_restaurante` varchar(255) DEFAULT NULL,
  `nombre_restaurante` varchar(150) NOT NULL,
  `estado` enum('borrador','publicada','oculta','en_revision') DEFAULT NULL,
  `updated_at` datetime(6) DEFAULT NULL,
  `cliente_id` varchar(36) NOT NULL,
  PRIMARY KEY (`id`),
  KEY (`cliente_id`),
  FOREIGN KEY (`cliente_id`) REFERENCES `clientes` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `comentarios` (
  `id` varchar(36) NOT NULL,
  `cliente_id` varchar(36) NOT NULL,
  `contenido` varchar(2000) NOT NULL,
  `created_at` datetime(6) DEFAULT NULL,
  `parent_id` varchar(36) DEFAULT NULL,
  `publicacion_id` varchar(36) NOT NULL,
  `estado` enum('activo','eliminado','oculto') DEFAULT NULL,
  `updated_at` datetime(6) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `restaurantes` (
  `id` varchar(36) NOT NULL,
  `direccion` varchar(255) DEFAULT NULL,
  `categoria` varchar(50) DEFAULT NULL,
  `ciudad` varchar(100) DEFAULT NULL,
  `created_at` datetime(6) DEFAULT NULL,
  `descripcion` text,
  `email` varchar(191) DEFAULT NULL,
  `latitud` decimal(10,8) DEFAULT NULL,
  `longitud` decimal(11,8) DEFAULT NULL,
  `nombre` varchar(100) NOT NULL,
  `owner_id` varchar(36) DEFAULT NULL,
  `telefono` varchar(20) DEFAULT NULL,
  `rango_precio` int DEFAULT NULL,
  `rating_promedio` decimal(3,2) DEFAULT NULL,
  `total_resenas` int DEFAULT NULL,
  `estado` enum('activo','pendiente','suspendido') DEFAULT NULL,
  `updated_at` datetime(6) DEFAULT NULL,
  `sitio_web` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `likes` (
  `publicacion_id` varchar(36) NOT NULL,
  `cliente_id` varchar(36) NOT NULL,
  PRIMARY KEY (`publicacion_id`,`cliente_id`),
  KEY (`cliente_id`),
  FOREIGN KEY (`publicacion_id`) REFERENCES `publicaciones` (`id`),
  FOREIGN KEY (`cliente_id`) REFERENCES `clientes` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `menu_restaurantes` (
  `id` varchar(36) NOT NULL,
  `categoria` varchar(50) DEFAULT NULL,
  `created_at` datetime(6) DEFAULT NULL,
  `descripcion` text,
  `disponible` bit(1) NOT NULL,
  `nombre` varchar(100) NOT NULL,
  `orden` int DEFAULT NULL,
  `precio` decimal(10,2) NOT NULL,
  `restaurante_id` varchar(36) NOT NULL,
  `updated_at` datetime(6) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `notificaciones_cliente` (
  `id` varchar(36) NOT NULL,
  `mensaje` text NOT NULL,
  `canal` enum('email','in_app','push') DEFAULT NULL,
  `cliente_id` varchar(36) NOT NULL,
  `created_at` datetime(6) DEFAULT NULL,
  `leida` bit(1) NOT NULL,
  `titulo` varchar(200) NOT NULL,
  `tipo` enum('comment','follow','like','menu','reservation','system') NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `pqrs` (
  `id` varchar(36) NOT NULL,
  `asunto` varchar(150) NOT NULL,
  `cliente_id` varchar(36) NOT NULL,
  `created_at` datetime(6) DEFAULT NULL,
  `descripcion` text NOT NULL,
  `empleado_id` varchar(36) DEFAULT NULL,
  `estado` enum('cerrada','en_gestion','recibida','resuelta') NOT NULL,
  `fecha_cierre` datetime(6) DEFAULT NULL,
  `fecha_gestion` datetime(6) DEFAULT NULL,
  `respuesta` text,
  `tipo` enum('peticion','queja','reclamo','sugerencia') NOT NULL,
  `updated_at` datetime(6) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `reservas` (
  `id` varchar(36) NOT NULL,
  `cliente_id` varchar(36) NOT NULL,
  `created_at` datetime(6) DEFAULT NULL,
  `estado` enum('cancelada','completada','confirmada','pendiente') NOT NULL,
  `fecha_reserva` date NOT NULL,
  `hora_reserva` time(6) NOT NULL,
  `notas` text,
  `num_personas` int NOT NULL,
  `restaurante_id` varchar(36) NOT NULL,
  `updated_at` datetime(6) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `seguidores` (
  `seguidor_id` varchar(36) NOT NULL,
  `seguido_id` varchar(36) NOT NULL,
  PRIMARY KEY (`seguidor_id`,`seguido_id`),
  KEY (`seguido_id`),
  FOREIGN KEY (`seguido_id`) REFERENCES `clientes` (`id`),
  FOREIGN KEY (`seguidor_id`) REFERENCES `clientes` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `sesiones_cliente` (
  `id` varchar(36) NOT NULL,
  `created_at` datetime(6) DEFAULT NULL,
  `expires_at` datetime(6) NOT NULL,
  `ip_address` varchar(45) DEFAULT NULL,
  `activa` bit(1) NOT NULL,
  `plataforma` enum('mobile','web_restaurante') NOT NULL,
  `session_token` varchar(191) NOT NULL,
  `updated_at` datetime(6) DEFAULT NULL,
  `cliente_id` varchar(36) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `tokens_recuperacion` (
  `id` varchar(36) NOT NULL,
  `code` varchar(6) NOT NULL,
  `email` varchar(255) NOT NULL,
  `expires_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO clientes (id,email,username,password,full_name,rol,is_active,email_verified)
VALUES ('legacy-foodie','foodie@example.test','foodie','test-hash','Synthetic customer','foodie',b'1',b'1'),
       ('legacy-owner','owner@example.test','owner','test-hash','Synthetic owner','restaurant_admin',b'1',b'1'),
       ('legacy-mod','mod@example.test','mod','test-hash','Synthetic moderator','moderador',b'1',b'1');

INSERT INTO restaurantes (id,owner_id,nombre,direccion,ciudad,categoria,estado)
VALUES ('legacy-restaurant','legacy-owner','Synthetic restaurant','Example address','Example city','Example','activo');

INSERT INTO publicaciones (id,cliente_id,contenido,nombre_restaurante,direccion_restaurante,calificacion,
                            url_imagen,es_publica,estado)
VALUES ('legacy-post','legacy-foodie','Synthetic review','Synthetic restaurant','Example address',4,
        'https://images.example.test/legacy.png',b'1','publicada');

INSERT INTO comentarios (id,cliente_id,publicacion_id,contenido,parent_id,estado)
VALUES ('legacy-reply','legacy-owner','legacy-post','Synthetic reply','legacy-comment','activo'),
       ('legacy-comment','legacy-foodie','legacy-post','Synthetic comment',NULL,'activo');

INSERT INTO menu_restaurantes (id,restaurante_id,nombre,precio,disponible,orden)
VALUES ('legacy-menu','legacy-restaurant','Synthetic item',12.50,b'1',2);

INSERT INTO reservas (id,restaurante_id,cliente_id,fecha_reserva,hora_reserva,num_personas,estado)
VALUES ('legacy-reservation','legacy-restaurant','legacy-foodie','2025-04-01','12:00:00',2,'confirmada');

INSERT INTO likes VALUES ('legacy-post','legacy-owner');
INSERT INTO seguidores VALUES ('legacy-foodie','legacy-owner');

INSERT INTO pqrs (id,cliente_id,empleado_id,tipo,asunto,descripcion,estado)
VALUES ('legacy-case','legacy-foodie','legacy-mod','peticion','Synthetic inquiry','Fixture','recibida');

INSERT INTO notificaciones_cliente (id,cliente_id,leida,titulo,mensaje,tipo)
VALUES ('legacy-note','legacy-foodie',b'0','Synthetic notification','Fixture','reservation');

INSERT INTO sesiones_cliente (id,cliente_id,activa,plataforma,session_token,expires_at)
VALUES ('legacy-session','legacy-foodie',b'1','mobile','synthetic-old-token','2025-04-01 14:00:00');

INSERT INTO tokens_recuperacion (id,email,code,expires_at)
VALUES ('legacy-code','foodie@example.test','123456','2025-04-01 14:00:00');
