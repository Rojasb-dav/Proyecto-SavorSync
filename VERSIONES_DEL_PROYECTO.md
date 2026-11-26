# Versiones del proyecto

Registro de cambios, decisiones y resultados de verificación de SavorSync. El [README](README.md) describe el estado vigente. Las cifras siguientes provienen de los informes de cada iteración.

## 2026-11-26 · V3.5-B · Compatibilidad de Flyway

Base aprobada [`daafc4f`](https://github.com/Rojasb-dav/Proyecto-SavorSync/commit/daafc4fbd6ec0b5c01b004b1f33757274d48d185). `dependencyInsight` confirmó que el BOM de Spring Boot 3.3.4 resolvía Flyway Core y MySQL en 10.10.0. Flyway 10.10.0 completó V1–V6 sobre MySQL 8.4.13 y emitió `Flyway upgrade recommended` porque su módulo MySQL declaraba 8.1 como versión máxima probada.

| Componente | Antes | V3.5-B |
|---|---|---|
| Flyway Core y Flyway MySQL | 10.10.0 | 11.15.0 en ambos módulos por `flyway.version` |
| MySQL Connector/J | 8.3.0 | 8.3.0 |
| Spring Boot | 3.3.4 | 3.3.4 |
| Hibernate ORM | 6.5.3.Final | 6.5.3.Final |
| HikariCP | 5.1.0 | 5.1.0 |
| Gradle / Java | 9.4.1 / toolchain 17 | 9.4.1 / toolchain 17 |

Los módulos de Flyway 10.22.0 y 11.14.1 todavía emiten el aviso después de MySQL 8.1. En la primera versión estable identificada que amplía ese límite, 11.15.0, el código del módulo cubre hasta 9.4 y el proyecto compila para Java 17. La referencia de Redgate lista 8.0 y 9.4 como versiones verificadas. La cobertura de 8.4 se comprobó con el código de la versión y los ensayos locales. Connector/J 8.3.0 documenta soporte para servidores MySQL desde 8.0. Spring Boot permite ajustar la propiedad del BOM. La combinación con Boot 3.3.4 se verificó en este proyecto y conserva la resolución única de Jackson Databind 2.17.2. [Flyway 10.22.0](https://raw.githubusercontent.com/flyway/flyway/flyway-10.22.0/flyway-database/flyway-mysql/src/main/java/org/flywaydb/database/mysql/MySQLDatabase.java#L243) · [Flyway 11.14.1](https://raw.githubusercontent.com/flyway/flyway/flyway-11.14.1/flyway-database/flyway-mysql/src/main/java/org/flywaydb/database/mysql/MySQLDatabase.java#L243) · [Flyway 11.15.0](https://raw.githubusercontent.com/flyway/flyway/flyway-11.15.0/flyway-database/flyway-mysql/src/main/java/org/flywaydb/database/mysql/MySQLDatabase.java#L243) · [Java 17](https://raw.githubusercontent.com/flyway/flyway/flyway-11.15.0/pom.xml#L732) · [Notas de Flyway](https://documentation.red-gate.com/flyway/release-notes-and-older-versions/release-notes-for-flyway-engine) · [Módulo MySQL](https://documentation.red-gate.com/flyway/reference/database-driver-reference/mysql) · [Connector/J 8.3.0](https://dev.mysql.com/doc/relnotes/connector-j/en/news-8-3-0.html) · [Gestión de dependencias de Spring Boot](https://docs.spring.io/spring-boot/3.3/gradle-plugin/managing-dependencies.html)

### Integridad de V1–V6

| Migración | SHA-256 del SQL antes y después | Checksum Flyway 10.10.0 y 11.15.0 |
|---|---|---:|
| V1 | `12649C6F8F8072540143C58CAA15E42CACEBA24D738E5B34E23B7307CE52536F` | `649273393` |
| V2 | `7B5C64923531E08D066ACC8C3AF4E70941E951E1531F2FB027C23C1EB977A959` | `510023184` |
| V3 | `D61FED3B58B60555B12ED453A5AB5B01B23AC73944F58AC1ADDD3E31B938B1E8` | `-1557068391` |
| V4 | `17C2B49A4A31458F5839316D4E4417FB87FE4198EE556FFD118AE6E0036437E5` | `534775200` |
| V5 | `8C355422A741923B40B246199E6DEDE35EE3A14DA670F80879FB25C91A95B298` | `-1040495304` |
| V6 | `1D10B166430976AC804EA5926BE01F34AD3428D1CFEDF3AC0D35DE906B4FF852` | `-146368849` |

### Verificación local

| Escenario | Resultado |
|---|---|
| A · MySQL 8.0.46 desde cero | V1–V6 aplicadas y validadas. Hibernate `validate` correcto. 27 tablas, 35 claves foráneas, 31 triggers, seis migraciones exitosas y cero filas en las 26 tablas funcionales. |
| B · MySQL 8.4.13 desde cero | Mismos conteos y validación de Hibernate. El registro conserva la línea de detección de MySQL 8.4 y ya no contiene el aviso `Flyway upgrade recommended`. |
| C · Historial creado por 10.10.0 en MySQL 8.4.13 | Flyway 11.15.0 validó seis migraciones, con cero pendientes y cero repetidas. Coincidieron las seis filas completas del historial y la huella de una fila sintética. Tampoco apareció el aviso en esta ejecución. |
| D · Integridad con usuario DML en ambos motores | Los triggers generaron UUID. Se aceptaron el propietario con rol correcto y el seguimiento válido. Se rechazaron DDL, rol incorrecto, autoseguimiento y referencia huérfana. El rollback dejó sin filas las tres tablas de prueba. |
| Backend y entrypoint Linux | `gradlew.bat build --rerun-tasks` generó `backend.jar`. 107 pruebas Java en 18 XML JUnit, incluidas 22 del guard y dos de baseline, con 0 fallidas, 0 errores y 0 omitidas. Docker construyó `savorsync-backend:v35b-local`. Las 41 comprobaciones del entrypoint pasaron. |
| Perfil `production` en MySQL 8.4.13 aislado | Usuario exclusivo DML y dos sesiones TLS en `savorsync_v34_validation`. CA obligatoria, PKCS12, `VERIFY_IDENTITY` y fallback desactivado. Hibernate `validate` con Flyway desactivado. Health, restaurantes y publicaciones 200. Reservas anónimas 401. Se rechazaron configuración externa, CA ausente y DNS incompatible. `bootstrap-admin` creó una cuenta sintética sin verificar. El escaneo de argumentos y logs no encontró las contraseñas de prueba. |

Se ejecutó la suite completa. La única excepción de `baseline` autorizada se aplicó dentro de los dos tests existentes de `MysqlLegacyBaselineValidationTest`, cada uno sobre un esquema sintético nuevo y desechable. La prohibición permanece para Aiven, `defaultdb`, `savorsync_v34_validation` y cualquier base real o preexistente. La comparación del escenario C usó un historial creado al aplicar V1–V6 y se completó sin `baseline`, `repair` ni `clean`.

El ensayo cubrió MySQL local 8.4.13. Quedan pendientes el corte sobre Aiven 8.4.11 y la comprobación de Render con el artefacto aprobado. Los avisos de `open-in-view`, `MySQLDialect` y Commons Logging quedan fuera de V3.5-B. P0 continúa abierto. [Migración y reversión](docs/PRODUCTION_MIGRATION_RUNBOOK.md#flyway-11150-en-v35-b)

## 2026-11-26 · V3.5-A.1 · Correcciones de auditoría

Se reforzó V3.5-A sobre la misma base V3.4. El guard de Spring Boot comprueba las fuentes externas antes de procesar JSON o imports y valida los perfiles efectivos antes del contexto. El entrypoint fija la configuración del classpath, conserva la CA obligatoria y detecta los nombres con puntos que el intérprete podría descartar. La URL productiva sigue limitada a `savorsync_v34_validation` y `defaultdb` conserva su condición histórica. V1–V6, el Dockerfile y las dependencias quedaron intactos.

| Verificación | Resultado |
|---|---|
| Bytes y atributos | La inspección hexadecimal confirmó que ambos scripts comienzan por `23 21`, decodifican como UTF-8 estricto y conservan LF sin BOM. La comprobación inicial con `StartsWith` produjo un falso positivo por comparación cultural. Los caracteres descompuestos eran un problema de visualización de la consola. `.gitattributes` fija LF para `*.sh` y `gradlew`. |
| Gradle, JAR y Java | Build correcto. 105 pruebas aprobadas en 18 XML JUnit, 0 fallidas, 0 errores y 0 omitidas. Las 22 pruebas del guard ejecutan Spring Boot y comprueban la configuración efectiva de Hikari, los perfiles, las fuentes externas y el rechazo antes del contexto. |
| Entrypoint | 41 comprobaciones aprobadas en la imagen final, incluidas las 35 previas. |
| Docker y MySQL 8.4.13 aislado | Imagen `savorsync-backend:v35a1-local` compilada. Perfil `production` con dos sesiones TLS al destino permitido. Health, restaurantes y publicaciones 200. Reservas anónimas 401. Flyway desactivado en producción. |
| Rechazos reales | JSON, URL de Hikari, modo TLS mediante nombre con puntos, truststore, Flyway, Hibernate, configuración externa, CA ausente o inválida y activación alternativa de producción rechazados. Un nombre DNS incompatible provocó un fallo de verificación de identidad. |
| Bootstrap y secretos | El flujo sin consola falló de forma controlada. La versión con consola creó una cuenta sintética `admin_sistema` con correo sin verificar. Las contraseñas de prueba no aparecieron en la salida comprobada ni en los argumentos del proceso Java de producción. |

La auditoría confirmó Aiven MySQL 8.4.11 en el puerto `28223`, `partial_revokes=ON` y el aislamiento de esquemas por conexiones reales. `savorsync_backend` queda asociado a `defaultdb`, `savorsync_v34_backend` al servicio definitivo y `savorsync_v34_migration@%` permanece como definidor de los 31 triggers. `avnadmin` se reserva para administración del servicio. El corte productivo requiere aprobación y confirmar en Render la URL, la cuenta, el secreto, la CA y la retirada de variables heredadas incompatibles. P0 sigue abierto. [Configuración admitida](docs/INFRASTRUCTURE_CONFIGURATION.md#configuración-admitida-en-producción) · [Despliegue y reversión](docs/PRODUCTION_DEPLOYMENT_RUNBOOK.md)

## 2026-11-26 · V3.5-A · Preparación de producción

Base V3.4 [`0362511`](https://github.com/Rojasb-dav/Proyecto-SavorSync/commit/03625119894ac8ecb60eb016db79e9defa68dd89). El entrypoint de producción exige un único host, puerto explícito y el esquema `savorsync_v34_validation`. Fija la URL validada para Spring Boot y Hikari y mantiene `ddl-auto=validate`, Flyway desactivado y `VERIFY_IDENTITY` con CA obligatoria y PKCS12. `defaultdb` se reserva como histórico. Las migraciones V1–V6 y las dependencias conservan sus versiones.

| Evidencia | Resultado |
|---|---|
| Aiven MySQL 8.4.11, reportado por el propietario | V1–V6 aplicadas, 27 tablas, 35 claves foráneas, 31 triggers y 26 tablas funcionales inicialmente vacías. Pruebas transaccionales, JDBC TLS, HTTP y aislamiento entre esquemas correctos. |
| Backend | 83 pruebas aprobadas en 17 XML JUnit. Cero fallos, errores u omisiones. JAR generado con Gradle y Java 17. El primer `clean` encontró archivos de build en uso en Windows. `build --rerun-tasks` completó la recompilación y la regresión. |
| Validación del entrypoint | 35 comprobaciones aprobadas en la imagen final. Los casos válidos alcanzan la comprobación de CA. Los casos inválidos se rechazan antes de iniciar Java, sin imprimir la URL. Desde `backend/backend`, ejecutar `sh src/test/sh/docker-entrypoint-test.sh` en Linux sin una CA de producción montada. |
| Docker Linux y MySQL 8.4.13 aislado | Imagen `savorsync-backend:v35a-local` compilada. V1–V6 se aplicaron por TLS con una cuenta separada. El perfil `production` arrancó con la cuenta de aplicación. Health, restaurantes y publicaciones devolvieron 200. Reservas sin autenticación devolvió 401. MySQL registró dos sesiones de la aplicación con cifrado TLS en el esquema esperado. El alias DNS ajeno al certificado terminó con código 1 por verificación de identidad fallida. Flyway permaneció desactivado en el arranque de producción. |

La validación local se realizó en contenedores nuevos. Flyway emitió su aviso de compatibilidad declarada para MySQL 8.4 y las seis migraciones se completaron. Queda la aprobación del propietario y la comprobación del entorno definitivo durante el corte. Si se requiere revertir, restaurar el servicio con una imagen compatible con el esquema definitivo y preservar sus escrituras. [Despliegue y reversión](docs/PRODUCTION_DEPLOYMENT_RUNBOOK.md)

## 2026-11-26 · V3.4 · Integridad referencial

Base [`ef2ef6a`](https://github.com/Rojasb-dav/Proyecto-SavorSync/commit/ef2ef6a1b680974a27b7655077a960ba805da5ed), sobre la entrega funcional [`7c9879b1`](https://github.com/Rojasb-dav/Proyecto-SavorSync/commit/7c9879b18e5c874e99f30a097169c57a7c005621). Se aprueba instalar con tablas limpias y conservar exclusivamente en el respaldo histórico los registros de prueba de las primeras versiones. El propietario reportó checksum SHA256 y restauración privada comprobada en MySQL 8.4.13. Esa instancia no formó parte de esta iteración.

- `Follow` mapea la fila con identidad propia, dos referencias a clientes y fecha. Desaparecen las asociaciones Hibernate implícitas y las colecciones completas de perfiles. Se serializan los seguidores y se mantienen los contadores del contrato JSON.
- La API exige un propietario válido de rol Restaurant Admin. Al publicar una reseña usa el ID del restaurante activo que envía Flutter. La búsqueda por nombre se conserva para clientes anteriores y solo enlaza una coincidencia inequívoca. Aprobación y titularidad se conservan por separado. Los DELETE de restaurante, cliente y publicación conservan las filas y su historial. Las reservas activas no se pueden crear en un local desactivado.
- V6 conserva V1–V5, introduce marcadores de baja y checks de integridad, valida el rol del propietario y agrega tres claves foráneas tipadas para reportes. La FK de comentarios vincula padre y publicación. Recuenta likes y comentarios a partir de filas y comprueba datos incompatibles de V5 antes de alterar tablas.
- Reservas, comentarios, likes y seguidores confirman sus cambios y avisos internos juntos. El registro de identidad y la cuenta se guardan en la misma transacción. V6 exige identidad válida en desafíos activos y verifica que las sesiones nuevas correspondan a cuentas activas y verificadas. Se comprueba que el archivo asociado pertenezca al autor y a un destino real. La eliminación de medios sigue coordinada con el registro y la inspección de referencias.
- Flutter conserva rutas y navegación. La confirmación de restaurantes explica que la acción desactiva y preserva historial. El formulario de reseñas limita la calificación a valores que admite la columna académica.

### Evidencia de V3.4

| Ejecución | Resultado |
|---|---|
| Backend, Gradle 9.4.1 y toolchain Java 17 | `gradlew.bat build` correcto. 83 pruebas aprobadas en 17 XML JUnit, 0 fallidas, 0 errores y 0 omitidas. Incluye las regresiones de identidad, OTP, recuperación, sesiones y autorización. |
| MySQL 8.0.46 aislado | Instalación V1–V6 desde cero, actualización con fixtures y baseline académico conservados. Se verificaron 27 tablas, 35 FK, 31 triggers y la reejecución sin pendientes. Hibernate `validate` correcto. |
| MySQL 8.4.13 aislado | Instalación limpia V1–V6. La copia histórica estricta de V3.3 funcionó sobre V5 con datos sintéticos y la actualización posterior a V6 preservó referencias. Un ciclo en V5 bloqueó la migración antes del primer ALTER permanente. Hibernate arrancó con la copia sintética actualizada. |
| Integridad y concurrencia | Titularidad, baja lógica, conservación de reservas, analíticas y publicaciones, unicidad, contadores, revocación y rollback verificados con fixtures. Se rechazaron FK incompatibles y altas sin permisos. |
| Docker Linux | Imagen local final compilada y arrancada con un usuario MySQL de permisos DML. `GET /actuator/health` devolvió HTTP 200 y `{"status":"UP"}`. |
| Flutter 3.41.9 y Dart 3.11.5 | Resolución con lockfile, 11 pruebas aprobadas, Web release y APK debug compilados con API local. Analyze terminó con código 1 por 16 diagnósticos informativos preexistentes. Sin errores ni advertencias. |
| Chrome | El corredor de `test/api_base_url_test.dart` permaneció cargando el archivo y se interrumpió a los 130 s con código 1. Quedó sin resultado. |
| Validaciones sin ejecutar | Dispositivo Android, APK release firmado, Aiven, despliegues y pruebas reales de Brevo, Cloudinary o Firebase. |

La primera ejecución señaló un delimitador de Flyway y una ejecución posterior señaló expectativas de prueba incompatibles con V6 y la secuencia de registro. Las correcciones se verificaron con una suite completa sobre un esquema nuevo.

P0 sigue abierto. El corte limpio y los permisos para triggers de Aiven, TLS JDBC, proxy, rotaciones y flujos externos permanecen pendientes. La política de retención y los flujos inexistentes de P1 siguen fuera del alcance. El IDE conserva la codificación original de los README existentes. La normalización a UTF-8 queda pendiente de una operación de codificación segura.

## 2026-11-26 · Consolidación documental

Base [`7c9879b`](https://github.com/Rojasb-dav/Proyecto-SavorSync/commit/7c9879b18e5c874e99f30a097169c57a7c005621). Se centralizan alcance, arquitectura, trazabilidad y pendientes en el README. Los procedimientos y referencias técnicas viven en `docs/`. Los informes de cada corte se consultan en Git. La verificación de esta iteración se limita a la documentación y a sus enlaces. El estado funcional y los bloqueantes de producción de V3.3 siguen vigentes.

## 2026-11-25 · V3.3 · Infraestructura y esquema parcial

Entrega [`7c9879b`](https://github.com/Rojasb-dav/Proyecto-SavorSync/commit/7c9879b18e5c874e99f30a097169c57a7c005621) sobre [`486baca`](https://github.com/Rojasb-dav/Proyecto-SavorSync/commit/486baca100b23b17ca3a42aa39a47b76a8f2a4f3). Se separó la migración de Aiven en copia desde un esquema parcial restaurado hacia un destino Flyway nuevo. Se integraron Brevo HTTPS, Cloudinary firmado en carpeta restringida, aprovisionamiento administrativo por consola, TLS JDBC, health check y compilación Docker con un JAR inequívoco. Flutter pasó a recibir `API_BASE_URL` por entorno. El Foodie verificado puede solicitar el rol administrativo desde su perfil. [Entrega V3.3](https://github.com/Rojasb-dav/Proyecto-SavorSync/blob/7c9879b18e5c874e99f30a097169c57a7c005621/P0_V33_AUDIT_HANDOFF.md)

| Verificación | Resultado |
|---|---|
| Backend, Java 17 y Gradle 9.4.1 | 79 aprobadas en 17 XML JUnit, sin fallos, errores ni omisiones. Build correcto. |
| MySQL local | V1–V5 en 8.0.46 y 8.4.13. Baseline del modelo original de 22 tablas en 8.0.46. Copia del fixture parcial compatible e incompatible probada en 8.4.13. Hibernate `validate` operativo. |
| Docker Linux | Build y arranque correctos. Health 200 UP con cuenta local DML, y rechazo de CA ausente o inválida. |
| Flutter 3.41.9, Dart 3.11.5 | 11 aprobadas, Web release y APK debug compilados. Analyze con 16 diagnósticos informativos preexistentes, sin errores ni advertencias. |
| Chrome y Android | Web montó localmente y la petición CORS a `/auth/me` devolvió el 401 esperado. El corredor Flutter agotó 120 s sin conteo. Dispositivo Android y firma release pendientes. |
| Proveedores y corte | Correo y archivos probados mediante proveedores simulados. Pruebas separadas del propietario con MySQL TLS, Brevo y Cloudinary. Integración desplegada y P0 pendientes. |

## 2026-11-25 · V3.2 · Seguridad residual y MySQL

Entrega [`486baca`](https://github.com/Rojasb-dav/Proyecto-SavorSync/commit/486baca100b23b17ca3a42aa39a47b76a8f2a4f3) sobre [`8559f23`](https://github.com/Rojasb-dav/Proyecto-SavorSync/commit/8559f23732d04759e1c0787c500c0e0e888a78cc). Se hizo obligatoria la comprobación de titularidad de imágenes, se conservó el tipo solicitado en reenvíos, se comprobó la verificación individual de empleados y se explicitó la autorización por método, rol y recurso. Se alinearon las pruebas de sesión con el contrato sin JWT antes de verificar. [Entrega V3.2](https://github.com/Rojasb-dav/Proyecto-SavorSync/blob/486baca100b23b17ca3a42aa39a47b76a8f2a4f3/P0_V32_AUDIT_HANDOFF.md)

- Backend. 65 aprobadas, 0 fallidas y 0 omitidas en 12 XML JUnit. Build correcto.
- MySQL 8.0 local. Flyway V1–V5 desde cero, baseline sobre 22 tablas originales y Hibernate `validate`.
- Flutter. 10 aprobadas. Web release y APK debug compilados. Analyze con 16 diagnósticos informativos. Corredor de Chrome sin resultado final.

## 2026-11-25 · V3.1 · Identidad, sesiones y archivos

Entrega [`8559f23`](https://github.com/Rojasb-dav/Proyecto-SavorSync/commit/8559f23732d04759e1c0787c500c0e0e888a78cc) sobre [`3939944`](https://github.com/Rojasb-dav/Proyecto-SavorSync/commit/39399448b6c9a0e93157d52870b763483b0a86ab). Se reforzaron sesiones JWT, verificación OTP y recuperación, configuración por entorno, migraciones y validación JPEG/PNG. Se mantuvo JWT como autenticación y Google Sign-In deshabilitado. [Entrega V3.1](https://github.com/Rojasb-dav/Proyecto-SavorSync/blob/8559f23732d04759e1c0787c500c0e0e888a78cc/P0_AUDIT_HANDOFF.md)

- Backend. 52 casos, 50 aprobados y 2 omitidos por falta de MySQL/Docker. Build correcto.
- Flutter. 8 aprobadas. Web release y APK debug compilados.
- El despliegue, las rotaciones, la auditoría completa de permisos y las integraciones externas seguían pendientes.

## 2026-11-24 y 2026-11-25 · Antecedentes

La auditoría inicial V2 comparó código, SQL y consumidores Flutter. La referencia histórica de `main` para V3.3 fue [`b3da13a`](https://github.com/Rojasb-dav/Proyecto-SavorSync/commit/b3da13aa2981ac66cb857929ddee5d84bed687dd). Los diagnósticos y planes de las fases previas se conservan abajo con su contexto original.

## Archivo de documentos

Estas copias están fijadas al último commit anterior a la consolidación, [`7c9879b`](https://github.com/Rojasb-dav/Proyecto-SavorSync/commit/7c9879b18e5c874e99f30a097169c57a7c005621). Consultarlas para recuperar el detalle original, los cortes anteriores y sus resultados fechados.

- [AIVEN_SCHEMA_COMPATIBILITY.md](https://github.com/Rojasb-dav/Proyecto-SavorSync/blob/7c9879b18e5c874e99f30a097169c57a7c005621/AIVEN_SCHEMA_COMPATIBILITY.md)
- [API_CONTRACTS.md](https://github.com/Rojasb-dav/Proyecto-SavorSync/blob/7c9879b18e5c874e99f30a097169c57a7c005621/API_CONTRACTS.md)
- [AUDIT_FINDINGS.md](https://github.com/Rojasb-dav/Proyecto-SavorSync/blob/7c9879b18e5c874e99f30a097169c57a7c005621/AUDIT_FINDINGS.md)
- [AUTHORIZATION_MATRIX.md](https://github.com/Rojasb-dav/Proyecto-SavorSync/blob/7c9879b18e5c874e99f30a097169c57a7c005621/AUTHORIZATION_MATRIX.md)
- [DATABASE_ALIGNMENT.md](https://github.com/Rojasb-dav/Proyecto-SavorSync/blob/7c9879b18e5c874e99f30a097169c57a7c005621/DATABASE_ALIGNMENT.md)
- [FEATURE_INVENTORY.md](https://github.com/Rojasb-dav/Proyecto-SavorSync/blob/7c9879b18e5c874e99f30a097169c57a7c005621/FEATURE_INVENTORY.md)
- [INFRASTRUCTURE_CONFIGURATION.md](https://github.com/Rojasb-dav/Proyecto-SavorSync/blob/7c9879b18e5c874e99f30a097169c57a7c005621/INFRASTRUCTURE_CONFIGURATION.md)
- [MYSQL_MIGRATION_VALIDATION.md](https://github.com/Rojasb-dav/Proyecto-SavorSync/blob/7c9879b18e5c874e99f30a097169c57a7c005621/MYSQL_MIGRATION_VALIDATION.md)
- [P0_AUDIT_HANDOFF.md](https://github.com/Rojasb-dav/Proyecto-SavorSync/blob/7c9879b18e5c874e99f30a097169c57a7c005621/P0_AUDIT_HANDOFF.md)
- [P0_V32_AUDIT_HANDOFF.md](https://github.com/Rojasb-dav/Proyecto-SavorSync/blob/7c9879b18e5c874e99f30a097169c57a7c005621/P0_V32_AUDIT_HANDOFF.md)
- [P0_V33_AUDIT_HANDOFF.md](https://github.com/Rojasb-dav/Proyecto-SavorSync/blob/7c9879b18e5c874e99f30a097169c57a7c005621/P0_V33_AUDIT_HANDOFF.md)
- [PLATFORM_COMPATIBILITY.md](https://github.com/Rojasb-dav/Proyecto-SavorSync/blob/7c9879b18e5c874e99f30a097169c57a7c005621/PLATFORM_COMPATIBILITY.md)
- [PRODUCTION_DEPLOYMENT_RUNBOOK.md](https://github.com/Rojasb-dav/Proyecto-SavorSync/blob/7c9879b18e5c874e99f30a097169c57a7c005621/PRODUCTION_DEPLOYMENT_RUNBOOK.md)
- [PRODUCTION_MIGRATION_RUNBOOK.md](https://github.com/Rojasb-dav/Proyecto-SavorSync/blob/7c9879b18e5c874e99f30a097169c57a7c005621/PRODUCTION_MIGRATION_RUNBOOK.md)
- [REMEDIATION_PLAN.md](https://github.com/Rojasb-dav/Proyecto-SavorSync/blob/7c9879b18e5c874e99f30a097169c57a7c005621/REMEDIATION_PLAN.md)
- [REQUIREMENTS_TRACEABILITY.md](https://github.com/Rojasb-dav/Proyecto-SavorSync/blob/7c9879b18e5c874e99f30a097169c57a7c005621/REQUIREMENTS_TRACEABILITY.md)
- [SCOPE_DECISIONS.md](https://github.com/Rojasb-dav/Proyecto-SavorSync/blob/7c9879b18e5c874e99f30a097169c57a7c005621/SCOPE_DECISIONS.md)
- [SavorSync_Plan_Maestro_V3_Gemini.md](https://github.com/Rojasb-dav/Proyecto-SavorSync/blob/7c9879b18e5c874e99f30a097169c57a7c005621/SavorSync_Plan_Maestro_V3_Gemini.md)
- [TEST_REPORT.md](https://github.com/Rojasb-dav/Proyecto-SavorSync/blob/7c9879b18e5c874e99f30a097169c57a7c005621/TEST_REPORT.md)

Para recuperar una copia desde un clon con el commit disponible:

```text
git show 7c9879b18e5c874e99f30a097169c57a7c005621:AUDIT_FINDINGS.md
```
