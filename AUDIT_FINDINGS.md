# Diagnóstico inicial de SavorSync V2

> **Actualización V3.3.** V3.3 separa nueve hallazgos sobre esquema parcial, correo HTTPS, multimedia, primera cuenta, TLS, Docker, Web/Vercel, autorización y validación. Los estados con evidencia y pendientes del propietario se registran por ID en [la entrega V3.3](P0_V33_AUDIT_HANDOFF.md).

## Estado de partida

- Rama inicial `main`, con referencia local `origin/main` al mismo commit. HEAD `8a9101e2b627e609f359f92189c1cf11f85810c8`. Único commit posterior a `3146a0e3b76adadba62193c35af10ba2eff2b023`: `8a9101e`, solo README. El árbol local de Git es la fuente de esta comparación.
- Cambios de trabajo previos en `GlobalExceptionHandler.java`, `ReservationController.java`, `auth_service.dart`, `login_screen.dart` y `register_screen.dart`. Rama de trabajo `fix/savorsync-remediation-v2` creada desde el mismo HEAD. Los cambios preexistentes forman parte del diagnóstico estático.
- El repositorio no incluye los informes originales en las rutas revisadas. La numeración y el alcance se cotejaron contra el plan V2. Las descripciones indican evidencia actual y pueden abarcar partes de un hallazgo. La categoría «Parcial» significa mitigación visible en código y no implica aceptación.
- Código Spring 3.3.4 sobre Java 17 en `backend/backend`, y Flutter con API REST compartida en `mobile`. Además de Android, iOS y web hay objetivos de escritorio. No se verificó el estado de esos objetivos de escritorio.
- No se localizaron manifiestos versionados de Render o Vercel mediante la búsqueda por nombre. Los Dockerfile existen en raíz y backend. Dominios y dashboards desplegados requieren comprobación del propietario.
- Gradle `classes --offline --no-daemon` devolvió 0 en el estado inicial. `compileJava` estaba actualizado y se procesaron recursos. Hay advertencia de compatibilidad futura con Gradle 10. Esto no demuestra inicio del backend, integración ni acceso MySQL. Véase [TEST_REPORT.md](TEST_REPORT.md).

## Estado por hallazgo

Las filas describen el estado inicial. Salvo la compilación diagnóstica y las verificaciones registradas en el informe de pruebas, la evidencia es estática. No hay hallazgos marcados como verificados y aprobados.

| Identificador | Evaluación inicial | Evidencia |
|---|---|---|
| FALLO-01 | Pendiente | Recursos Spring contienen valores de reserva de JWT, Cloudinary y correo. La búsqueda histórica por nombre de propiedad los ubica en `5a9ea1f`. |
| FALLO-02 | Pendiente | `SecurityConfig` autentica rutas protegidas de forma genérica. Falta aplicar roles y propiedad en varias operaciones. |
| FALLO-03 | Parcial | `AuthService.register` fuerza `foodie`. Los formularios privilegiados siguen usando ese registro. |
| FALLO-04 | Pendiente | `DataSeeder` ejecuta por defecto y tiene contraseña de respaldo para un moderador. |
| FALLO-05 | Pendiente | `UserResponse` incluye email y teléfono en consultas de terceros. |
| FALLO-06 | Pendiente | Gobierno de usuarios con política de roles insuficiente en `UserController`. |
| FALLO-07 | Parcial | Existe una comprobación nominal de propietario en perfil. Quedan mecanismos alternativos de identidad y control insuficiente de campos. |
| FALLO-08 | Pendiente | `PostController` permite resolver autor desde datos de la petición o un usuario alternativo. |
| FALLO-09 | Pendiente | Operaciones de publicaciones y servicios Flutter ocultan fallos mediante estados aparentemente exitosos o datos de respaldo. |
| FALLO-10 | Parcial | `ReservationController` incorpora DTO por cambio local. Las consultas de reservas aún requieren comprobación de propiedad. |
| FALLO-11 | Pendiente | Reservas sin validación integral de fechas, disponibilidad, capacidad ni transiciones. |
| FALLO-12 | Pendiente | Operaciones de restaurantes y menú sin alcance suficiente de rol y establecimiento. |
| FALLO-13 | Pendiente | Actualización de establecimientos desde Flutter reutiliza POST y la selección puede caer en el primer restaurante. |
| FALLO-14 | Pendiente | GET de PQRS público y alcance de titular o empleado sin verificar integralmente. |
| FALLO-15 | Pendiente | `NotificationController` usa identificadores del cliente sin comprobación integral del propietario. |
| FALLO-16 | Pendiente | DTO de perfil y flujos de seguimiento requieren separar los datos públicos y privados y verificar contadores y persistencia. |
| FALLO-17 | Parcial | JWT con firma y expiración y validación de sesión presentes. Flutter restaura un usuario ficticio ante fallos. |
| FALLO-18 | Parcial | El literal de JWT ficticio ya no aparece en el servicio Flutter local, pero la integración sustituye el token por una contraseña compartida. Sin validación de Google en Spring. |
| FALLO-19 | Pendiente | `ApiService` convierte errores de varias lecturas en listas vacías. |
| FALLO-20 | Parcial | DTO disponible en la copia local. `RoleBasedShell` omite `restaurantId` al abrir reservas administrativas. |
| FALLO-21 | Pendiente | `MenuManagementScreen` elige el primer restaurante como respaldo y mantiene operaciones de menú en memoria. |
| FALLO-22 | Pendiente | `PqrsManagementScreen` omite el texto al enviar la respuesta y usa una ruta de notificación sin contrato válido. |
| FALLO-23 | Parcial | DTO mejora fechas y nombres. Persisten inconsistencias de campos, estado y deserialización por validar en ejecución. |
| FALLO-24 | Pendiente | Longitudes y tipos SQL divergen de entidades y DTO, incluidos comentarios y calificación. |
| FALLO-25 | Parcial | Código de seis dígitos generado con SecureRandom y expiración de 15 minutos. Sin límites, consumo robusto ni almacenamiento protegido. |
| FALLO-26 | Pendiente | `tokens_recuperacion` ausente del DDL. SMTP asíncrono antes del commit y entrega sin verificar. |
| FALLO-27 | Parcial | Techo y controles MIME básicos en backend. Persisten selección `unsigned` y ausencia de verificación de contenido real. |
| FALLO-28 | Pendiente | CORS permite patrones amplios de Vercel y orígenes locales en la misma configuración. |
| FALLO-29 | Pendiente | TLS y verificación de certificado de Aiven sin evidencia de despliegue. |
| FALLO-30 | Pendiente | Identidad y sesiones JPA se concentran en clientes mientras SQL separa clientes y empleados. |
| FALLO-31 | Pendiente | Flutter enmascara errores de red y no separa datos vacíos de indisponibilidad en varias lecturas. |
| FALLO-32 | Parcial | Cambio local neutraliza el cuerpo de 500 genérico. Quedan razones de excepción sin sanitizar en otros flujos y mensajes de excepciones en logs. |
| FALLO-33 | Pendiente | Colecciones sin paginación y consultas por fila, incluidas conversiones a DTO de reservas. |
| FALLO-34 | Pendiente | Conteos y manejo de errores en publicaciones requieren revisión, incluidos comentarios que no actualizan su contador. |
| FALLO-35 | Pendiente | Favoritos locales sin alcance por usuario y restauración de sesión basada en estado local. |
| FALLO-36 | Pendiente | Estado no admitido de reserva devuelve éxito en el contrato actual. |
| FALLO-37 | Pendiente | Moderador y administrador de sistema comparten navegación. Faltan comprobaciones de interfaz por tamaño y plataforma. |
| FALLO-38 | Pendiente | JWT completo ocupa `VARCHAR(191)` y la persistencia de sesión puede fallar sin respuesta fiable. Revocación incompleta. |
| FALLO-39 | Pendiente | Formularios de moderación usan registro público y pueden sustituir las credenciales locales del administrador. |
| FALLO-40 | Pendiente | Consulta de reservas prioriza usuario sobre restaurante y Flutter puede abrir panel sin restaurante. |
| FALLO-41 | Pendiente | Panel de restaurante actualiza mediante POST y tiene selección local por defecto. |
| FALLO-42 | Pendiente | Notificaciones duplican `/api`, ocultan errores y simulan continuidad mediante una sola consulta. |
| FALLO-43 | Pendiente | Backend y Flutter permiten tratar `emailVerified` como campo editable del perfil. |
| FALLO-44 | Parcial | DTO local aporta nombres. Perfil consultado puede provocar una petición de reservas del usuario visitado. |
| FALLO-45 | Pendiente | `MenuItem` mapea `menu_restaurantes`, el SQL crea `menu_restaurante`. |
| FALLO-46 | Pendiente | `Post` declara columnas ausentes del DDL y omite `restaurante_id` y `imagenes_publicacion`. |
| FALLO-47 | Pendiente | Relaciones multimedia y tabla de recuperación insuficientes para el contrato JPA. Véase el inventario SQL. |
| FALLO-48 | Nuevo en copia local | La sustitución de Google Sign-In introduce una contraseña compartida en el cliente. Debe retirarse en P0.1 y comprobar si algún artefacto o entorno la usó. |
| FALLO-49 | Nuevo hallazgo | La pantalla de recuperación solicita el correo, pero el método Flutter de restablecimiento carece de llamada desde la UI. |
| FALLO-50 | Nuevo hallazgo | La pantalla de moderación afirma que no hay reportes sin consultarlos. El perfil de moderación muestra métricas fijas. |
| FALLO-51 | Nuevo hallazgo | Los mínimos del lockfile Flutter exceden los mínimos anunciados en `pubspec.yaml`. Android release reutiliza la firma debug. |
| FALLO-52 | Nuevo hallazgo | Las mayúsculas de algunos nombres de iconos web difieren de las referencias en manifest e index. Falta validarlo al servir el build. |
| FALLO-53 | Nuevo hallazgo | El script SQL comienza con `DROP DATABASE`. Su reconstrucción se limita a entornos desechables y aislados. |
| FALLO-54 | Confirmado por ejecución y corregido | El test de inicialización desmontaba el árbol con temporizadores pendientes. En P0.2 la prueba espera la transición y verifica la pantalla de login. Pasó en la suite Flutter. |
| FALLO-55 | Confirmado por ejecución | El alta de clientes con ID asignado antes de `save` activaba `merge` y fallaba al cargar columnas inexistentes de publicaciones. Se corrigió el camino de inserción en P0.2. |

## Incompatibilidades y dependencias

- Java y SQL: 22 tablas y 22 triggers en el script, repartidos en 20 secciones. El documento académico aprobado y el inventario de Aiven quedan por cotejar. El script abre con `DROP DATABASE`. Las entidades, relaciones, enums, sesiones y recuperación se detallan en [DATABASE_ALIGNMENT.md](DATABASE_ALIGNMENT.md).
- Spring y Flutter: registro privilegiado sin endpoint, reservas sin alcance uniforme, notificaciones con prefijo duplicado, PQRS sin texto de respuesta y contratos con modelos discrepantes. Detalle en [API_CONTRACTS.md](API_CONTRACTS.md).
- Web y Android: persisten diferencias en OAuth, sesión, geolocalización y firma. iOS existe en código, con aprobación de alcance y macOS pendientes. Detalle por carpetas y plataformas en [PLATFORM_COMPATIBILITY.md](PLATFORM_COMPATIBILITY.md).
- No se dispone de MySQL aislado preparado para las pruebas con el esquema armonizado, confirmación de las variables de nube ni evidencia de SMTP, OAuth, Cloudinary y Aiven desplegados. También faltan un migrador versionado y publicación del contrato OpenAPI en el código revisado. La prueba backend preexistente carga todo Spring y depende de MySQL.
- Clasificación de nube: hipótesis pendientes de acceso autorizado para rotaciones, TLS, configuración de CORS efectiva, SMTP de Render, OAuth y data real. No hay regresiones de la remediación constatadas en este diagnóstico inicial.

## Orden de ejecución

Primero P0.1, con eliminación local de credenciales y contención de la variante local de Google. El siguiente bloque de P0 requiere autorización expresa. P0.2–P0.8 deben resolver identidad, sesiones, propiedad y esquema antes del gate formal. Después, P1 alinea persistencia y contratos, P2 amplía calidad y P3 valida compilaciones, nube y operaciones cruzadas. El seguimiento está en [REMEDIATION_PLAN.md](REMEDIATION_PLAN.md).

## Resultado de P0.1

**PARCIALMENTE CORREGIDA.** Retirados los valores privados y de respaldo detectados en el código activo. Continúan pendientes las comprobaciones y rotaciones externas. Los valores anteriores permanecen en el historial Git y pueden existir en artefactos desplegados o copias previas. El rastreo histórico por propiedades y nombres de archivo sobre las referencias locales, sin salida de diffs, señaló `5a9ea1f` para configuración Spring y seed. Es un barrido por patrones conocidos, no una auditoría de todas las copias ni de credenciales externas.

| Credencial o material | Evidencia y corrección local | Acción del propietario |
|---|---|---|
| JWT | Clave de firma de reserva en configuración versionada. Ahora se exige `APP_JWT_SECRET`. | Rotar la clave de firma expuesta en cada entorno afectado y coordinar cierre y nuevo inicio de sesión. Demostrar la rotación mediante fecha o referencia de cambio, sin adjuntar la clave. |
| Cloudinary | La configuración incluía un API Secret de respaldo y un par de identificadores de cuenta. El cliente usa identificadores públicos de subida; P0.8 cubre la política de subida. | Regenerar o revocar el par expuesto y actualizar cada entorno. Comprobar permisos y restricciones del preset en P0.8. |
| Gmail/SMTP | Contraseña de aplicación de respaldo versionada. El usuario SMTP también se obtiene del entorno. | Revocar la contraseña de aplicación expuesta y crear otra para el entorno autorizado, o configurar el proveedor aprobado. Verificar la entrega después de P0.7. |
| MySQL | Los valores de reserva iniciales apuntaban al MySQL local con credenciales débiles. No hay evidencia de que coincidan con Aiven. Ahora URL, usuario y contraseña se exigen por ambiente. | Cambiar contraseñas locales reutilizadas. Revisar la credencial de Aiven en su gestor y rotarla si coincide, se reutilizó o aparece en otra copia. Confirmar TLS en P0.6. |
| Moderador inicial | Contraseña predeterminada en Git. El seed quedó sujeto al perfil de desarrollo y a habilitación explícita, con contraseña obligatoria. | Identificar cuentas que se hayan creado con el valor anterior, restablecer su contraseña y revocar sesiones según el procedimiento autorizado. |
| Google en cliente | FALLO-48 visible en el árbol de trabajo inicial. Retirado el valor compartido y el cliente rechaza el flujo de forma explícita. No se verificó que hubiera llegado a una publicación, build distribuido o entorno remoto. | Verificar si alguna versión llegó a crear cuentas con el valor compartido. Si las hay, restablecer credenciales y revocar sesiones. Activar Google únicamente cuando se valide la identidad en el backend. |

Los logs de aplicación tocados registran el tipo de excepción en vez de su mensaje crudo. P0.2 y P0.7 conservan la tarea de corregir el almacenamiento de JWT y códigos. P0.6 mantiene la sanitización del contrato de errores. `main`, producción y el esquema no se usaron para aplicar cambios. El estado de ejecución y las pendientes se registran en [TEST_REPORT.md](TEST_REPORT.md).

## Resultado de P0.2

**PARCIALMENTE CORREGIDA.** FALLO-17 y FALLO-38 se corrigieron en el flujo de sesiones asociado a `clientes`. Un JWT único se registra como huella SHA-256. Spring comprueba firma, expiración, estado de la sesión, titular, actividad y rol vigente. Flutter restaura el usuario desde `/auth/me` y conserva la credencial si el servicio está temporalmente indisponible.

El cierre revoca la sesión corriente. La suspensión y el cambio de contraseña revocan todas las sesiones del usuario. Los JWT antiguos sin el nuevo formato quedan invalidados y requieren iniciar sesión de nuevo. Las filas históricas permanecen intactas. La separación entre clientes y empleados sigue en P0.5. El flujo de recuperación sigue necesitando la tabla prevista en P0.5 y la validación de correo y consumo del código en P0.7. [TEST_REPORT.md](TEST_REPORT.md).

## Resultado de P0.3

**PARCIALMENTE CORREGIDA.** Spring comprueba roles y titularidad en las rutas sensibles. PQRS queda fuera de las rutas públicas, las consultas de notificaciones y reservas personales se acotan al titular y la administración de menús y reservas se acota al propietario. Las escrituras sociales obtienen su autor de la sesión. Las pruebas HTTP y MySQL confirmaron los controles cubiertos. La compatibilidad funcional en dispositivos y el cotejo del alcance de moderación siguen pendientes. [TEST_REPORT.md](TEST_REPORT.md).

## Reconciliación con la iteración V3.1 — 2026-11-25

Los hallazgos FALLO-01–55 anteriores describen una auditoría V2 y se conservan sin reescribir. El árbol actual parte de `39399448b6c9a0e93157d52870b763483b0a86ab` en `fix/savorsync-remediation-v3`; los estados históricos no son evidencia de esta iteración.

| Discrepancia documental | Estado observado en código V3.1 |
|---|---|
| Este informe declara rama `main` y base `8a9101e…`; el informe de pruebas declara otra base y 48 errores. | Son antecedentes V2. La rama/HEAD actuales están indicados arriba; la ejecución actual figura en TEST_REPORT.md. |
| El informe histórico indica que P0.4–P0.8 no se implementaron. | En V3.1 hay cambios locales en identidad, OTP, recuperación, Flyway, CORS, archivos y Flutter. El grado de verificación individual está en REMEDIATION_PLAN.md y P0_AUDIT_HANDOFF.md. |
| El inventario anterior dice que no hay Flyway y que sólo hay un SQL destructivo. | Ahora hay Flyway y V1–V5. V1 conserva 22 tablas y triggers sin DROP/CREATE DATABASE. Las migraciones no se ejecutaron porque no hay MySQL/Docker local. |
| El contrato previo dice registro 200 con AuthResponse, CORS con patrones amplios y upload unsigned. | El código actual registra con 202 sin JWT, usa orígenes CORS explícitos y procesa cargas en Spring con credenciales sólo del servidor. Véase API_CONTRACTS.md. |
| El reporte V2 afirmaba que el esquema y MySQL quedaron completamente verificados. | En esta ejecución no se abrió MySQL local ni Aiven; esa afirmación no se puede trasladar a V3.1. |

El repositorio no define los identificadores `V3-01`–`V3-07` en documentos ni código. Se registran sin asignarles causas inventadas; la correspondencia con el informe externo de auditoría queda pendiente. No se constató regresión de producción ni se ejecutó sobre un servicio remoto.

## Hallazgos residuales de auditoría V3.2 — 2026-11-25

| Hallazgo | Resultado de revisión local |
|---|---|
| V3.2-01 Propiedad de imágenes | Corregido: PostService y UserService comprueban el resultado de attachIfOwned; asociación idempotente sólo para el mismo recurso/dueño; una asociación fallida revierte persistencia. Se probaron URL ajena, arbitraria, reuso y rollback. Imágenes históricas no se borran. |
| V3.2-02 Tipo solicitado | Corregido y probado: reenvío lee requested_role desde el registro de identidad. Flutter conserva email, challenge y tipo solicitado pendiente de verificación entre reaperturas; ese dato no asigna permisos. Aprobación revoca sesiones antiguas. |
| V3.2-03 Empleados existentes | Corregido y probado con moderador y admin_sistema sintéticos: ambos pueden solicitar OTP y verificarse individualmente. No hay verificación masiva ni cuentas privilegiadas de fallback. La transición real de cuentas depende de un operador propietario autorizado. |
| V3.2-04 Autorización exhaustiva | SecurityConfig usa reglas por método/rol y denyAll final; controladores/servicios revisados comprueban titular/restaurante y estado. Pruebas seleccionadas y matriz creada. Revisión combinatoria no ejecutada y módulos P1 no implementados. |
| V3.2-05 MySQL/Flyway | Corregido localmente: cinco migraciones, historial y checksums válidos desde base nueva; JPA validate; baseline de esquema legado preserva fixtures; colisión normalizada falla sin borrar filas. No Aiven. |
| V3.2-06 SessionMySqlTest | Contrato actualizado: 202 y RegistrationResponse sin JWT, código de seis dígitos capturado de correo simulado, AuthResponse tras OTP, sesión/revocación y flujo de aprobación. Sin correo real. |

Los errores iniciales de pruebas ocasionados por URL de fixtures, contador persistente entre corridas y checksum previo se corrigieron en el arnés local; no se deshabilitaron casos ni se alteraron pruebas para ocultar fallos. Los resultados finales y conteos se anotan en el handoff V3.2 tras inspeccionar XML JUnit.

La corrida final aprobó 65 pruebas Java, incluidas 10 de sesión contra MySQL. Se corrigió un interbloqueo de recuperación detectado por las pruebas concurrentes. Véase [P0_V32_AUDIT_HANDOFF.md](P0_V32_AUDIT_HANDOFF.md).
