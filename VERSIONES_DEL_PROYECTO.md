# Versiones del proyecto

Registro de cambios, decisiones y resultados de verificación de SavorSync. El [README](README.md) describe el estado vigente. Las cifras siguientes provienen de los informes de cada iteración.

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
