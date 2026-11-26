# Configuración de infraestructura

## Render y JDBC

Configurar Root Directory en backend/backend, Dockerfile Path en Dockerfile y Docker Build Context Directory en . respecto a ese directorio. Docker ejecuta bootJar con Gradle Wrapper y copia backend.jar de forma inequívoca. Configurar Health Check Path en /actuator/health. HTTP 200 UP indica que el backend puede consultar la base. HTTP 503 DOWN indica que no puede. El resultado no incluye detalles ni depende de Brevo o Cloudinary. Revisar la rama y los despliegues automáticos antes de aprobar cambios. [Secret Files de Render](https://render.com/docs/docker-secrets)

| Variable | Valor o criterio |
|---|---|
| SPRING_PROFILES_ACTIVE | production |
| SPRING_DATASOURCE_URL | `jdbc:mysql://<HOST_DNS_AIVEN>:28223/savorsync_v34_validation` |
| SPRING_DATASOURCE_USERNAME | `savorsync_v34_backend` |
| SPRING_DATASOURCE_PASSWORD | Secreto del usuario de aplicación |
| APP_JWT_SECRET | Valor nuevo generado y custodiado por el propietario |
| APP_CORS_ALLOWED_ORIGINS | https://proyecto-savorsync-mobile.vercel.app y únicamente orígenes aprobados |
| APP_FLYWAY_ENABLED | false. El entrypoint de producción fija Flyway desactivado y Hibernate en `validate`. |
| CLOUDINARY_CLOUD_NAME | jflzrtvk |
| CLOUDINARY_API_KEY / CLOUDINARY_API_SECRET | Par de la clave restringida SavorSync-Backend |
| CLOUDINARY_ASSET_FOLDER | foodies |
| BREVO_API_KEY | Secreto restringido de Transactional email |
| BREVO_SENDER_EMAIL / BREVO_SENDER_NAME | Remitente verificado del propietario y SavorSync |
| RENDER_TRUSTED_PROXY_REGEX | Expresión que solo coincide con saltos de ingreso verificados. Por defecto no coincide con ninguna IP. |

Adjuntar aiven-ca.pem en Secret Files. El proceso importa el archivo de runtime /etc/secrets/aiven-ca.pem a un PKCS12 temporal con permisos privados. Connector/J usa ese almacén, VERIFY_IDENTITY y fallback desactivado. Usar el DNS cubierto por el certificado y el puerto verificado de Aiven, `28223`. El entrypoint solo acepta `jdbc:mysql://<host>:<puerto>/savorsync_v34_validation`. Se rechazan `defaultdb`, parámetros, fragmentos, credenciales en la URL, múltiples hosts y sintaxis alternativas. Configurar la conexión por entorno con `SPRING_PROFILES_ACTIVE=production`. El entrypoint fija la URL validada para Spring Boot y Hikari. Conservar las credenciales en variables separadas. El almacén global de Java sigue disponible para HTTPS externo. Nunca copiar certificados ni secretos a las capas de imagen. [Verificación de servidor Connector/J](https://dev.mysql.com/doc/connector-j/en/connector-j-server-authentication.html)

### Configuración admitida en producción

Arrancar la imagen publicada con su entrypoint y `SPRING_PROFILES_ACTIVE=production`. Para el primer administrador, conservar ese perfil y usar el argumento `--savorsync-bootstrap-admin` con la habilitación controlada. Java agrega `bootstrap-admin` internamente. `test` y `development` siguen disponibles para arranques separados.

Spring Boot puede asignar prioridad sobre los archivos empaquetados a variables, propiedades JVM, JSON y argumentos. Sus reglas de perfiles también permiten activar `production` por inclusión, grupo o perfil por defecto. En el arranque administrado, el entrypoint usa únicamente configuración empaquetada y aporta los argumentos que fijan la URL y las opciones de migración y validación. Antes de que Boot lea JSON o imports, el guard rechaza propiedades externas de Spring, Hibernate, Flyway y logging. Para Spring solo admite `SPRING_PROFILES_ACTIVE` y `SPRING_DATASOURCE_URL`, `SPRING_DATASOURCE_USERNAME` y `SPRING_DATASOURCE_PASSWORD`. Rechaza variantes de nombres, opciones JVM externas y argumentos de Spring. En Linux comprueba también los nombres originales de las variables con puntos, que el intérprete puede descartar antes de lanzar Java. Después de resolver los perfiles comprueba que `production` procede del entrypoint, antes de inicializar conexiones. [Configuración externa de Spring Boot](https://docs.spring.io/spring-boot/3.3/reference/features/external-config.html) · [Perfiles de Spring Boot](https://docs.spring.io/spring-boot/3.3/reference/features/profiles.html)

Si están presentes en Render, retirar `SPRING_JPA_HIBERNATE_DDL_AUTO`, `SPRING_FLYWAY_ENABLED`, `SPRING_APPLICATION_JSON` y otros overrides heredados incompatibles. Confirmar los valores efectivos de perfil, URL, usuario, referencia al secreto y CA antes del corte.

El límite de confianza es el operador de la imagen y sus montajes. El operador controla el DNS, el CA montado, las credenciales y el proceso. Debe proteger el archivo Secret File y el acceso a inspección del contenedor. Reemplazar el entrypoint, el JAR o la imagen deja el arranque fuera del contrato soportado. Las contraseñas se entregan por entorno o consola interactiva, según la operación.

### Cuentas y permisos verificados en Aiven

Aiven MySQL 8.4.11 tiene `partial_revokes=ON`. El propietario comprobó por conexiones reales los permisos restringidos por esquema y el aislamiento entre `defaultdb` y `savorsync_v34_validation`. Queda verificar en Render qué cuenta, secreto, URL y CA utiliza la imagen desplegada.

| Cuenta | Responsabilidad |
|---|---|
| `savorsync_backend` | Cuenta histórica asociada a `defaultdb`. Mantenerla separada del esquema definitivo. |
| `savorsync_v34_backend` | Cuenta definitiva de Render. DML sobre `savorsync_v34_validation`, sin DDL. |
| `savorsync_v34_migration` | Cuenta separada para Flyway y DDL del esquema definitivo. Conservar `savorsync_v34_migration@%` como definidor de los 31 triggers. |
| `avnadmin` | Administración del servicio y revisión de cuentas y permisos. Mantener sus credenciales fuera de Render. |

Para auditar, consultar primero `SHOW GRANTS` desde cada cuenta o con la identidad administrativa autorizada y el host exacto. Revisar roles y restricciones heredados. Si los permisos efectivos coinciden con la verificación, conservar las cuentas y los grants existentes. El siguiente ejemplo se reserva para una corrección autorizada. Con `partial_revokes=ON`, los guiones bajos son literales en el nombre del esquema y se escriben sin barras invertidas. Sustituir `<HOST_VERIFICADO>` por el host real de la cuenta.

```sql
SHOW GRANTS FOR 'savorsync_v34_backend'@'<HOST_VERIFICADO>';
-- Solo si falta el DML y la corrección está autorizada.
GRANT SELECT, INSERT, UPDATE, DELETE ON `savorsync_v34_validation`.* TO 'savorsync_v34_backend'@'<HOST_VERIFICADO>';
```

Render antepone infraestructura de proxy. El servidor ignora encabezados de clientes directos por defecto. Después de verificar los rangos y la cadena de ingreso, configurar el patrón de Tomcat solo para saltos confiables y comprobar con peticiones que incluyan X-Forwarded-For arbitrario. Con patrón vacío o sin coincidencia, getRemoteAddr conserva el salto inmediato y puede agrupar cuotas de origen; validarlo antes de abrir tráfico. El backend usa los límites de código vigentes de 5 solicitudes aceptadas por identidad y 100 por origen en 60 minutos, pausa de reenvío de 60 segundos, OTP de 15 minutos y cinco errores por desafío. [Ingreso y direcciones en Render](https://render.com/articles/how-render-handles-ddos-attacks)

## Clientes

| Uso | API_BASE_URL y configuración |
|---|---|
| Web local | http://127.0.0.1:8080/api/v1 con ALLOW_LOCAL_HTTP=true. Servir Flutter en http://127.0.0.1:8081 y agregar ese origen al backend local. |
| Emulador Android debug | http://10.0.2.2:8080/api/v1 con ALLOW_LOCAL_HTTP=true. |
| Android físico debug | adb reverse tcp:8080 tcp:8080 y http://127.0.0.1:8080/api/v1 con ALLOW_LOCAL_HTTP=true. |
| Web y Android de producción | https://proyecto-savorsync.onrender.com/api/v1, con HTTPS. |

Vercel usa root mobile y publica build/web. build-vercel.sh descarga Flutter 3.41.9 y verifica su revisión antes de compilar con Dart 3.11.5 y el lockfile. Definir API_BASE_URL de forma explícita por entorno. El cliente muestra un error de configuración si falta o es inválida. Se conserva el esquema actual de rutas Flutter por hash. No se añade rewrite SPA. Revisar base href, flutter_bootstrap.js, assets, consola, CORS y caché/service worker si reaparece el blanco. No promover una Preview por su sola captura.

## Proveedores

Brevo usa api-key, sender, destinatario y texto vía HTTPS con timeout. Un 201 significa aceptación del proveedor, no entrega al buzón. Usar el historial transaccional para verificar la entrega. Después de un fallo, esperar la cuota de reenvío. Los logs generales muestran solo el resultado clasificado. [API transaccional Brevo](https://developers.brevo.com/reference/send-transac-email)

Cloudinary Java 1.38.0 serializa asset_folder como opción firmada. Confirmar modo de carpetas dinámicas y permisos de la clave limitada. Los activos nuevos llevan el tag savorsync_backend_v33 y un public_id único. Para buscar huérfanos, comparar ese tag y la fecha con cloudinary_assets, avatares e imágenes de publicación y restaurante. Excluir recursos históricos, cargas recientes y cualquier URL o public_id referenciado. Hacer revisión manual antes de borrar. Si falla la persistencia, el controlador intenta compensación de ese public_id. Juntar evidencia externa solo después de la aprobación del propietario. [Carpetas Cloudinary](https://cloudinary.com/documentation/folder_modes) · [Serialización del SDK Java](https://raw.githubusercontent.com/cloudinary/cloudinary_java/1.38.0/cloudinary-core/src/main/java/com/cloudinary/Util.java)
