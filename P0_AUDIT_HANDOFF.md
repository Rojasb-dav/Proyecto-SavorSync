# SavorSync P0 — Handoff de auditoría V3.1

> **Actualización V3.2.** La siguiente entrega registra la evidencia de MySQL aislado, el estado de cada hallazgo residual y las pendientes de producción. Este archivo conserva el informe histórico V3.1. [P0_V32_AUDIT_HANDOFF.md](P0_V32_AUDIT_HANDOFF.md)

## Identificación

- Rama: `fix/savorsync-remediation-v3`.
- Commit base auditado: `39399448b6c9a0e93157d52870b763483b0a86ab`.
- Commit de esta iteración: se confirma con `git rev-parse HEAD` al cierre de la entrega.
- Alcance: PRE-00, PRE-01, P0.1–P0.8, validación local y documentación. No se iniciaron tareas P1.
- Producción: no se conectó ni modificó Aiven, Render, Vercel, Cloudinary, Firebase o el proveedor de correo. No hubo despliegues, migraciones remotas ni push.

## Archivos de la iteración

Se modificaron los documentos raíz `API_CONTRACTS.md`, `AUDIT_FINDINGS.md`, `DATABASE_ALIGNMENT.md`, `FEATURE_INVENTORY.md`, `PLATFORM_COMPATIBILITY.md`, `REMEDIATION_PLAN.md`, `REQUIREMENTS_TRACEABILITY.md`, `SCOPE_DECISIONS.md` y `TEST_REPORT.md`; además se añadió `.env.example` con valores ficticios y esta entrega.

Backend:

- Configuración y dependencias: `backend/backend/build.gradle`, `src/main/resources/application.properties`, `application-development.properties`, `application-test.properties`.
- Configuración, controladores, seguridad y DTO: `config/DataSeeder.java`; `controller/AuthController.java`, `FileController.java`, `GlobalExceptionHandler.java`; `dto/request/RegisterRequest.java`, `EmailVerificationRequest.java`, `ForgotPasswordRequest.java`, `ResetPasswordRequest.java`; `dto/response/UserResponse.java`, `RegistrationResponse.java`; `model/Employee.java`, `PasswordResetToken.java`; `repository/ClientSessionRepository.java`, `EmployeeSessionRepository.java`, `PasswordResetTokenRepository.java`; `security/RestSecurityErrors.java`, `security/config/SecurityConfig.java`, `security/jwt/JwtAuthenticationFilter.java`, `JwtUtil.java`.
- Servicios: `service/AuthService.java`, `CloudinaryService.java`, `EmailVerificationService.java`, `IdentityService.java`, `PostService.java`, `UserService.java`; se añadieron `AccountIdentityRegistry.java`, `AuthRateLimitService.java`, `CloudinaryAssetRegistry.java`, `SecurityEmailDispatcher.java`, `SecurityEmailEvent.java`.
- Migraciones añadidas: `src/main/resources/db/migration/V1__baseline_original_schema.sql`, `V3__identity_challenges_and_rate_limits.sql`, `V4__track_cloudinary_assets.sql`, `V5__preserve_requested_account_role.sql`. La migración V2 existente no se reescribió.
- Pruebas: `config/CredentialConfigurationTest.java`, `identity/IdentityP04Test.java`, `identity/IdentityWorkflowTest.java`, `security/AuthorizationMvcTest.java`, `security/jwt/JwtAuthenticationFilterTest.java`, `service/AuthServiceSessionTest.java`, `service/UserServiceSessionTest.java`; se añadieron `controller/FileUploadP08Test.java` y `service/EmailVerificationServiceTest.java`.

Flutter:

- `mobile/lib/core/services/auth_service.dart`, `lib/providers/auth_provider.dart`, `lib/services/cloudinary_service.dart`.
- `lib/screens/auth/forgot_password_screen.dart`, `login_screen.dart`, `register_screen.dart`; se añadió `email_verification_screen.dart`.
- `lib/screens/admin/menu_management_screen.dart`, `restaurant_admin_dashboard.dart`, `posts/create_post_screen.dart`, `profile/edit_profile_screen.dart`.
- `mobile/test/auth_service_test.dart).

Los archivos locales preexistentes `.idea/caches/deviceStreaming.xml`, `backend/backend/test-out.txt`, `backend/backend/test-out2.txt` y `tatus` se conservaron y se excluyen del commit.

## Cambios realizados

- Seeder opt-in y limitado al perfil `development`; la contraseña debe existir antes de tocar la base de datos, se guarda con BCrypt y una cuenta existente no se modifica.
- Se conservaron las respuestas de autenticación con `tokenType` y `expiresInMs`, el guardado de sesión antes de responder, las huellas SHA-256 de JWT y la separación de sesiones de cliente y empleado. El filtro valida firma, vencimiento, sesión y huella, identidad, cuenta, estado activo y rol vigente; los fallos de base de datos se distinguen como indisponibilidad.
- Las rutas públicas se comparan por método y ruta. Se asigna autoridad restringida a usuarios sin verificar y se especifican reglas de autorización por rol. El encabezado de plataforma se trata como dato declarado, no como control de seguridad.
- Registro y verificación quedaron desacoplados del inicio de sesión: desafío de seis dígitos, hash BCrypt, propósito, expiración, límites de intento y reenvío, consumo transaccional y envío de correo después del commit. El rol solicitado se almacena aparte; el rol efectivo no se eleva por una selección del cliente. Los flujos de aprobación y publicación de restaurante siguen separados.
- Se incorporó Flyway y una estrategia de baseline: V1 es un baseline no destructivo para base nueva vacía; no se habilitó baseline automático. Las migraciones posteriores son aditivas y no se ejecutaron sobre producción.
- Recuperación de contraseña utiliza DTO validados, consultas por identidad y propósito, bloqueo/consumo atómico, límites persistentes, revocación de sesiones y despacho de correo posterior al commit, con respuestas genéricas.
- La carga multimedia pasa por el backend autenticado. Se eliminó la carga unsigned directa desde Flutter; el servidor comprueba formato, tamaño, MIME y contenido de imagen. Se registra la asociación del recurso y se compensa una carga si falla el registro local.
- CORS se configura mediante orígenes explícitos y errores de seguridad con JSON uniforme. La documentación describe las variables y el TLS requerido, sin cambiar servicios externos.
- Flutter ahora reporta plataforma Web/Mobile sin `dart:io` en código compartido, gestiona el flujo de verificación y errores de carga. Se mantuvo el diseño existente.

## Hallazgos y límites de auditoría

- Los hallazgos residuales del alcance descrito se abordaron en el código y se documentan en los informes actualizados.
- Los identificadores `V3-01` a `V3-07` no aparecen definidos con una correspondencia verificable en los documentos disponibles del repositorio. No se les atribuyó contenido inventado; se requiere que el propietario/auditor proporcione su definición para asociarlos.
- Al corregir fixtures, tres pruebas Flutter dejaron de asumir que una respuesta de autenticación sin `emailVerified` era válida. Se ajustaron los datos de prueba sin relajar la validación de producción.
- `clean test` no pudo completar su fase `clean`: Windows no permitió borrar archivos de build que estaban abiertos. La ejecución posterior de `test --rerun-tasks` sí terminó correctamente y se ejecutó `build` por separado. No se forzó el borrado.
- La auditoría de controles de autorización por recurso sigue parcial: la batería local no constituye una revisión exhaustiva de cada combinación de controlador, titularidad y rol.

## Contratos y datos

- Registro ya no entrega una sesión privilegiada antes de verificar correo; devuelve el estado de registro para iniciar el flujo OTP. Verificación y recuperación usan DTO y códigos de seis dígitos. Flutter consume el contrato correspondiente.
- Se conserva el contrato de login con token Bearer, duración e identidad propia. Plataforma se informa con valores admitidos por el esquema.
- V1 conserva el esquema original de 22 tablas y sus triggers para inicializar una base vacía. V3–V5 agregan metadatos de identidad, límites, seguimiento de recursos multimedia y rol solicitado. No se certificó equivalencia del esquema mediante MySQL en esta máquina.
- La actualización de una base existente necesita inspección del esquema, respaldo, comparación y autorización explícita del baseline. Aplicar estas migraciones en Aiven queda fuera de esta iteración.

## Validación ejecutada

Backend, en `backend/backend`:

- Wrapper Gradle: 9.4.1. Java 17 quedó sin cambios, conforme al toolchain declarado.
- `gradlew.bat test --no-daemon --rerun-tasks`: finalizó con código 0; 52 pruebas reportadas, 50 aprobadas y 2 omitidas. Las omitidas requieren MySQL/Docker.
- `gradlew.bat build --no-daemon`: finalizó con código 0.
- `gradlew.bat testClasses --no-daemon`: finalizó con código 0.
- `gradlew.bat clean test --no-daemon`: bloqueado al borrar archivos ocupados; no se reporta como aprobado.

Flutter, en `mobile`:

- Flutter 3.41.9 y Dart 3.11.5. `flutter doctor -v` identificó Chrome y Android SDK 37; Android reportó licencias pendientes/desconocidas.
- `flutter pub get`: finalizó con código 0.
- `flutter test`: 8/8 pruebas aprobadas.
- `flutter analyze`: no encontró errores; terminó con código 1 por 16 diagnósticos informativos preexistentes (deprecaciones, const y contexto async).
- `flutter build web --release`: finalizó con código 0.
- `flutter build apk --debug`: finalizó con código 0. No se generó APK release porque no hay configuración legítima de firma release.
- No se ejecutaron pruebas integrales en navegador ni dispositivo Android.

## Compatibilidad, seguridad y requerimientos académicos

La implementación conserva Spring Boot 3.3.4, Java 17, Flutter para Android y Web, Spring Security/JWT, BCrypt y MySQL; no incorpora Firebase Auth. Google Sign-In continúa deshabilitado. Se conservan las 22 tablas y los cuatro roles, sin activar FCM ni WebSockets.

Las correcciones respaldan los requisitos de identidad, autenticación y autorización, perfil y experiencia por rol, administración de restaurantes, publicaciones y archivos. La aprobación del rol administrativo y del establecimiento conserva su flujo diferenciado. La trazabilidad detallada está en `REQUIREMENTS_TRACEABILITY.md`; no se declara terminada la aplicación ni implementados módulos P1.

## Estado P0

| Tarea | Estado | Evidencia y límite |
|---|---|---|
| P0.1 Credenciales | IMPLEMENTADA SIN VERIFICAR | Seeder y configuración local protegidos; rotación de credenciales posiblemente expuestas depende del propietario. |
| P0.2 JWT y sesiones | IMPLEMENTADA SIN VERIFICAR | Pruebas backend y Flutter aprobadas; queda pendiente validación cruzada con MySQL real aislado. |
| P0.3 Autorización | PARCIALMENTE CORREGIDA | Reglas y pruebas MVC añadidas; revisión de cada recurso/titularidad no es exhaustiva. |
| P0.4 Identidad | IMPLEMENTADA SIN VERIFICAR | OTP y flujos cubiertos por pruebas; correo real e integración con MySQL no verificados. |
| P0.5 Migraciones | PARCIALMENTE CORREGIDA | Migraciones y estrategia preparadas; no ejecutadas contra MySQL vacío ni copia aislada del esquema. |
| P0.6 Infraestructura | IMPLEMENTADA SIN VERIFICAR | CORS y propiedades documentadas; configuración desplegada/TLS Aiven no verificados externamente. |
| P0.7 Recuperación | IMPLEMENTADA SIN VERIFICAR | Flujo cubierto por suite local; concurrencia y persistencia MySQL requieren MySQL de pruebas. |
| P0.8 Archivos | IMPLEMENTADA SIN VERIFICAR | Validaciones locales y prueba de controlador añadidas; Cloudinary real y flujos en dispositivos no ejecutados. |

## Bloqueantes externos y siguientes decisiones

- Proporcionar un MySQL aislado y Docker operativo para ejecutar migraciones sobre una base vacía y una copia del esquema legado, y completar las pruebas de sesión, identidad y recuperación.
- El propietario debe rotar cualquier credencial que haya sido expuesta y completar las variables seguras de Aiven, Render, Vercel, Cloudinary y correo.
- Configurar en despliegue únicamente orígenes CORS autorizados, TLS con verificación de certificado, secretos JWT y el proveedor de correo. Confirmar entrega transaccional sin exponer códigos.
- Probar carga y persistencia multimedia con la cuenta autorizada y validar la limpieza/manual review de recursos huérfanos.
- Aclarar el contenido de los hallazgos V3-01–V3-07 para establecer su correspondencia formal.
- El uso de los límites propuestos (5 intentos/desafío, 60 s entre reenvíos, 5 solicitudes/hora por identidad) debe revisarse con el propietario; están parametrizados/documentados como decisión técnica y no como requisito textual del manual.

## Recomendación

Entregar este cambio para auditoría independiente local. No declarar P0 completamente verificada ni autorizar avance a P1 hasta ejecutar las migraciones y pruebas MySQL en un entorno aislado, cerrar la revisión exhaustiva de autorización y resolver los bloqueantes de configuración externa. No hubo cambios de producción ni push.
