# Configuración de infraestructura V3.3

## Render y JDBC

Configurar Root Directory en backend/backend, Dockerfile Path en Dockerfile y Docker Build Context Directory en . respecto a ese directorio. Docker ejecuta bootJar con Gradle Wrapper y copia backend.jar de forma inequívoca. Configurar Health Check Path en /actuator/health. HTTP 200 UP indica que el backend puede consultar la base. HTTP 503 DOWN indica que no puede. El resultado no incluye detalles ni depende de Brevo o Cloudinary. Revisar la rama y los despliegues automáticos antes de aprobar cambios. [Secret Files de Render](https://render.com/docs/docker-secrets)

| Variable | Valor o criterio |
|---|---|
| SPRING_PROFILES_ACTIVE | production |
| SPRING_DATASOURCE_URL | jdbc:mysql://mysql-210b7696-savorsync-db.i.aivencloud.com:<PUERTO_AIVEN>/defaultdb |
| SPRING_DATASOURCE_USERNAME | savorsync_backend |
| SPRING_DATASOURCE_PASSWORD | Secreto del usuario de aplicación |
| APP_JWT_SECRET | Valor nuevo generado y custodiado por el propietario |
| APP_CORS_ALLOWED_ORIGINS | https://proyecto-savorsync-mobile.vercel.app y únicamente orígenes aprobados |
| APP_FLYWAY_ENABLED | false para servicio habitual. El perfil production fuerza Flyway desactivado. |
| CLOUDINARY_CLOUD_NAME | jflzrtvk |
| CLOUDINARY_API_KEY / CLOUDINARY_API_SECRET | Par de la clave restringida SavorSync-Backend |
| CLOUDINARY_ASSET_FOLDER | foodies |
| BREVO_API_KEY | Secreto restringido de Transactional email |
| BREVO_SENDER_EMAIL / BREVO_SENDER_NAME | Remitente verificado del propietario y SavorSync |
| RENDER_TRUSTED_PROXY_REGEX | Expresión que solo coincide con saltos de ingreso verificados. Por defecto no coincide con ninguna IP. |

Adjuntar aiven-ca.pem en Secret Files. El proceso importa el archivo de runtime /etc/secrets/aiven-ca.pem a un PKCS12 temporal con permisos privados. Connector/J usa ese almacén, VERIFY_IDENTITY y fallback desactivado. Usar el DNS emitido y el puerto del panel. El entrypoint rechaza parámetros JDBC de producción, de modo que la URL no puede desactivar la política TLS. El almacén global de Java sigue disponible para HTTPS externo. Nunca copiar certificados ni secretos a las capas de imagen. [Verificación de servidor Connector/J](https://dev.mysql.com/doc/connector-j/en/connector-j-server-authentication.html)

Para restringir permisos, identificar primero el host exacto de la cuenta y revisar si recibe privilegios de roles. Ejecutar con la identidad administrativa autorizada en mantenimiento. Sustituir HOST_VERIFICADO según SHOW GRANTS.

```sql
SHOW GRANTS FOR 'savorsync_backend'@'<HOST_VERIFICADO>';
GRANT SELECT, INSERT, UPDATE, DELETE ON defaultdb.* TO 'savorsync_backend'@'<HOST_VERIFICADO>';
REVOKE SELECT, INSERT, UPDATE, DELETE ON *.* FROM 'savorsync_backend'@'<HOST_VERIFICADO>';
ALTER USER 'savorsync_backend'@'<HOST_VERIFICADO>' REQUIRE SSL;
SHOW GRANTS FOR 'savorsync_backend'@'<HOST_VERIFICADO>';
```

Confirmar grants y roles heredados. Probar Hibernate validate, SELECT FOR UPDATE, transacciones, health, registro, reenvío, actualización y revocación. El usuario de aplicación no ejecuta DDL. Usar la identidad administrativa autorizada para Flyway y los triggers. La restricción efectiva con la cuenta de Aiven queda como validación del propietario.

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
