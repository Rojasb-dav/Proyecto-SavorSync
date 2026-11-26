# Decisiones de Alcance (PRE-01)

> **Actualización V3.3.** V3.3 conserva flutter_map, OpenStreetMap, geolocator, latlong2, navegación externa por Google Maps y restaurantes obtenidos de Spring Boot y MySQL. Es la sustitución tecnológica propuesta, pendiente de validación académica de RF10. Las mejoras del mapa y Firebase permanecen en P1 y P1.14 respectivamente.

| Decisión | Descripción | Resolución Propuesta |
|---|---|---|
| D01 | Nombre Foodies vs SavorSync | Conservar ambos como alias documental. |
| D02 | Flutter Web vs React / Infraestructura | Conservar Flutter Web y Android, y la infraestructura actual (Aiven/Render). |
| D03 | Firebase Auth vs JWT | Conservar JWT (RF11). FCM solo para notificaciones push. |
| D04 | Búsqueda RF03 vs UC-03 | Implementar 20 por página para restaurantes y publicaciones. |
| D05 | Empleados restaurante vs empleados internos | Restringir roles administrativos internos; restaurant_admin solo administra su local. UC-10 bloqueado hasta aclaración. |
| D06 | Acceso a visitantes | Permitir acceso GET limitado al catálogo activo y reseñas de cuentas públicas, sin detalles privados. |
| D07 | PQRS y sincronización (UC-07) | La referencia corresponde al RF10. |
| D08 | Nombres DDL SQL | Usar el esquema en español y mantener la estructura original de 22 tablas. |
| D09 | iOS | No ejecutar sin entorno (macOS). Bloqueado temporalmente. |
| D10 | Lógicas de reserva, historial de comentarios | Implementar estados básicos transaccionales seguros y retención aprobada. |
| D11 | Consentimiento y retención | Requerir aceptación de términos explícita, no derivar demografía sin permiso explícito (RF07). |
| D12 | Sincronización y reportes | Ajustar en P1.13 y P1.17 con WebSockets y exportación real (Apache POI/PDFBox). |

## Decisiones autorizadas para cierre P0 — 2026-11-25

| Decisión | Resolución vigente |
|---|---|
| D13 | Correo no verificado no recibe sesión normal; sólo completa verificación o cierra sesión. |
| D14 | requested_role restaurant_admin se guarda sin privilegios; el rol efectivo cambia tras aprobación de admin_sistema. La publicación del local sigue separada. |
| D15 | `X-Platform` es metadato declarado, no prueba de dispositivo ni autoridad. |
| D16 | Google Sign-In sigue deshabilitado. No se introduce Firebase Auth ni se inicia FCM/WebSockets. |
| D17 | No se migran Aiven ni se cambian servicios remotos. Rotaciones y baseline de esquema existente requieren intervención posterior del propietario. |
| D18 | La transición de empleados existentes exige verificación individual antes de volver a iniciar sesión; no se aplica backfill de email_verified ni se crea acceso de emergencia. El propietario ejecutará el procedimiento para cuentas reales tras autorización. |
| D19 | JPEG y PNG son los únicos formatos admitidos para carga en P0; SVG/WebP y formatos activos quedan rechazados. |
| D20 | sslMode=DISABLED sólo se usa en la URL de MySQL local del contenedor de pruebas; producción requiere TLS con validación de certificados. |
| D21 | La prueba de esquema legado se realiza en esquemas aleatorios desechables y establece baseline 1 explícitamente tras inspección. No equivale a autorización de baseline en Aiven. |
| D22 | Reanudar el flujo de verificación exige la contraseña actual o un desafío previo de la misma cuenta. Las solicitudes sin prueba de identidad reciben una respuesta genérica. |
