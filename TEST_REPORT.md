# Informe de Pruebas SavorSync V3

## PRE-00: Diagnóstico Local y Protección de la Rama

**Rama y Commit:**
- Branch: `main`
- Commit: `b3da13aa2981ac66cb857929ddee5d84bed687dd`

**Versiones del Sistema:**
- Java: 25.0.2
- Gradle: 9.4.1
- Flutter: 3.41.9 (Dart 3.11.5)

**Ejecución Inicial (Baseline):**
- **Backend Tests:** 48 errores de compilación causados por refactorización del esquema de sesiones (`AuthSession` reemplazado por `ClientSession` y `EmployeeSession`).
- **Flutter Tests:** Ejecutados exitosamente, a excepción de advertencias por dependencias desactualizadas.
- **Ambiente de pruebas aislado:** `application-test.properties` apuntando a `127.0.0.1`.

---

## P0.1, P0.2 y P0.3: Autenticación, JWT, Sesiones, Roles y Cors

**Backend:**
- **P0.1 Secretos:** Modificado el `DataSeeder.java` para prevenir arranque en caso de no proveer la contraseña en `development` y deshabilitarlo permanentemente en `production`. Se eliminaron configuraciones y validaciones sueltas defectuosas.
- **P0.2 Autenticación JWT y Login:**
  - Se eliminó el `try/catch` silenciador en `AuthService.java` al persistir sesiones y se forzó `saveAndFlush`, rechazando token si falla BD.
  - Se implementó en `JwtAuthenticationFilter.java` el uso directo de las bases de datos para comprobar si la sesión de empleado/cliente es válida.
  - Se implementó el control de inactividad (`isActive`), control de `expiresAt`, y comprobación de coincidencia de rol al emitir el token y al validarlo.
  - Se adaptaron 38 pruebas unitarias al nuevo esquema de sesión.
  - Se actualizaron los DTOs `UserResponse` para diferenciar respuestas propias y públicas (`fromSelf` y `fromPublic`) según los requerimientos de privacidad de P1.9.
- **P0.3 y P0.6 Roles, CORS y Configuración Global:**
  - Se ajustó el `SecurityConfig.java` para que los endpoints protegidos devuelvan respuestas JSON autoritativas con formato correcto (`RestSecurityErrors`) en lugar de strings no estructurados.
  - Se definieron estrictamente los endpoints publicos con formato de autorización, implementando CORS seguro con `setAllowedOriginPatterns()`.
- **Resultados de Pruebas:** 38/38 pruebas del backend corriendo exitosamente en el entorno aislado (Test JUnit / MockMvc / SessionMySQL). **No hay fallas remanentes.** 100% Pass rate tras subsanar todas las fallas en la configuración Mock de los repositorios.

**Flutter:**
- Reforzado el Frontend (`auth_service.dart`) para rechazar inicio de sesión si el `expiresInMs` de la API es nulo, cero o negativo.
- **Resultados de Pruebas:** 8/8 tests de flutter finalizando exitosamente.

---

## P0.4 y P0.7: Registro, Empleados y Recuperación de Correo

- En `AuthService.java` y `AuthController.java` se corrigieron los DTOs y mapeos para asegurar que el registro público sólo admite roles `foodie` y `restaurant_admin`, bloqueando tajantemente que un usuario cree perfiles administrativos internos desde el acceso público. Las pruebas confirman que los roles protegidos son ignorados en registros públicos y sobrescritos con `foodie`.
- Se implementó `V2__Add_Password_Reset_Token_Table.sql` y se acopló `PasswordResetToken` de Spring Boot a su propia tabla dedicada en base de datos.
- Se refactorizó la lógica en `AuthService.java` (métodos `forgotPassword` y `resetPassword`) de tal modo que almacena el *hash encriptado* por `PasswordEncoder` en lugar del código en claro en base de datos para los tokens de restablecimiento, añadiendo una capa vital de seguridad ante fugas (FALLO-26). También se impuso transaccionalidad total con `saveAndFlush`.

**Resultados de Pruebas (Backend):**
Tras actualizar la estructura de mocks en `AuthServiceSessionTest` para usar `ClientSessionRepository`, los 38 tests JUnit y MockMvc del proyecto reportaron nuevamente un **100% Pass rate** ✅, con cobertura satisfactoria en todos los casos de recuperación de cuenta y filtrado de roles.

---

## P0.5: Modelo Relacional, Migraciones y Esquema DDL

- Se evaluó e inspeccionó detalladamente `schema_foodies_db.sql`.
- **Verificación Completa:** Se verificó que las 22 tablas exactas del modelo relacional original, referenciadas en las secciones 1 al 20, se mantienen activas y fieles a su integridad SQL (UUID de IDs, llaves foráneas y tipos restringidos como enums para campos controlados de estados, notificaciones, menús y PQR).
- **Control de Flyway:** Se instauró un nuevo directorio `db/migration` dentro de recursos en preparación a futuros despliegues aditivos y control automático del esquema sin perder datos históricos. La tabla faltante `tokens_recuperacion` ya forma parte del esquema formal.

---

## Ejecución V3.1 — 2026-11-25 (se conserva el informe histórico anterior)

Rama `fix/savorsync-remediation-v3`; base `39399448b6c9a0e93157d52870b763483b0a86ab`. Los resultados V2 (main, SHA distinto y 38/48 pruebas) no describen esta corrida.

### Backend

| Comando | Resultado |
|---|---|
| `gradlew.bat test --no-daemon --rerun-tasks` | Exit 0; 52 tests, 50 aprobados, 0 fallidos, 2 omitidos. Los omitidos corresponden a `SessionMySqlTest`; no se dispone de MySQL/Docker. |
| `gradlew.bat build --no-daemon` | Exit 0; build exitoso. Gradle Wrapper 9.4.1 y Java Toolchain 17. |
| `gradlew.bat clean test --no-daemon` | No llegó a ejecutar tests: `:clean` falló al borrar `backend/backend/build` por archivos bloqueados/abiertos por Windows. No se forzó el borrado. La suite separada anterior sí pasó. |

### Flutter

| Comando | Resultado |
|---|---|
| `flutter doctor -v` | Flutter 3.41.9, Dart 3.11.5, Android SDK 37 y Chrome disponibles. Licencias Android aparecen como desconocidas/no aceptadas. |
| `flutter pub get` | Exit 0. 73 paquetes tienen versiones posteriores fuera de los rangos declarados; no se actualizaron indiscriminadamente. |
| `flutter analyze` | Exit 1 con 16 avisos `info` (deprecaciones, const y async context); 0 errores de análisis reportados. Se corrigió el aviso del dropdown modificado en registro; los restantes están en pantallas preexistentes. |
| `flutter test` | Exit 0; 8/8 tests aprobados. |
| `flutter build web --release` | Exit 0; generado `mobile/build/web`. |
| `flutter build apk --debug` | Exit 0; generado `mobile/build/app/outputs/flutter-apk/app-debug.apk`. |
| `flutter build apk --release` | No ejecutado: no hay firma release autorizada/configurada y la configuración histórica usa la firma debug. |

Las pruebas de archivo nuevas validan PNG permitido, vacío, corrupto, MIME discordante, tamaño mayor de 10 MiB y ausencia de autenticación. No prueban proveedor Cloudinary real ni cámara/galería en un dispositivo.

### Límites de verificación

MySQL y Docker no están disponibles para esta sesión. No se ejecutaron V1–V5, no se probó el baseline sobre una copia de las 22 tablas, no se validó Hibernate contra MySQL y no se usó Aiven. No se desplegó ni se conectó a Render, Vercel, Cloudinary o SMTP real. No se completó prueba E2E Web/Android; el build no prueba permisos, CORS desplegado ni entrega de correo.
