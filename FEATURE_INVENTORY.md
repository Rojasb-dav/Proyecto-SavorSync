# Inventario de Funcionalidades y Feature Flags (PRE-01)

> **Actualización V3.3.** V3.3 añade correo Brevo de producción, alta administrativa por consola y health de dependencias críticas. Cloudinary usa carpeta firmada del backend. El perfil Foodie admite solicitar administración. Firebase y las correcciones funcionales del mapa permanecen pendientes.

| Funcionalidad | RF / UC | Estado | Clasificación | Dependencia | Pruebas |
|---|---|---|---|---|---|
| Autenticación JWT | RF11 | Parcial | REQUIRED | P0.2 | Fallando por cambio DDL |
| Cuentas de Empleados | RF06 | Parcial | REQUIRED | P0.4 | - |
| Google Sign-In | - | Deshabilitado | FUTURE_DISABLED | P1.10 | - |
| Carga de Archivos | RF02 | Parcial | REQUIRED | P0.8 | Cloudinary |
| Gestión de Reservas | RF05 | Parcial | REQUIRED | P1.3 | - |
| Gestión de Menús | RF05 | Parcial | REQUIRED | P1.5 | - |
| Publicaciones / Feed | RF02, RF04 | Parcial | REQUIRED | P1.6 | - |
| PQRS | RF09 | Parcial | REQUIRED | P1.7 | - |
| Notificaciones In-App | RF08 | Parcial | REQUIRED | P1.8 | - |
| Analítica y Reportes | RF07 | Pendiente | REQUIRED | P1.17 | - |
| Notificaciones FCM | RF08 | Pendiente | REQUIRED | P1.14 | FCM / SMTP |
| WebSockets | RF10 | Pendiente | REQUIRED | P1.13 | Spring WebSockets |

**Flags en Flutter:**
- `FEATURE_GOOGLE_SIGN_IN` = false
- `FEATURE_FOODIE_WEB` = false (se usará condicional para portal web de clientes).

## Estado de remediación V3.1 — 2026-11-25

| Funcionalidad | Estado local observado | Alcance de prueba |
|---|---|---|
| Registro, login, OTP y restauración JWT | Implementado para Web/Android; sin sesión si no está verificado | Tests locales; falta recorrido con proveedor de correo de prueba |
| Recuperación de contraseña | DTO, OTP hash, límites, consumo y revocación | Sin MySQL concurrente ni SMTP real |
| Autorización | ROLE_UNVERIFIED y reglas por método/rol | Pruebas MVC seleccionadas; falta auditoría completa por endpoint |
| Migraciones | Flyway V1–V5; se conservan 22 tablas originales | MySQL/Docker no disponibles; no desplegado |
| Archivos Cloudinary | Proxy autenticado, JPEG/PNG, validación y tracking de huérfanos | Tests locales; Cloudinary no ejecutado |
| Google Sign-In / Firebase Auth | Deshabilitado / no implementado | JWT permanece como sistema de autenticación |
| WebSockets / FCM | No iniciado | Diferido a P1; no hubo cambios

## Estado residual V3.2 — 2026-11-25

| Funcionalidad | Estado | Evidencia |
|---|---|---|
| Registro, reenvío y tipo de cuenta | Implementado y probado en MySQL; tipo solicitado persiste entre registro, reenvío y aprobación sin privilegios automáticos. | SessionMySqlTest |
| Verificación de empleados legacy | Implementada y probada con fixtures moderador/admin_sistema no verificados; no se activa verificación masiva. | SessionMySqlTest |
| Publicaciones y asociación de imágenes | Asociación exige registro de asset y dueño; reuso en otro recurso/usuario rechazado y rollback probado. | SessionMySqlTest |
| Matriz de autorización | Reglas explícitas por método y rol, servicios aplican titularidad/estado, rutas no listadas denegadas. | AuthorizationMvcTest, matriz AUTHORIZATION_MATRIX.md |
| Migraciones | Flyway V1–V5 probadas desde cero y baseline legado con colisiones controladas; JPA valida contra esquema. | MysqlMigrationValidationTest, MysqlLegacyBaselineValidationTest, MYSQL_MIGRATION_VALIDATION.md |
| Cloudinary real | No se ejecutó cuenta externa; JPEG/PNG backend y autorización comprobados localmente. | Sin verificación de proveedor |
| Flutter Web / Android | Estado final y análisis documentados en P0_V32_AUDIT_HANDOFF.md. | Tests/build locales, sin E2E físico |
| FCM/WebSockets/Firebase Auth | Sin iniciar; Firebase Auth no sustituye Spring Security/JWT. | Diferido, fuera de V3.2 |
