# Matriz de Trazabilidad Académica

Basado en el manual técnico RF01-RF11 y UC-01 al UC-14, RNF-PERF a RNF-LEGAL.

| ID | Requerimiento / Subrequisito | Estado Actual | Tarea Plan |
|---|---|---|---|
| RF01 | Registro diferenciado, verificación, perfil, recuperación, sesiones | Parcial (P0.1, P0.2) | P0.2, P0.4, P0.7 |
| RF02 | Reseñas (500 chars, 1-5 fotos, rating, preview, editar 24h) | Pendiente | P1.6, P1.13 |
| RF03 | Búsqueda/filtros/mapa, 20 por página, feed | Pendiente | P1.15 |
| RF04 | Likes únicos, comentarios, follow, notificaciones | Pendiente | P1.6, P1.9 |
| RF05 | Aprobación de restaurantes, perfiles, menú, horarios | Pendiente | P1.3, P1.6, P1.17 |
| RF06 | Moderación, empleados, penalizaciones, reportes | Pendiente | P0.3, P1.16 |
| RF07 | Inteligencia de negocios, visitas, PDF/Excel, programación | Pendiente | P1.17 |
| RF08 | Centro de notificaciones, filtros, push, correo | Pendiente | P1.8, P1.14 |
| RF09 | PQRS: radicación, estados, respuesta, avisos | Pendiente | P1.7, P1.14 |
| RF10 | Maps, Cloudinary, FCM, SMTP, WebSockets, analítica | Pendiente | P1.12, P1.14 |
| RF11 | BCrypt, JWT, roles, sesiones, verificación de email | Parcial | P0.2, P1.11 |

## Requerimientos No Funcionales (RNF)

| ID | Descripción | Estado Actual |
|---|---|---|
| RNF-PERF | Rendimiento y velocidad de carga (<2s) | Pendiente de pruebas |
| RNF-USA | Usabilidad y roles (accesibilidad, responsive) | Pendiente |
| RNF-SEC | Seguridad (JWT, CORS, permisos) | En progreso (P0.3, P0.6) |
| RNF-CONF | Confiabilidad (resiliencia, manejo de errores) | Pendiente |
| RNF-MANT | Mantenibilidad (pruebas automatizadas, DTOs) | En progreso |
| RNF-PORT | Portabilidad (Android, Web) | En progreso |
| RNF-LEGAL| Requisitos legales (consentimiento, privacidad) | Pendiente (P1.18) |

## Corte de trazabilidad P0 V3.1 — 2026-11-25

Este corte cubre seguridad e identidad. No declara terminados los RF funcionales ni inicia P1.

| Requerimiento | Trazabilidad actual | Estado |
|---|---|---|
| RF01 | Registro, verificación, perfil propio y recuperación bajo Spring Security/JWT; Flutter Web/Android comparte el contrato. | PARCIALMENTE CORREGIDA |
| RF05 | Solicitud de administración ligada al tipo solicitado y aprobación separada; publicación del restaurante queda pendiente. | PARCIALMENTE CORREGIDA |
| RF06 | Cuatro autoridades separadas; matriz completa de módulos y empleados internos queda fuera de P0. | PARCIALMENTE CORREGIDA |
| RF11 | BCrypt, JWT con huella persistida, revocación, verificación y restricciones por rol; sin MySQL ni recorrido real cruzado. | IMPLEMENTADA SIN VERIFICAR |
| RNF-SEC | Secretos por entorno, CORS explícito, errores sanitizados, OTP/recuperación limitada y upload validado. | IMPLEMENTADA SIN VERIFICAR |
| RNF-PORT | Flujos Flutter compartidos entre Web/Android sin dart:io en auth/subida. Los builds se reportan separadamente. | IMPLEMENTADA SIN VERIFICAR |

Se conservan las 22 tablas originales. Las migraciones V1–V5 no se ejecutaron en MySQL.
