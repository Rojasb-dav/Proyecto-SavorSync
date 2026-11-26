# Validación de migraciones MySQL — V3.2

> **Actualización V3.3.** V3.3 usa una copia estructural sintética en MySQL 8.4.13 y una base de destino nueva con V1–V5. Se conserva la evidencia V3.2 de 8.0 y del baseline de 22 tablas. La ruta parcial, su tratamiento de datos y el riesgo de DDL gestionado se detallan en [compatibilidad](AIVEN_SCHEMA_COMPATIBILITY.md) y [migración](PRODUCTION_MIGRATION_RUNBOOK.md).

Fecha: 2026-11-25. Entorno exclusivamente local de prueba en 127.0.0.1:3307. Ninguna conexión a Aiven ni otro servicio remoto.

## Base nueva

MysqlMigrationValidationTest completó en el esquema desechable foodies_db_v32_validation4:

1. Flyway validó el historial antes de ejecutar.
2. Aplicó V1 baseline original en base vacía; V2 tokens de recuperación; V3 identidades y límites; V4 seguimiento de recursos Cloudinary.
3. Se insertó una identidad sintética restaurant_admin y se aplicó V5 preservando el tipo solicitado, sin conceder rol efectivo.
4. Flyway se volvió a ejecutar para comprobar idempotencia.
5. El historial contiene cinco versiones exitosas.
6. Hibernate inició con ddl-auto=validate por SessionMySqlTest.
7. Se comprobaron 27 tablas base, 27 claves primarias, 32 claves foráneas y 23 triggers. También se verificaron el índice único del desafío activo y los tipos y nulabilidad de roles, plataformas de sesión y contenido de comentarios.
8. La prueba informa MySQL 8.0. Java 17 del toolchain no cambió.

Las cuatro tablas adicionales son tokens_recuperacion, account_identity_registry, auth_rate_limits y cloudinary_assets. V5 agrega una columna y no una tabla. No se usó ddl-auto=create, update ni none.

El servidor local bloqueaba la creación de triggers al usuario de prueba por binary logging. La prueba guardó el valor previo, habilitó temporalmente log_bin_trust_function_creators para esta validación local y lo restauró en finally. No se cambió Docker/WSL ni se trasladó la excepción a producción.

## Corrección de V5 e historial

La V5 del commit base referenciaba clientes.role. El SQL original y V1 declaran clientes.rol. MySQL rechazó la ejecución de V5 en el esquema de prueba que primero llegó a esta versión, después de ejecutar el ALTER TABLE. Se corrigió únicamente la referencia de columna y se comprobó el backfill en esquemas desechables. La corrección cambia el checksum. El historial de Aiven sigue sin inspección.

En un entorno con V5 fallida, la columna requested_role puede existir. Antes de recuperar, cotejar la columna, el backfill y el historial contra una copia restaurada. Si una variante de V5 figura como exitosa, comparar la definición y los datos con esta versión y planificar una reconciliación aprobada del historial o una migración posterior específica. Conservar el respaldo y el historial durante el diagnóstico.

## Esquema legado

MysqlLegacyBaselineValidationTest reproduce el esquema de 22 tablas en esquemas desechables. Lee schema_foodies_db.sql, pero sólo ejecuta desde CREATE TABLE clientes; no ejecuta DROP DATABASE, CREATE DATABASE o USE del encabezado destructivo. Inserta filas sintéticas de cliente, empleado, restaurante, publicación, seguimiento y reserva, establece baseline versión 1 de forma explícita y ejecuta V2–V5.

Se comprueba retención de filas y relaciones; el cliente legacy con rol restaurant_admin conserva el tipo solicitado y los empleados históricos no se marcan verificados automáticamente. La prueba de colisión introduce correos duplicados tras normalización entre cliente y empleado. V2 queda aplicada, V3 falla antes de completar identidades; ambas cuentas legacy permanecen y el registro central queda vacío. Esto confirma la necesidad de prevalidar y que DDL de MySQL puede dejar una migración parcialmente aplicada.

## Historial de esquemas aislados

- foodies_db quedó con un intento inicial V1 fallido por restricciones de MySQL al crear triggers con binary logging. Se dejó intacta.
- foodies_db_v32_validation y foodies_db_v32_validation2 conservan intentos parciales previos; se dejaron intactos.
- foodies_db_v32_validation3 no se reutilizó debido al checksum de V5 de una ejecución previa.
- foodies_db_v32_validation4 es la base nueva completa de esta validación.
- Los tests de esquema legado crean esquemas locales con nombres aleatorios y no exportan dumps ni datos al repositorio.

## Procedimiento futuro para base existente

1. Obtener respaldo restaurable y confirmar alcance/propietario.
2. Inspeccionar historial Flyway, checksums, versión DDL y las 22 tablas, triggers, FK, índices, ENUM y datos.
3. Comparar el esquema con V1 y la aplicación. V1 sirve para base vacía, no para una base poblada.
4. Buscar colisiones de email/username normalizados entre clientes y empleados; resolverlas con decisión auditada, sin borrar cuentas.
5. Revisar constraints, referencias, espacio, ventana de mantenimiento y restauración.
6. En base existente, aplicar baseline explícito aprobado sólo si el esquema coincide. No activar baselineOnMigrate automáticamente.
7. Probar migraciones aditivas en una copia restaurada y validar conteos, FK y referencias.
8. Ante fallo DDL, detener el proceso: MySQL puede confirmar DDL previo aunque Flyway registre fallo. Inspeccionar historial/esquema y preparar migración compensatoria aprobada. No reejecutar ciegamente ni eliminar el historial.

No se migró Aiven ni se usaron credenciales productivas. Una operación sobre producción necesita aprobación independiente y revisión DBA.
