# Entrega de auditoría P0 V3.3

Base `486baca100b23b17ca3a42aa39a47b76a8f2a4f3` en `fix/savorsync-remediation-v3`. `main` se comprobó en `b3da13aa2981ac66cb857929ddee5d84bed687dd`. Esta entrega prepara la integración de infraestructura. P0 queda abierto hasta que el propietario complete el ensayo, las autorizaciones y las verificaciones de producción.

## Hallazgos y evidencia

| ID | Causa y cambio | Verificación y decisión pendiente |
|---|---|---|
| V3.3-01 | El esquema de Aiven tiene 12 tablas y difiere del modelo Flyway. Se documentó la comparación y se agregó `ops/copy-partial-schema.sql`. Usa un destino nuevo V1–V5 y copia desde un origen restaurado, con FK activas y transacción. | DDL estructural inspeccionado. MySQL 8.0 validó instalación limpia y baseline de 22 tablas. MySQL 8.4.13 validó V1–V5, copia de fixture compatible, rechazo de datos incompatibles, preservación de IDs y relaciones y Spring con JPA validate. Queda ensayar con la restauración privada, autorizar mapeos de datos incompatibles y confirmar los triggers en el servicio 8.4.11. |
| V3.3-02 | SMTP era la única entrega. `SecurityEmailDispatcher` ahora usa `SecurityEmailProvider` después del commit. `BrevoSecurityEmailProvider` usa HTTPS con tiempos máximos, estado sanitizado, cuerpo descartado y sin reintentos implícitos de aplicación. | Siete pruebas HTTP simuladas cubren 201, 400, 401, 403, 429, 503 y timeout/configuración. Los flujos de OTP, reenvío y recuperación conservan su contrato y proveedor simulado. El propietario ya comprobó entrega Brevo desde PowerShell. La prueba real desde Spring Boot queda pendiente. |
| V3.3-03 | Las cargas no declaraban la carpeta autorizada. `CloudinaryService` serializa `asset_folder=foodies`, usa un ID único, `overwrite=false`, tag de origen y respuesta HTTPS. | Prueba directa de los parámetros del SDK 1.38.0 y rechazo sanitizado. La suite conservó pruebas de titularidad, reutilización, rollback y compensación. El propietario ya comprobó la clave restringida con una imagen sintética. Quedan el recorrido desde Spring y la retirada planificada de la clave Root y preset legado. |
| V3.3-04 | El seeder de desarrollo no sirve para iniciar producción. `FirstAdminCommand` usa consola interactiva, modo no web y autorización explícita. `FirstAdminProvisioning` registra una cuenta interna BCrypt sin verificar y rechaza repetición o colisión. | Prueba de provisión y arranque sobre MySQL 8.4.13. HTTP comprobó rechazo del login hasta OTP simulado, login posterior, acceso administrativo y creación de moderador. La ejecución de la orden con identidad real queda reservada al propietario. |
| V3.3-05 | El contenedor carecía de configuración de confianza JDBC. El entrypoint importa la CA a PKCS12 temporal y el perfil production configura Connector/J con VERIFY_IDENTITY sin afectar el almacén global. Tomcat solo acepta origen reenviado desde proxies configurados. | Docker rechazó una CA ausente y una inválida antes de conectarse. El contenedor arrancó y ejecutó health con un usuario local de permisos DML. El propietario comprobó VERIFY_IDENTITY mediante cliente MySQL previamente. Quedan prueba JDBC con CA real, grants efectivos, topología de proxies y rotaciones. |
| V3.3-06 | El contexto Docker anterior podía copiar archivos innecesarios y seleccionar varios JAR. Se acotó COPY, se añadieron exclusiones, se fijaron imágenes Temurin y un bootJar y se agregó health mínimo. | Docker Desktop compiló en Linux con `backend/backend`, tras exponer su helper en el PATH del proceso. El contenedor arrancó y HTTP respondió 200 con `{"status":"UP"}`. Prueba unitaria de 503/DOWN. La configuración externa de Render se documentó y queda a cargo del propietario. |
| V3.3-07 | Flutter usaba un endpoint fijo. `ApiService` y `main` validan el dart define y muestran un error legible si falta. Android debug permite HTTP loopback acotado. Vercel usa un script con Flutter 3.41.9 y el lockfile. | Evidencia Flutter y navegador en la tabla de validación. La configuración y promoción Vercel quedan pendientes. |
| V3.3-08 | Un perfil creado como Foodie no podía presentar una solicitud administrativa. `IdentityService` actualiza el tipo solicitado bajo transacción sin otorgar permisos. Se mantiene la aprobación exclusiva y la revocación. | El flujo HTTP sobre MySQL 8.4 comprobó solicitud posterior al registro como Foodie, repetición idempotente, moderador 403, admin 200 y JWT anterior 401. La suite de V3.2 conserva alcance de privacidad y titularidad. La matriz diferencia política y cobertura directa. |
| V3.3-09 | Faltaba una verificación coordinada de infraestructura y clientes. Se ejecutaron los casos locales con fixtures y pruebas con proveedor simulado. | Consultar los resultados siguientes. Las integraciones de producción y la firma del APK release están pendientes. |

## Validación

| Comprobación | Resultado |
|---|---|
| Gradle 9.4.1 y Java 17. `test --no-daemon --rerun-tasks` | **79 aprobadas, 0 fallidas, 0 errores, 0 omitidas** en 17 XML JUnit. |
| `gradlew.bat build --no-daemon` | Correcto. |
| MySQL 8.0.46 local en puerto 3307 | V1–V5, baseline original, 10 casos de sesión y concurrencia. Imagen Docker con usuario de permisos DML en el esquema local. |
| MySQL 8.4.13 local en puerto 3308 | Dos casos del modelo parcial. El caso compatible arrancó el backend real con validate y un proveedor de correo simulado. El caso incompatible dejó el destino sin filas copiadas. La instancia de prueba se detuvo al terminar sin eliminar su esquema o volumen. |
| Docker Linux | Imagen `savorsync-backend:v33-local` compilada. Fallo inicial reproducible `docker-credential-desktop: executable file not found in %PATH%`, corregido al añadir el directorio de Docker Desktop al PATH del proceso. Validación de health y CA descrita arriba. |
| Flutter 3.41.9 y Dart 3.11.5 | pub get correcto, 11 pruebas aprobadas, Web release y APK debug compilados con API loopback. Analyze registró 16 diagnósticos informativos preexistentes y ningún error o advertencia. |
| Chrome 158, Web compilado | El HTML local respondió 200 con base href /. DevTools verificó que Flutter montó la vista y que un fetch desde http://127.0.0.1:8081 hacia el backend Docker obtuvo 401 esperado en /auth/me. El navegador pudo completar la petición CORS con X-Platform. La comprobación descartó un fallo de montaje en este arranque local. Sigue pendiente el recorrido visual completo de la Preview de Vercel. |
| Corredor Flutter en Chrome | Reintento con trazas. DDC compiló, el servidor de pruebas abrió su puerto y Chromium publicó DevTools. La ejecución agotó 120 segundos después de `Running test suite test\\api_base_url_test.dart` sin conteo final. La comprobación del sitio estático en Chrome se ejecutó por separado. |
| Android | No había dispositivo ni emulador conectado en flutter devices. La validación llegó hasta APK debug. Firma release pendiente de la configuración real del propietario. |

## Estado de P0 y corte

| Área | Estado |
|---|---|
| P0.1 Credenciales | Configuración y custodia documentadas. Se desactivó el usuario generado de Spring Security y se comprobó que la ejecución de pruebas no registró su contraseña. Rotaciones reales pendientes. |
| P0.2 Autenticación y sesiones | Verificada localmente, incluida la revocación después de aprobar el nuevo rol. |
| P0.3 Autorización | Denegación por defecto y casos representativos verificados localmente. La matriz distingue cobertura directa e inspección. |
| P0.4 Identidad | Verificada localmente con OTP simulado e identidad de prueba. Provisión real pendiente. |
| P0.5 Migración | Verificada localmente en MySQL 8.0 y 8.4. Corte y compatibilidad de triggers en Aiven pendientes. |
| P0.6 Infraestructura | Imagen y arranque locales verificados. TLS, proxy y variables reales de Render y Vercel pendientes. |
| P0.7 Recuperación | Concurrencia y rechazo verificados localmente con correo simulado. Entrega real de Spring por Brevo pendiente. |
| P0.8 Archivos | Parámetros, titularidad y compensación verificados localmente. Carga desde Spring con la clave real y retirada de preset pendientes. |

El propietario reportó CA JDBC preparada, comprobación previa de TLS, prueba transaccional Brevo, permisos de Cloudinary limitados a foodies y preparación de Firebase. La ejecución de despliegue, entrega real, rotaciones y reactivación sigue reservada al propietario. Firebase permanece en P1.14. Consultar [configuración](INFRASTRUCTURE_CONFIGURATION.md), [migración](PRODUCTION_MIGRATION_RUNBOOK.md) y [corte](PRODUCTION_DEPLOYMENT_RUNBOOK.md).
