# Inventario de Funcionalidades y Feature Flags (PRE-01)

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
