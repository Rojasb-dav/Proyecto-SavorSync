# Decisiones de Alcance (PRE-01)

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
