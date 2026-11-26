# Plan integral de remediación SavorSync V2

> **Actualización V3.3.** V3.3 prepara el corte del esquema parcial, integra proveedores a nivel de código y valida en instalaciones locales. El gate P0 requiere autorización y evidencia de producción del propietario según [el runbook](PRODUCTION_DEPLOYMENT_RUNBOOK.md). Se mantienen las decisiones de P1.

Referencia `3146a0e3b76adadba62193c35af10ba2eff2b023`. La rama de trabajo `fix/savorsync-remediation-v2` parte de `8a9101e2b627e609f359f92189c1cf11f85810c8`. El diagnóstico se registra en [AUDIT_FINDINGS.md](AUDIT_FINDINGS.md).

Estados autorizados: PENDIENTE, EN DESARROLLO, IMPLEMENTADA SIN VERIFICAR, PARCIALMENTE CORREGIDA, VERIFICADA Y APROBADA, BLOQUEADA. «Pendiente» en las tablas indica que esta remediación no implementó la tarea. Toda tarea pendiente tiene cambios, pruebas, resultados y commit asociado por registrar. Las columnas de alcance y dependencias describen el impacto esperado en API Spring, datos MySQL y consumidores Web/Android según la operación. iOS requiere decisión de alcance.

## P0 — Seguridad, identidad y estabilidad

| Tarea | Fallos relacionados | Estado | Problema o alcance | Archivos | Diagnóstico y cambio propuesto | Dependencias, impacto y verificación |
|---|---|---|---|---|---|---|
| P0.1 | 01, 04, 48 | PARCIALMENTE CORREGIDA | Protección de credenciales | Configuración Spring, DataSeeder, Dockerfile y exclusiones. AuthService Java/Dart, GlobalExceptionHandler y login Flutter. | Secretos externos por ambiente. Seed explícito limitado a desarrollo. Google inseguro deshabilitado. Los esquemas y servicios remotos se conservan. | Rotaciones y reutilización de credenciales requieren propietario. Pruebas locales detalladas abajo. |
| P0.2 | 17, 38, 55 | PARCIALMENTE CORREGIDA | Autenticación JWT | JwtUtil, filtro, controladores, servicios, repositorios, AuthSession, AuthResponse y flujo de sesión Flutter. | SHA-256, `jti`, persistencia antes de autenticar, validación de vigencia y rol, revocación, 401/403 y restauración desde `/auth/me`. | Validar plataformas y cotejar la separación cliente/empleado en P0.5. Véase TEST_REPORT.md. |
| P0.3 | 02, 05–08, 10, 12, 14, 15 | PARCIALMENTE CORREGIDA | Roles y propiedad | Spring Security, controladores, servicios de usuario/publicaciones, repositorios y pantallas de administración y perfil. | Permisos por método, identidad desde la sesión, PQRS privadas y alcance por titular o propietario. | 30 verificaciones backend. Pendientes de cotejo de reglas académicas y ejecución multiplataforma en TEST_REPORT.md. |
| P0.4 | 03, 39, 43 | PENDIENTE | Registro e identidad | AuthController, AuthService, RegisterRequest, UpdateProfileRequest, UserService, formulario de registro, perfil y pantallas de moderación. | Foodie público, flujo aprobado de restaurante, alta de moderador con autorización, verificación de correo y restricciones de plataforma. | P0.2–P0.3. Aprobación de reglas de registro privilegiado y plataforma cuando el código difiera. |
| P0.5 | 24, 30, 38, 45–47, 53 | PENDIENTE | Alineación SQL | schema_foodies_db.sql, model, repository, DTO, resources y Gradle. | Cotejo de las 22 tablas y relaciones. Sesiones de clientes/empleados, menú, posts e imágenes. Migraciones versionadas y validación no destructiva. | Modelo académico, copia aislada y esquema autorizado de Aiven. Véase DATABASE_ALIGNMENT.md. |
| P0.6 | 28, 29, 32 | PENDIENTE | Infraestructura segura | SecurityConfig, GlobalExceptionHandler, configuración JVM, Aiven/Render/Vercel y cliente REST. | CORS por ambiente, HTTPS, TLS con certificado, puertos y sanitización de errores. | Dominios autorizados y acceso de lectura a configuración y evidencia de nube. |
| P0.7 | 25, 26, 49 | PENDIENTE | Recuperación de contraseña | AuthService, PasswordResetToken, repositorio, DTO y pantallas de recuperación. | Códigos protegidos, límites, uso único, transacciones y entrega verificable. Revocar sesiones y completar flujo web/Android. | P0.2, P0.5 y servicio de correo de pruebas. |
| P0.8 | 27 | PENDIENTE | Cloudinary y archivos | FileController, CloudinaryConfig/Service, servicio Flutter y pantallas que cargan medios. | Validación de contenido, extensión y tamaño, autorización y cuotas. Gestión de huérfanos y evaluación de subidas firmadas. | P0.3 y Cloudinary de pruebas. Probar navegador, cámara y galería. |

## P1 — Integración funcional y persistencia

| Tarea | Fallos relacionados | Estado | Problema o alcance | Archivos | Diagnóstico y cambio propuesto | Dependencias, impacto y verificación |
|---|---|---|---|---|---|---|
| P1.1 | Contratos transversales | PENDIENTE | API REST uniforme | Controladores, DTO, modelos Dart, servicios y Dio directo. | Matriz de métodos, JSON, encabezados, fechas y códigos. Compatibilidad temporal y OpenAPI. | Gate P0, inventario en API_CONTRACTS.md y pruebas de deserialización. |
| P1.2 | 09, 19, 31, 32 | PENDIENTE | Errores transparentes | ApiService, AuthService, NotificationService, Cloudinary, y pantallas. | Estados vacío/error/carga distintos. Retirar datos de respaldo y limitar reintentos a operaciones seguras. | P1.1. Probar 401, timeout, caída y reconexión. |
| P1.3 | 10, 11, 20, 23, 36, 40, 44 | PENDIENTE | Reservas | ReservationController, DTO, entidad, repositorio, modales, perfil y shell. | Consultas propias y administrativas, DTO estable, validación de estado y horarios, capacidad, concurrencia y notificación. | P0.3/P0.5 y reglas aprobadas de disponibilidad. Android y web sobre la misma reserva. |
| P1.4 | 12, 13, 41 | PENDIENTE | Restaurantes | RestaurantController, entidad/repositorio, dashboard y pantallas públicas. | Separar crear, editar y cambiar estado. Propiedad, listado, validación, imágenes y baja con integridad referencial. | P0.3/P0.5/P0.8. Edición sin duplicación y visibilidad cruzada. |
| P1.5 | 21, 45 | PENDIENTE | Menús persistentes | MenuItem, repositorio, controlador, DTO y MenuManagementScreen. | CRUD y disponibilidad persistentes, restaurante autorizado, validación, recarga y menú visible a consumidores. | P0.5 y P1.4. Crear, editar y borrar desde panel y comprobar en móvil. |
| P1.6 | 08, 09, 34, 46, 50 | PENDIENTE | Contenido social | PostController, PostService, DTO y modelos Dart de posts/comentarios, pantallas sociales. | Identidad desde sesión, restaurante e imágenes persistidos, visibilidad, moderación, conteos, likes únicos y transacciones. | P0.3/P0.5/P0.8. Posts, cámara, galería, comentarios, likes y moderación en ambos clientes. |
| P1.7 | 14, 22 | PENDIENTE | PQRS | PqrsController, DTO/entidades y pantallas create_pqrs/pqrs_management. | Titular y personal autorizado, respuesta persistente, estado/transiciones, fechas y notificación. | P0.3/P0.5. Crear en Android y responder en panel web. |
| P1.8 | 15, 22, 42 | PENDIENTE | Notificaciones | NotificationController, DTO/entidades, NotificationService y notification_center_screen. | Rutas compartidas, marcados y borrados propios, alcance del propietario y actualización real. Push y broadcast sujetos al alcance original. | P0.3/P0.5, P1.3/P1.7 y requisitos de notificación. |
| P1.9 | 05–07, 16, 35, 43 | PENDIENTE | Perfiles y relaciones | UserController/Service, FollowController, DTO, UserModel, perfil y favoritos. | Separar datos públicos y privados. Edición segura, avatar, seguimiento y favoritos persistentes, gobierno y revocación. | P0.2–P0.5. Aislamiento de cuentas y sincronización entre clientes. |
| P1.10 | 18, 48 | PENDIENTE | Google Sign-In real | AuthService Java/Dart, botón de login, configuración OAuth web/Android y eventual iOS. | Configurar clientes directamente en Google OAuth. Validar el token de identidad en Spring, vincular la cuenta y emitir y persistir una sesión SavorSync. | Clientes OAuth, paquete y huellas Android, dominios web y alcance iOS. Mantener la contención mientras esté pendiente. |
| P1.11 | 17, 35, 38 | PENDIENTE | Almacenamiento de sesión | TokenStorage, SharedPreferences, ApiService y AuthProvider. | Almacenamiento nativo y estrategia de navegador. Expiración, recuperación, revocación y separación por cuenta. | P0.2. Recarga web y reapertura Android. |
| P1.12 | 27, 28, 31, 51, 52 | PENDIENTE | Conectividad multiplataforma | ApiService, Cloudinary, AndroidManifest, Gradle, iOS, web y plugins. | URLs por ambiente, timeout/reconexión, permisos, geolocalización, selección de archivos y dependencias heredadas. | P0.6/P0.8. Probar Android/web con red lenta y sin conexión. |

## P2 — Experiencia y calidad

| Tarea | Fallos relacionados | Estado | Problema o alcance | Archivos | Diagnóstico y cambio propuesto | Dependencias, impacto y verificación |
|---|---|---|---|---|---|---|
| P2.1 | 37, 50 | PENDIENTE | Interfaces por rol | RoleBasedShell, rutas y pantallas administrativas. | Separar moderador/sistema, funciones autorizadas, NavRail/barra inferior, diálogos, accesibilidad, tamaños táctiles. | Gate P1 y restricciones originales. Verificar tamaños web y Android. |
| P2.2 | 33 | PENDIENTE | Consultas y paginación | Repositorios, DTO, índices MySQL, servicios y listas Flutter. | Medir N+1 y consumo. Paginar posts, restaurantes, usuarios, reservas, PQRS y notificaciones. | P1.1 y P0.5. Comparar métricas y verificar deserialización. |
| P2.3 | 24 y contratos | PENDIENTE | DTO y modelos | DTO Java y modelos Dart de usuarios, auth, posts, comentarios, reservas, restaurantes, menú, notificaciones y PQRS. | Alinear enum, obligatoriedad, tipos, longitudes, alias y fechas. Pruebas JSON bilaterales. | P1.1 y P0.5. Fixtures de contratos aislados. |
| P2.4 | 54 y cobertura transversal | PENDIENTE | Pruebas automatizadas | Backend test, mobile/test, integración y configuración de MySQL. | Consolidar unitarias, seguridad, HTTP, datos, transacciones, contratos, modelos, widgets, navegación y conectividad. | MySQL aislado y herramientas de pruebas web/Android. Evaluar Testcontainers. |

## P3 — Validación multiplataforma y despliegue

| Tarea | Fallos relacionados | Estado | Problema o alcance | Archivos | Diagnóstico y cambio propuesto | Dependencias, impacto y verificación |
|---|---|---|---|---|---|---|
| P3.1 | Transversal | PENDIENTE | Compilar y probar backend | Wrapper Gradle, build.gradle, test y reportes. | Ejecutar clean build y test. Registrar resultados, advertencias, dependencias y fallos. | Gate P2 y MySQL aislado. |
| P3.2 | 51, 52 | PENDIENTE | Compilar Flutter | pubspec/lock, Android, web, iOS y SDK. | Doctor, pub get, analyze, test, Web release, APK release, bundle y iOS release si corresponde. | SDK/Java/Flutter compatibles, herramientas Android y macOS/firma si aplica. |
| P3.3 | Transversal | PENDIENTE | Validación móvil | APK o dispositivo Android, pantallas, permisos y API. | Validar identidad, recuperación/Google, restaurante, posts/galería/cámara, comunidad, reservas/tickets, PQRS, perfil, GPS y red. | Artefacto Android, entorno aislado, API y servicios de prueba. |
| P3.4 | Transversal | PENDIENTE | Validación web | Build Flutter Web, navegador, CORS y paneles. | Validar identidad, contenido, reservas, PQRS, notificaciones, perfiles y paneles de restaurante, moderación y sistema. | Artefacto Web, dominios/entorno de prueba y roles aprobados. |
| P3.5 | Transversal | PENDIENTE | Pruebas cruzadas | Android y Web conectados al mismo backend/MySQL de prueba. | Ejecutar las 18 pruebas del plan: posts bidireccionales, reservas, menú CRUD, PQRS, perfil, favoritos, sesiones, moderación, medios, caída y reapertura. | P3.3/P3.4 y cuentas de prueba autorizadas. |
| P3.6 | Transversal | PENDIENTE | Validación de autorización | Spring Security, cada controlador, servicios, datos y cuentas autorizadas. | Probar respuestas por identidad, rol, estado del JWT, titularidad, campos de perfil/registro, entradas inválidas y archivos. | Ambiente controlado y P0.2–P0.5. |
| P3.7 | Transversal | PENDIENTE | Servicios de nube | Aiven, Render, Vercel, Cloudinary, Google y correo. | Comprobar configuración, versión, TLS, SQL, backups, ejecución y persistencia. | Acceso autorizado. Despliegue o cambios requieren autorización. |
| P3.8 | Transversal | PENDIENTE | Documentación final | README, arquitectura, modelo, contratos, pruebas y despliegue. | Documentar implementación comprobada, permisos, variables por ambiente, instalación, compilación, servicios y manuales. | Evidencia de P3; actualizar README al final. |

## Control de fase

- Esta ejecución llega hasta P0.3. P0.4 queda a la espera de autorización expresa. Flutter Web en Vercel y Flutter Android comparten Spring Boot en Render y MySQL en Aiven.
- Gate P0. Verificar autenticación, revocación, propiedad, roles y persistencia sobre un esquema compatible. Solicitar autorización para empezar P1.
- Gate P1. Verificar los contratos de escritura y lectura de Flutter, operaciones reales y persistencia transversal. Solicitar autorización para empezar P2.
- Gate P2. Validar interfaz, consultas, DTO y cobertura automatizada. Solicitar autorización para empezar P3.
- P3 requiere evidencia de los 18 escenarios cruzados, autorización, servicios de nube y compilaciones por plataforma, además de la aprobación previa para cualquier despliegue.
- Conservar todos los datos y tablas. Comparar script, modelo académico y esquema de Aiven antes de migrar. Los cuatro roles quedan sujetos a la matriz de permisos original y a controles en Spring.

## Evidencias

- [AUDIT_FINDINGS.md](AUDIT_FINDINGS.md)
- [API_CONTRACTS.md](API_CONTRACTS.md)
- [DATABASE_ALIGNMENT.md](DATABASE_ALIGNMENT.md)
- [PLATFORM_COMPATIBILITY.md](PLATFORM_COMPATIBILITY.md)
- [TEST_REPORT.md](TEST_REPORT.md)

## P0.1 en la rama de remediación

**Prioridad crítica. Estado PARCIALMENTE CORREGIDA.** El código ya toma las credenciales detectadas desde el entorno. Se retiraron dos valores predeterminados de uso en cuentas (seed y Google). Se añadieron exclusiones para archivos locales de secretos en Git y en ambos contextos de Docker. Los manejadores de autenticación y errores generales ya no registran el texto crudo de esas excepciones.

| Entorno | Configuración de P0.1 |
|---|---|
| Desarrollo | `SPRING_PROFILES_ACTIVE=development`. Backend enlazado a loopback. Inyectar un conjunto local de variables. El seed opcional requiere `APP_SEED_MODERATOR_ENABLED=true` y `APP_SEED_MODERATOR_PASSWORD` con una contraseña propia de desarrollo. |
| Pruebas | `SPRING_PROFILES_ACTIVE=test`. Backend enlazado a loopback. Inyectar solo variables de instancias y cuentas de prueba. Las pruebas acotadas de P0.1 no requieren MySQL ni servicios externos. |
| Producción | `SPRING_PROFILES_ACTIVE=production`, con secretos inyectados por Render y el puerto de `PORT` cuando esté configurado. El seed no se activa en este perfil. |

Inyectar `SPRING_DATASOURCE_URL`, `SPRING_DATASOURCE_USERNAME`, `SPRING_DATASOURCE_PASSWORD`, `APP_JWT_SECRET`, `CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_API_KEY`, `CLOUDINARY_API_SECRET`, `SPRING_MAIL_USERNAME` y `SPRING_MAIL_PASSWORD`. Mantener un conjunto de valores distinto por ambiente. `APP_JWT_SECRET` debe aportar al menos 32 bytes para HS256. La URL JDBC debe identificar el servicio y sus parámetros de conexión, con usuario y contraseña en sus variables respectivas.

**Impacto.** El arranque de Spring requiere configuración externa. MySQL conserva sus tablas y registros. Flutter Web y Android mantienen correo y contraseña, y el botón Google queda temporalmente deshabilitado hasta que exista validación del lado servidor. El bloqueo reside en las rotaciones, la revisión de cuentas potencialmente afectadas y la validación en nube. Véanse [AUDIT_FINDINGS.md](AUDIT_FINDINGS.md) y [TEST_REPORT.md](TEST_REPORT.md).

**Commit asociado.** Sin commit. Los cambios permanecen en el árbol de trabajo de la rama de remediación junto con las ediciones locales iniciales.

## P0.2 en la rama de remediación

**Prioridad crítica. Estado PARCIALMENTE CORREGIDA.** El backend emite un JWT con `jti` único, guarda una huella compacta y comprueba la persistencia antes de responder al cliente. Usa el mismo vencimiento en la sesión y el JWT. El filtro verifica la identidad y el rol actual sobre los que se construye el contexto de seguridad. El endpoint `GET /api/v1/auth/me` permite restaurar sesiones Web y Android con la misma identidad.

**Impacto.** Se conserva `sesiones_cliente` sin modificar el DDL. La transición requiere volver a autenticarse para las sesiones anteriores. Spring distingue 401, 403 y los fallos temporales de consulta de sesión. Flutter elimina la credencial rechazada y ofrece reintento ante fallos temporales. Si no puede confirmar la revocación en el servidor, informa el alcance local del cierre.

**Pendientes.** Verificación funcional en navegador y dispositivo, reconciliación de `sesiones_empleado` en P0.5, recuperación integral en P0.7 y estrategia de almacenamiento por plataforma en P1.11. Los resultados están en [TEST_REPORT.md](TEST_REPORT.md).

**Commit asociado.** Cambios locales en la rama de remediación.

## P0.3 en la rama de remediación

**Prioridad crítica. Estado PARCIALMENTE CORREGIDA.** Spring protege los cambios de estado y el borrado según rol. Los identificadores para crear publicaciones, comentarios, restaurantes, reservas y PQRS provienen de la sesión. Las consultas privadas se acotan a la cuenta y las del panel de reservas a sus restaurantes.

- `foodie` puede crear reservas y PQRS propias. El contacto personal de perfiles de terceros se omite.
- `restaurant_admin` administra el menú y las reservas de sus establecimientos y puede registrar locales pendientes. La visibilidad privada de restaurantes se acota a su propietario y al personal autorizado.
- `moderador` puede gestionar PQRS, aprobar restaurantes y suspender o reactivar cuentas de consumidores y administradores de restaurante. El borrado definitivo de cuentas queda en administración del sistema. La interfaz de aprobaciones muestra el borrado de restaurantes a administración del sistema. El backend conserva la opción para el propietario autorizado.
- `admin_sistema` puede ejercer las operaciones de gobierno previstas en esta tarea. Las notificaciones se consultan y modifican por titular. Su creación directa requiere administración del sistema.

Los ajustes de Flutter ocultan controles de borrado que el rol ya no puede usar y eliminan la solicitud de reservas privadas al visitar perfiles ajenos. Las reglas académicas y las operaciones de moderación destructiva requieren cotejo explícito. La validación en Android y la integridad referencial de algunos borrados siguen pendientes. Se mantuvieron las tablas y el esquema. [TEST_REPORT.md](TEST_REPORT.md).

**Commit asociado.** Cambios locales en la rama de remediación. El próximo punto es P0.4, sujeto a autorización.

## Actualización autorizada V3.1 — 2026-11-25

Este addendum es el estado vigente para la rama `fix/savorsync-remediation-v3`, con base `39399448b6c9a0e93157d52870b763483b0a86ab`. Las secciones V2 anteriores se conservan como historial y sus referencias a `main`, V2, resultados y estados no describen esta ejecución. No se inició P1.

| Tarea | Estado V3.1 | Evidencia y límite |
|---|---|---|
| P0.1 | IMPLEMENTADA SIN VERIFICAR | Secretos por variables, seeder sólo `development & !production`, opt-in y contraseña requerida. Pruebas de configuración. Rotación de valores previamente expuestos requiere acción del propietario. |
| P0.2 | IMPLEMENTADA SIN VERIFICAR | Huella de JWT, sesión SQL antes de respuesta, validación de cuenta/rol/expiración, roles cliente/empleado, logout y revocación por titular. Pruebas unitarias; recorridos reales Web/Android y MySQL pendientes. |
| P0.3 | PARCIALMENTE CORREGIDA | ROLE_UNVERIFIED no obtiene rutas protegidas, reglas HTTP exactas y pruebas MVC seleccionadas. No se probó la matriz completa de controladores y roles con MySQL. |
| P0.4 | IMPLEMENTADA SIN VERIFICAR | OTP de seis dígitos, perfil no verificado sin sesión, desafío de un uso, selección de rol persistida y aprobación de restaurant_admin separada. Faltan MySQL y SMTP de prueba. |
| P0.5 | PARCIALMENTE CORREGIDA | Flyway y V1–V5 aditivas/no destructivas incorporadas; ddl-auto=validate. No hay MySQL/Docker local para ejecutar migraciones ni validar mapeos y datos. No se contactó Aiven. |
| P0.6 | IMPLEMENTADA SIN VERIFICAR | CORS por lista explícita, errores JSON sanitizados y TLS documentado. No se inspeccionaron Render, Vercel ni Aiven; CORS no es control para clientes nativos. |
| P0.7 | IMPLEMENTADA SIN VERIFICAR | DTO validados, BCrypt, límites durables, consumo bloqueado, propósito separado, revocación y correo después del commit. No se validó concurrencia contra MySQL ni SMTP real. |
| P0.8 | IMPLEMENTADA SIN VERIFICAR | Proxy autenticado, JPEG/PNG binario, tamaño/resolución, tracking aditivo de huérfanos y eliminación unsigned en Flutter. Cloudinary y selector/cámara/galería no se ejecutaron. |

V1 reconstruye las 22 tablas originales sólo en una base vacía. Una base existente requiere respaldo y cotejo; no hay baseline automático ni migración de producción.

## Addendum V3.2 — 2026-11-25

La rama local aplicó V1–V5 y validó Hibernate con MySQL 8.0 de pruebas. Se probó también baseline legado explícito, datos sintéticos retenidos y fallo controlado ante colisión de identidad. Los dos recorridos usan esquemas separados; se dejó intacto el esquema inicial con migración incompleta. Evidencia en MYSQL_MIGRATION_VALIDATION.md.

Los residuales V3.2-01 a V3.2-06 se corrigen en propiedad de assets, reenvío de requestedRole, transición individual de empleados, allowlist de autorización, fixtures MySQL y pruebas de SessionMySqlTest. El estado por hallazgo, suite Java/Flutter y límites externos quedan en P0_V32_AUDIT_HANDOFF.md. No se cambia a P1; no se modifican servicios externos ni se migra Aiven.


