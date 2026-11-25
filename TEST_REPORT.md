# Informe de pruebas SavorSync V2

Rama `fix/savorsync-remediation-v2`, base `8a9101e2b627e609f359f92189c1cf11f85810c8`. Ejecución local desde Android Studio en Windows. El alcance comprende el diagnóstico, la limpieza de la configuración heredada y las tareas P0.1 a P0.3.

| Etapa | Ejecución | Evidencia |
|---|---|---|
| Diagnóstico backend | `gradlew.bat classes --offline --no-daemon` | Salida 0. Gradle 9.4.1. `compileJava` se encontraba actualizado y procesó recursos. Advertencia de compatibilidad futura con Gradle 10. |
| Diagnóstico Flutter | `flutter analyze --no-pub` | Salida 1 con 16 avisos de nivel info, 0 advertencias y 0 errores. Predominan API obsoleta y uso de contexto tras saltos asíncronos. |
| Backend P0.1 | `gradlew.bat test --tests '*CredentialConfigurationTest' --offline --no-daemon` | El primer intento no pudo resolver `junit-platform-launcher:1.10.3` desde la caché. El reintento con acceso al repositorio de dependencias pasó. Las ejecuciones offline posteriores recompilaron el código y los tests modificados. La última terminó con 4 pruebas, 0 fallos y 0 errores. `git diff --check` también pasó. |
| Flutter P0.1 | `flutter test --no-pub` | 1 aprobada y 1 fallida. La prueba nueva confirma que la llamada directa a Google se rechaza. El test existente `App initialization test` dejó temporizadores pendientes al desmontar el árbol. |
| Flutter Web P0.1 | `flutter test --no-pub --platform chrome test/auth_service_test.dart` | La ejecución quedó en `loading` y se detuvo a los 228 s. El entorno no produjo un resultado del navegador. |
| Inspección de fuentes | Barrido de configuraciones Spring y código Flutter posterior a P0.1 | Cero coincidencias de los valores de respaldo según los patrones examinados y cero coincidencias de los nombres de la contraseña compartida o el JWT ficticio de Google. El historial y las copias previas siguen requiriendo rotación. |

El informe de Gradle está en `backend/backend/build/reports/tests/test/index.html`. La prueba de configuración verifica los nueve orígenes de variables, la ausencia del seed por defecto en desarrollo, la exclusión del seed cuando se combina producción con desarrollo y el rechazo de contraseña vacía antes de acceder al repositorio. Se utilizaron dobles de dependencias para probar el comportamiento de configuración sin acceder a una base de datos.

La prueba de arranque vacía `contextLoads()` se retiró antes de P0.3. `SessionMySqlTest` conserva la cobertura de arranque con comprobaciones HTTP y persistencia real. La validación en Android, correo y despliegues permanece en sus fases correspondientes.

## Limpieza de la configuración heredada

La revisión de fuentes, configuración, documentación y dependencias resueltas confirma que Flutter Web y Android mantienen la API REST común. El adaptador retirado carecía de invocadores. `flutter pub get --offline` resolvió los paquetes y generó metadatos, pero terminó con error de Windows al preparar enlaces simbólicos de plugins. La compilación web pudo usar los metadatos resueltos con `--no-pub`.

- Web release. `flutter build web --release --no-pub --no-wasm-dry-run` pasó y generó `mobile/build/web`. El barrido del JavaScript generado no encontró los dominios ni los nombres de módulos retirados.
- Android debug. Se eliminaron las salidas antiguas de `android/build` y `android/app/build`. Los dos intentos de `flutter build apk --debug --no-pub` alcanzaron sus límites de 240 s y 300 s durante `assembleDebug`, sin verificar un APK nuevo. `git diff --check` pasó.

## P0.2 — Autenticación y revocación

| Prueba | Evidencia |
|---|---|
| Backend acotado y MySQL | 23 pruebas pasaron con Gradle. Incluyen cuatro de configuración, diez del filtro, seis del servicio de autenticación, dos de suspensión y una prueba HTTP contra MySQL 8.0.45. |
| Esquema local | Se cargaron las 22 tablas en una instancia temporal aislada. La primera ejecución detectó que la asignación temprana del ID de cliente hacía que JPA cargara columnas de publicaciones que el DDL no define. Tras cambiar el registro a una inserción y el conteo de publicaciones, pasó la prueba real. |
| Persistencia y API | El JWT emitido superó 191 caracteres y MySQL guardó una huella de 67. Registro, login, restauración y logout devolvieron los estados esperados. Suspender revocó las sesiones todavía activas y reactivar conservó la revocación. La sesión anterior quedó rechazada con 401 y la consulta devolvió un conteo de publicaciones real. |
| Flutter acotado | `flutter test --no-pub test/auth_service_test.dart` pasó 7 de 7. Incluye restauración real, 401, indisponibilidad temporal, cierre local con aviso y respuesta tardía con sesión más reciente. |
| Flutter Web | `flutter build web --release --no-pub --no-wasm-dry-run` pasó y generó `mobile/build/web`. Las pruebas funcionales en navegador y dispositivo siguen pendientes. |
| Suite Flutter | `flutter test --no-pub --reporter expanded` pasó 8 de 8. El test de arranque ahora espera la transición y verifica que una instalación sin sesión abre el login. |

El informe de Gradle está en `backend/backend/build/reports/tests/test/index.html`. La prueba MySQL usa el perfil `test` y exige las variables `SAVORSYNC_SESSION_MYSQL_URL`, `SAVORSYNC_SESSION_MYSQL_USER` y `SAVORSYNC_SESSION_MYSQL_PASSWORD` de una instancia desechable en loopback. La instancia temporal se cerró y se eliminaron sus archivos. El servicio MySQL existente y Aiven quedaron fuera de la verificación. La revocación por cambio de contraseña se comprobó en la prueba unitaria. La prueba integral de recuperación necesita la tabla `tokens_recuperacion`, que no figura en el DDL.

## P0.3 — Roles y titularidad

- Se retiró `BackendApplicationTests.contextLoads()`. La prueba HTTP contra MySQL mantiene evidencia de arranque y persistencia.
- `gradlew.bat test --offline --no-daemon` pasó **30 de 30** con MySQL temporal. Los siete casos nuevos de MockMvc cubren acceso anónimo, roles de gobierno, titularidad de reservas, menús y notificaciones, privacidad de contacto, identidad de publicaciones y subida de archivos. La prueba HTTP con las 22 tablas confirmó que la visibilidad de una publicación protege también la consulta de sus comentarios.
- `flutter test --no-pub --reporter expanded` pasó **8 de 8**. `flutter build web --release --no-pub --no-wasm-dry-run` generó `mobile/build/web`.
- Pendientes de Android en dispositivo y del cotejo de permisos académicos. El servicio MySQL existente y Aiven permanecieron fuera de la prueba. Se retiraron los archivos de la instancia temporal.

## Matriz de pruebas cruzadas prevista

Los escenarios están PENDIENTES y requieren que Android y Web apunten al mismo entorno autorizado.

| Prueba | Escenario |
|---|---|
| 01 | Crear publicación en Android y consultar desde web. |
| 02 | Crear publicación en web y consultar desde Android. |
| 03 | Crear reserva en Android y verla en el panel web. |
| 04 | Confirmar reserva en panel web y comprobar el estado en Android. |
| 05 | Crear plato en el panel y verlo en Android. |
| 06 | Editar plato y comprobar ambas plataformas. |
| 07 | Eliminar plato y verificar que desaparece en ambas plataformas. |
| 08 | Crear PQRS en Android y verla como moderador en panel web. |
| 09 | Responder PQRS en web y ver la respuesta en Android. |
| 10 | Editar perfil en web y comprobar en Android. |
| 11 | Agregar favorito en Android y comprobar en web. |
| 12 | Suspender usuario y verificar revocación de sus sesiones. |
| 13 | Cambiar contraseña y verificar revocación de sesiones previas. |
| 14 | Moderar publicación y comprobar visibilidad en ambas plataformas. |
| 15 | Cargar imagen en Android y mostrarla en web. |
| 16 | Cargar imagen en web y mostrarla en Android. |
| 17 | Interrumpir el backend de prueba y verificar que ningún cliente muestra datos ficticios. |
| 18 | Cerrar y volver a abrir ambos clientes y comprobar persistencia. |

Las pruebas futuras de autorización deben comprobar 401, 403 y el alcance de propiedad de cada rol con datos aislados. Incluyen identidades inexistentes o revocadas, recursos propios/de terceros, intentos de asignar roles o modificar verificación, validación de estados y rechazo de archivos inválidos. Se registrarán los resultados por endpoint y plataforma cuando se ejecuten.
