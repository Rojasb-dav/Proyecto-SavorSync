# Versiones del proyecto

Registro de cambios, decisiones y resultados de verificación de SavorSync. El [README](README.md) describe el estado vigente. Las cifras siguientes provienen de los informes de cada iteración.

## 2026-11-26 · V3.5-C · Estabilización y regresión

Base aprobada [`bc9b48c`](https://github.com/Rojasb-dav/Proyecto-SavorSync/commit/bc9b48c6240f0707d0a625228818b7f0c263d6d8). Spring Boot habilitaba Open-in-View por omisión. Ahora `spring.jpa.open-in-view=false` define el límite de persistencia y Hibernate infiere MySQLDialect de los metadatos JDBC. El aviso de Commons Logging se debía a `cloudinary-http44:1.38.0 → httpclient:4.4 → commons-logging:1.2`, también vía `httpmime`. La exclusión se limita a la declaración Cloudinary y conserva `spring-jcl`. [Open EntityManager in View](https://docs.spring.io/spring-boot/reference/data/sql.html#data.sql.jpa-and-spring-data.open-entity-manager-in-view) · [Puente de Spring](https://docs.spring.io/spring-framework/reference/core/spring-jcl.html)

- El feed lee publicaciones visibles con autor e imágenes en la consulta, escoge la imagen por orden y agrupa las lecturas de restaurantes, likes del visitante y contadores ausentes. El DTO se completa dentro de la transacción. Los comentarios visibles leen su autor mediante una consulta conjunta. Las asociaciones siguen siendo LAZY en el modelo.
- Perfiles y seguidores devuelven DTO o estado HTTP. Reservas mantienen su DTO transaccional. Restaurantes, menú, notificaciones y PQRS exponen campos escalares. La moderación usa las rutas actuales y los mismos filtros por rol. Los favoritos, horarios, promociones, reportes y analítica conservan las comprobaciones de integridad existentes y carecen de endpoints independientes en el backend revisado. Las búsquedas por fila preexistentes en listados de reservas y perfiles quedan fuera de los cambios de lectura del feed.
- El login limita la entrada a 72 bytes UTF-8 antes de BCrypt para clientes y empleados. Las credenciales demasiado largas reciben 401. Se conservan los perfiles permitidos, el guard, el entrypoint y la separación DML y migraciones.

### Verificación

| Verificación | Resultado |
|---|---|
| Java y JAR | Gradle 9.4.1, toolchain Java 17. `build --rerun-tasks` compiló `backend.jar` y ejecutó 110 pruebas en 18 XML JUnit, sin fallos, errores ni omisiones. Incluye 22 pruebas del guard y las dos pruebas de baseline autorizadas, limitadas a esquemas sintéticos nuevos y aislados. |
| HTTP con datos | Autor, restaurante, imagen, likes y comentarios se serializaron como DTO. Se comprobó el filtrado de publicaciones privadas y comentarios ocultos. El número de sentencias del feed fue igual con dos y con siete publicaciones. Las pruebas también comprobaron perfil, seguimiento, menú, reservas y notificaciones con datos. |
| Clientes externos simulados | El SDK Cloudinary hizo multipart contra un servidor de loopback con `spring-jcl` y el proveedor de correo HTTP se comprobó con el fixture existente. El correo SMTP de verificación se simuló. |
| MySQL 8.0.46 y 8.4.13 | Instalación limpia de V1–V6 y arranque con Hibernate `validate` en ambos motores. Cada esquema tuvo 27 tablas, 35 claves foráneas, 31 triggers y 26 tablas funcionales inicialmente vacías. El historial creado por V3.5-B se validó en 8.4.13 sin escrituras de historial ni migraciones repetidas. Los casos DML en ambos motores verificaron UUID, restricciones, rechazo de DDL y rollback. |
| Docker y `production` | Imagen `savorsync-backend:v35c-local` Linux/amd64 y 41 comprobaciones de shell aprobadas. Health, restaurantes y publicaciones respondieron 200 y reservas anónimas 401. Los DTO de producción incluyeron autor, foto, restaurante y comentario del fixture, con exclusión de la reseña privada. Dos sesiones TLS por usuario DML, Flyway desactivado, guard activo, rechazo de configuración externa, CA ausente o inválida y DNS incompatible. Bootstrap creó un administrador sintético. Las comprobaciones de logs y argumentos no encontraron contraseñas de prueba. |
| Advertencias y JAR | Los registros de la suite y del arranque de la imagen carecen de los avisos de Open-in-View, `HHH90000025`, Commons Logging y compatibilidad de Flyway con MySQL 8.4, sin ajuste de niveles de logging. El JAR contiene 76 librerías y conserva `spring-jcl:6.1.13` sin `commons-logging`. Persisten avisos de compilación y compatibilidad futura de Gradle. |

Los [SHA-256 y checksums V1–V6](#integridad-de-v1v6) coinciden con V3.5-B. Las dos invocaciones autorizadas de `baseline` ocurrieron únicamente en `MysqlLegacyBaselineValidationTest`. La referencia del historial se creó con migraciones normales, sin `baseline`, `repair` ni `clean`.

El README fue convertido por el propietario de UTF-16LE con BOM a UTF-8 sin BOM mediante PowerShell. Se verificó la equivalencia textual y la ausencia de BOM mediante inspección de bytes. El contenido se conserva fuera de los dos párrafos actualizados deliberadamente.

### Auditoría de dependencias

Consulta al 26 de noviembre de 2026. Se cruzaron las 86 coordenadas Maven del runtime con OSV. Se obtuvieron 97 identificadores únicos en 18 coordenadas, con coincidencias de versión que incluyen avisos condicionados a configuración. Se priorizaron los avisos críticos y altos de mayor exposición en el código y la configuración actual. Los resultados de inventario identifican coincidencias, y el alcance de cada aviso restante requiere triage antes del corte. [OSV](https://osv.dev/) · [Avisos de Spring](https://spring.io/security/) · [Apache Tomcat](https://tomcat.apache.org/security-10.html)

| Componente efectivo | Riesgo y exposición | Corrección o siguiente verificación |
|---|---|---|
| Spring Security 6.3.3 | **Crítico**, CVE-2026-22732 para emisión de encabezados en stacks Servlet con Spring Security. SavorSync usa esa cadena y devuelve datos de cuenta. Queda verificar todos los caminos de respuesta detrás del proxy. El aviso crítico CVE-2024-38821 requiere WebFlux, ausente del runtime. | La línea 6.3 incluye corrección en 6.3.15 comercial. Las líneas OSS corrigieron desde 6.5.9 o 7.0.4. Spring documenta emisión temprana de encabezados como mitigación separada, con cambios de precedencia sujetos a prueba. [CVE-2026-22732](https://spring.io/security/cve-2026-22732/) · [CVE-2024-38821](https://spring.io/security/cve-2024-38821/) |
| Spring Security Crypto 6.3.3 | **Alto en la biblioteca**, CVE-2025-22228. Mitigado en el login cliente y empleado por el límite de 72 bytes UTF-8, verificado a 72 y 73 bytes. Registro, bootstrap y recuperación ya limitan la contraseña. | Corrección de biblioteca desde 6.3.8, con revisión coordinada de Spring. [Aviso de BCrypt](https://spring.io/security/cve-2025-22228/) |
| Tomcat 10.1.30 | **Alto y aplicable**, CVE-2025-48988. El backend acepta multipart autenticado y la versión carece del límite independiente de partes. CVE-2025-24813 requiere escritura en DefaultServlet. La configuración revisada conserva su desactivación por defecto. | Apache corrigió el límite en 10.1.42. Evaluar una versión 10.1 actualmente corregida y repetir pruebas de tamaño, autenticación y proxy. [Apache Tomcat](https://tomcat.apache.org/security-10.html) · [CVSS de NVD/CISA](https://nvd.nist.gov/vuln/detail/CVE-2025-48988) |
| Jackson 2.17.2 | **Alto y aplicable**, CVE-2026-89407. Jackson 2.17.2 invoca la validación vulnerable al convertir cadenas a `Double`; las reseñas reciben un campo `Double` por JSON. **Crítico en la biblioteca**, CVE-2026-110879, condicionado al uso de tipado polimórfico. El código revisado no activa tipado por defecto ni `@JsonTypeInfo` en la API. También se detectaron avisos de parsers `DataInput` o asíncronos sin uso identificado en la API Servlet. | Evaluar un BOM Jackson soportado con parches coordinados de core y databind. Los avisos citados tienen parches desde core 2.21.7 y databind 2.21.8 en la línea LTS 2.21. [Parser numérico de Jackson 2.17.2](https://raw.githubusercontent.com/FasterXML/jackson-databind/jackson-databind-2.17.2/src/main/java/com/fasterxml/jackson/databind/deser/std/NumberDeserializers.java) · [CVE-2026-89407](https://github.com/FasterXML/jackson-core/security/advisories/GHSA-p6pp-m3f8-5c89) · [CVE-2026-110879](https://github.com/FasterXML/jackson-databind/security/advisories/GHSA-m8xf-2cr7-77ph) · [Ciclo de Jackson](https://github.com/FasterXML/jackson/wiki/Jackson-Releases) |
| Boot 3.3.4, Framework 6.1.13 y Hibernate 6.5.3.Final | Boot 3.3, Framework 6.1 y ORM 6.5 terminaron su soporte abierto general. OSV señala avisos de arranque del contenedor y Spring MVC. El backend usa un chequeo de salud propio y carece de `EndpointRequest.to`, de Artemis y de uso directo de `JavaScriptUtils`. | Adoptar una línea mantenida con pruebas completas o evaluar soporte comercial. [Boot 3.3](https://spring.io/blog/2025/06/19/spring-boot-3-3-13-available-now/) · [Framework 6.1](https://spring.io/blog/2025/09/15/spring-framework-and-spring-security-fixes-for-CVE-2025-41249-and-CVE-2025-41248/) · [ORM 6.5](https://hibernate.org/orm/releases/6.5/) |
| Cloudinary 1.38.0, HttpClient 4.4, Commons Lang 3.14.0 | **Medio**, CVE-2020-13956 y CVE-2025-48924. El backend envía bytes a un host de SDK fijo y no admite URLs de destino ni nombres de clases de usuario. El SDK es anterior a la mejora de seguridad de 2025. | Verificar Cloudinary mantenido con HttpClient 5 y Commons Lang corregido, incluyendo carga firmada y compensación de fallos. [Cloudinary](https://cloudinary.com/documentation/java_integration) · [HttpClient](https://github.com/advisories/GHSA-7r82-7xv7-xcpj) · [Commons Lang](https://github.com/advisories/GHSA-j288-q9x7-2f5v) |
| Logback 1.5.8, SLF4J 2.0.16 | OSV asocia avisos a Logback Core. CVE-2024-12798 requiere influir en la configuración de logging y utilizar Janino. El perfil soportado rechaza configuración externa y Janino está ausente. | Actualizar con el BOM mantenido. Revisar el resto de avisos de Logback junto con el runtime final. [Logback](https://logback.qos.ch/news-archive.html) |
| Flyway 11.15.0, Connector/J 8.3.0, HikariCP 5.1.0 | Sin coincidencia en este cruce Maven. Flyway pide Databind 2.19.1 y el BOM fija 2.17.2 con una sola versión efectiva. Migraciones y arranque verificados, con Flyway desactivado en producción. Los avisos del servidor gestionado son independientes del driver. | Mantener versión coordinada de Flyway y Jackson en la próxima validación. Revisar la versión definitiva del servidor con el propietario. [Flyway](https://documentation.red-gate.com/flyway/release-notes-and-older-versions/release-notes-for-flyway-engine) · [Oracle CPU](https://www.oracle.com/security-alerts/cpuoct2026.html) |
| JJWT 0.11.5, correo y Firebase | JWT usa HS256 y sus tres módulos están alineados, fuera de la rama de soporte de JJWT. CVE-2024-31033 se retiró. Brevo usa el cliente HTTP del JDK y SMTP usa Angus 2.0.3. Firebase Admin está ausente. | Incluir actualización de JJWT y pruebas de JWT, Brevo y SMTP en la revisión de dependencias. [Soporte de JJWT](https://github.com/jwtk/jjwt/security) · [Aviso retirado](https://github.com/advisories/GHSA-r65j-6h5f-4f92) |
| Imagen base y herramientas | Temurin `17.0.21.1+2` en Ubuntu 22.04 LTS. Adoptium confirma que ese build corrige CVE-2026-114938. OSV cruzó 93 paquetes fuente Ubuntu y señaló 27 coordenadas. Por ejemplo, Canonical lista corrección de Kerberos en `1.19.2-2ubuntu0.12` frente a `1.19.2-2ubuntu0.10` en la imagen, con condiciones dependientes de los binarios y servicios usados. La API no configura Kerberos. Los avisos de OpenSSL y glibc requieren revisar su alcance en el runtime, más allá de Maven. Gradle, JUnit, Mockito y Lombok pertenecen al build o pruebas. | Revalidar digests y el alcance de los paquetes del sistema antes de publicar. [Adoptium](https://adoptium.net/news/2026/11/temurin-november-2026-cspu-java4shell) · [Ubuntu 22.04](https://ubuntu.com/security/esm) · [USN-9202-1](https://ubuntu.com/security/notices/USN-9202-1) · [CVE-2026-84786](https://ubuntu.com/security/CVE-2026-84786) · [CVE-2026-124024](https://ubuntu.com/security/CVE-2026-124024) |

### Propuesta separada para autorizar antes del corte

1. Priorizar una línea soportada de Spring Boot 4.x que conserve Java 17 y su BOM coordinado. Evaluar el cambio de Jackson y Hibernate, y verificar que la selección actual de Flyway siga validando el historial y `ddl-auto=validate`. Como alternativa temporal, evaluar una remediación autorizada de Tomcat 10.1, Jackson y Spring Security dentro del stack actual, con parches vigentes y soporte explícito. [Requisitos de Spring Boot](https://docs.spring.io/spring-boot/system-requirements.html) · [Distribuciones Tomcat 10.1](https://tomcat.apache.org/download-10.cgi)
2. Repetir SCA de runtime e imagen, revisar controles del proxy, cabeceras de respuestas autenticadas y errores, límites de multipart e integración HTTP. Verificar de nuevo hashes y checksums, TLS, permisos, flujo de primer administrador y la matriz de regresión.
3. Mantener P0 abierto y el corte bloqueado. Tras remediar y autorizar, comprobar en Render la imagen aprobada, la CA, las variables admitidas, la cadena del proxy y rutas HTTP. Comprobar en Vercel el `API_BASE_URL`, CORS, Preview y promoción manual. [Secuencia de corte](docs/PRODUCTION_DEPLOYMENT_RUNBOOK.md)

Para revertir una regresión de aplicación, usar el artefacto aprobado V3.5-B con el esquema definitivo y su historial V1–V6, conservar TLS y Flyway desactivado y comprobar las rutas de humo en mantenimiento. La reversión recupera el comportamiento anterior y conserva los bloqueantes de seguridad. [Reversión](docs/PRODUCTION_DEPLOYMENT_RUNBOOK.md#reversión-del-despliegue)

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
