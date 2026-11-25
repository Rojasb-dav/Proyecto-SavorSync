# Entrega de auditoría P0 V3.2

Rama `fix/savorsync-remediation-v3`, base `8559f23732d04759e1c0787c500c0e0e888a78cc`. Alcance local en Spring Boot, Flutter y MySQL de pruebas. Los informes V3.1 permanecen como antecedentes.

## Hallazgos

| Hallazgo | Estado | Evidencia y límites |
|---|---|---|
| V3.2-01 Titularidad de imágenes | Verificado localmente para publicaciones y avatares | El backend exige una URL exacta registrada para la cuenta. La asociación y la escritura comparten transacción. MySQL comprobó rechazo de URL ajena y arbitraria, reutilización en otro recurso, repetición sobre el mismo recurso, rollback y conservación de avatares históricos. No hay una ruta de asociación de imágenes en los controladores actuales de restaurantes y menús. Las subidas sin asociación quedan identificables en el registro y requieren revisión antes de borrar. |
| V3.2-02 Restauración de tipo solicitado | Verificado localmente | Flutter guarda correo, desafío y tipo de cuenta pendiente. La pantalla inicial recupera el flujo. El reenvío conserva `requestedRole`. La solicitud desde el perfil y la aprobación administrativa son operaciones separadas. MySQL comprobó que el solicitante sigue como Foodie hasta aprobarse, que su sesión se revoca al cambiar el rol y que la del aprobador sigue activa. |
| V3.2-03 Transición de empleados | Verificado localmente con correo simulado | `moderador` y `admin_sistema` existentes completaron la verificación individual con su contraseña y un OTP. La sesión normal se emite tras confirmar correo. La entrega SMTP real y el primer acceso de cuentas reales requieren coordinación del propietario. |
| V3.2-04 Autorización por recurso | Parcialmente corregida y probada | Se sustituyó la regla general de roles por una lista explícita y denegación por defecto. Las pruebas cubren escrituras sociales por rol, titularidad de perfiles, restaurantes, menús, reservas, notificaciones y PQRS, y visibilidad pública de comentarios y menús. La matriz documenta las reglas y la cobertura disponible por ruta. |
| V3.2-05 Migraciones y persistencia | Verificado localmente | Flyway aplicó V1–V5, validó el historial y Hibernate validó el esquema. El baseline legado conservó las relaciones y filas sintéticas. Una colisión normalizada detuvo V3 con DDL parcial. Las pruebas MySQL cubrieron consumo único, intentos persistentes, reenvío y emisión concurrentes, revocación, cuotas y una carrera de unicidad entre identidades cliente y empleado. |
| V3.2-06 Contratos de SessionMySqlTest | Verificado localmente | Diez casos con MySQL 8.0 y correo simulado ejercitaron registro 202 sin sesión, OTP de seis dígitos, reenvío, sesión persistida, logout, suspensión, aprobación, revocación, propiedad de imágenes, recuperación y límites. |

## Verificación

| Comprobación | Resultado |
|---|---|
| Gradle Wrapper 9.4.1 y toolchain Java 17. `test --no-daemon --rerun-tasks` | 65 pruebas aprobadas en 12 XML JUnit, 0 fallidas, 0 errores y 0 omitidas. |
| `gradlew.bat build --no-daemon` | Correcto. Generó el artefacto Spring Boot. |
| MySQL 8.0 local en 127.0.0.1:3307. Flyway sobre base vacía | V1–V5 aplicadas y reejecución sin cambios. Se comprobaron 22 tablas originales, cuatro complementarias, un historial, 27 claves primarias, 32 referencias foráneas, 23 triggers, el índice único de desafíos activos y la definición y nulabilidad de columnas críticas. |
| Flyway sobre esquema legado | 2 pruebas aprobadas. Baseline explícito, preservación de datos, colisión de identidad con cuentas intactas y DDL parcial. |
| Flutter 3.41.9, Dart 3.11.5 y SDK Android 37 | `flutter pub get` correcto. El diagnóstico de Android indicó estado de licencias desconocido. |
| `flutter test` | 10 pruebas aprobadas. Incluye reapertura de un registro de restaurante pendiente y reenvío. |
| Suite de autenticación en Chrome | Se detuvo después de cinco minutos en la etapa de carga. No hubo resultado de pruebas en navegador. |
| `flutter build web --release` | Correcto. Generó `mobile/build/web`. |
| `flutter build apk --debug` | Correcto. Generó `mobile/build/app/outputs/flutter-apk/app-debug.apk`. |
| `flutter analyze` | Código 1 por 16 diagnósticos informativos preexistentes. Cero errores y cero advertencias. |

La prueba de recuperación concurrente inicial reprodujo un interbloqueo MySQL (1213). Se serializó la recuperación por identidad y se consultó el desafío activo por su índice. La corrida final obtuvo una aceptación y un rechazo del código consumido. El código de autorización y las migraciones siguieron usando la conexión local. V5 se corrigió porque referenciaba `clientes.role` y el DDL declara `clientes.rol`. Consultar historial, checksum y procedimiento de recuperación antes de migrar un esquema existente. [MYSQL_MIGRATION_VALIDATION.md](MYSQL_MIGRATION_VALIDATION.md)

## Primer acceso de empleados existentes

1. Confirmar quién conserva el acceso al buzón del administrador legítimo y de cada moderador. Si hay una colisión de identidad, resolverla con el propietario antes de aplicar V3.
2. Conservar un respaldo verificable y preparar el proveedor de correo transaccional antes de la ventana de cambio. Comprobar en un ambiente aislado que un empleado sintético recibe el OTP, verifica y puede abrir su panel Web.
3. Tras una migración de producción aprobada por separado, cada empleado inicia sesión en Web con su correo y contraseña existentes. Flutter solicita la verificación, recibe el desafío y espera el OTP que llega al buzón. Solo después de verificarlo se habilita la sesión.
4. Si no llega el correo, revisar la entrega y pedir un nuevo código desde el flujo de verificación respetando el tiempo de espera. Si ya se perdió el desafío anterior, volver a iniciar el flujo desde login. Si se perdió acceso al buzón, escalar al propietario para una recuperación de identidad documentada. Mantener el requisito de verificación individual.

Este procedimiento se probó con identidades sintéticas y un servicio de correo simulado en backend. La ejecución interactiva Web con una cuenta de empleado queda pendiente.

## Estado de P0

| Área | Estado |
|---|---|
| P0.1 Credenciales | Verificado localmente mediante pruebas de configuración. La rotación de credenciales históricas corresponde al propietario. |
| P0.2 JWT y sesiones | Verificado localmente, incluidas sesión persistida, logout y revocación. Queda pendiente el recorrido interactivo en clientes. |
| P0.3 Autorización | Parcialmente corregido. Lista por método y rol, titularidad y visibilidad probadas en rutas representativas. |
| P0.4 Identidad | Verificado localmente con SMTP simulado y pruebas del flujo de Flutter. Pendiente validar entrega SMTP real y primer acceso de empleados reales. |
| P0.5 Migraciones | Verificado en esquemas de prueba nuevos y legados con JPA validate. Cotejo de Aiven pendiente de autorización. |
| P0.6 Infraestructura | Verificación local parcial. CORS explícito y errores saneados en el código. Despliegue, orígenes y TLS productivos pendientes. |
| P0.7 Recuperación | Verificado localmente. Emisión y consumo concurrentes, revocación y persistencia probados en MySQL de pruebas. Entrega real pendiente. |
| P0.8 Archivos | Validación JPEG/PNG y titularidad local probadas. Cloudinary real, cámara/galería y administración de huérfanos pendientes. |

## Archivos y alcance

- Seguridad y persistencia Java en `AuthService`, `AuthController`, `AccountIdentityRegistry`, `AuthRateLimitService`, `EmailVerificationService`, `PasswordResetTokenRepository`, `CloudinaryAssetRegistry`, `PostService`, `UserService`, `ReservationController`, `PostController`, `PostRepository` y `SecurityConfig`. Las entidades se alinearon con el DDL y V5 cambió una referencia de columna.
- Servicios, almacenamiento, proveedor y pantallas de autenticación en Flutter, además de pruebas de restauración de verificación. El rol efectivo sigue viniendo del servidor.
- Pruebas Java de autorización, identidad, sesión y migraciones nuevas y legadas. Toda cuenta creada para las pruebas es sintética.
- Contratos, inventario, decisiones, trazabilidad y validación de MySQL documentados en la raíz. [AUTHORIZATION_MATRIX.md](AUTHORIZATION_MATRIX.md)

La evaluación se limita a P0. Quedan pendientes la revisión de autorización de combinaciones sin evidencia directa, las verificaciones externas de Aiven, SMTP y Cloudinary, y los recorridos interactivos en Web y Android. No se hizo push, merge, despliegue ni operación en producción.
