# SavorSync V3.6-A · Inventario y clasificación de seguridad

Consulta de fuentes públicas el 26 de noviembre de 2026. Base revisada: d4a63195ed20b9b05063fc49bcd7d48debbda846. [Informe de arquitectura](SavorSync-V3.6-A-Arquitectura-2026-11-26.md).

Se recuperó el inventario histórico V3.5-C de 86 coordenadas de Maven del grafo de runtime y se revisaron sus 97 identificadores GHSA únicos mediante registros OSV. Los alias CVE identifican el mismo aviso y cuentan una sola vez, incluso cuando varios módulos incorporan el componente afectado. Las familias se identifican en la columna Dependencia. Las versiones de corrección son las publicadas para diferentes ramas y su selección exige verificar el BOM y el paquete final. La severidad es la indicada en OSV cuando existe. N/D indica que el registro consultado omite ese dato. La evidencia sobre alcance proviene de los archivos de código y configuración del commit y de los resultados de referencia documentados en V3.5-C. [API de OSV](https://google.github.io/osv.dev/api/) · [GitHub Advisory Database](https://github.com/advisories) · [NVD](https://nvd.nist.gov/).

| Clasificación | Total |
| --- | ---: |
| Aplicable | 4 |
| Mitigado y verificado | 1 |
| No aplicable con justificación | 87 |
| Pendiente de investigación | 5 |
| **Total histórico** | **97** |

Los avisos marcados como no aplicables dependen de conservar la configuración observada. Reabrir el análisis si cambia un proxy, se habilitan protocolos o módulos opcionales, o se admiten orígenes, tipos JSON, destinos o metadatos que actualmente controla el servidor. La verificación de BCrypt corresponde a una prueba documentada de V3.5-C. Esta intervención fue de lectura y revisión de evidencia, sin una nueva ejecución de pruebas.

## Identificadores históricos de V3.5-C

### Superficies aplicables

| N.º | Aviso y alias | Dependencia | Severidad OSV | Versiones de corrección registradas | Evidencia de SavorSync y alcance |
| ---: | --- | --- | --- | --- | --- |
| 9 | [GHSA-p6pp-m3f8-5c89](https://osv.dev/vulnerability/GHSA-p6pp-m3f8-5c89) · CVE-2026-89407 | jackson-core | HIGH | 2.18.11, 2.21.7, 2.22.3, 3.1.7, 3.2.2 | Coerción JSON numérica en campos Double de reseñas y otros DTO Servlet. La validación del negocio ocurre después de deserializar. |
| 48 | [GHSA-h3gc-qfqq-6h8f](https://osv.dev/vulnerability/GHSA-h3gc-qfqq-6h8f) · CVE-2025-48988 | tomcat-embed-core | HIGH | 11.0.8, 10.1.42, 9.0.106 | Endpoint multipart de carga para Foodie y Restaurant Admin. El límite de bytes vigente no limita de forma independiente las partes. |
| 52 | [GHSA-hgrr-935x-pq79](https://osv.dev/vulnerability/GHSA-hgrr-935x-pq79) · CVE-2025-61795 | tomcat-embed-core | LOW | 11.0.12, 10.1.47, 9.0.110 | Multipart real y almacenamiento temporal estándar de Tomcat. El riesgo aparece en errores de carga y depende de espacio y concurrencia. |
| 96 | [GHSA-mf92-479x-3373](https://osv.dev/vulnerability/GHSA-mf92-479x-3373) · CVE-2026-22732 | spring-security-web | CRITICAL | 6.5.9, 7.0.4 | Cadena Spring Security Servlet con encabezados por defecto y respuestas autenticadas susceptibles de caché. La mitigación del proveedor no está instalada. |

### Mitigación con evidencia histórica

| N.º | Aviso y alias | Dependencia | Severidad OSV | Versiones de corrección registradas | Evidencia de SavorSync y alcance |
| ---: | --- | --- | --- | --- | --- |
| 93 | [GHSA-mg83-c7gq-rv5c](https://osv.dev/vulnerability/GHSA-mg83-c7gq-rv5c) · CVE-2025-22228 | spring-security-crypto | HIGH | 6.3.8, 6.4.4, 6.2.10, 6.1.14, 6.0.16, 5.8.18, 5.7.16 | AuthService corta la entrada antes de BCrypt. SessionMySqlTest documentó 72 y 73 bytes UTF-8 para cliente y empleado, con 200 y 401. |

### Superficies pendientes de verificación

| N.º | Aviso y alias | Dependencia | Severidad OSV | Versiones de corrección registradas | Evidencia de SavorSync y alcance |
| ---: | --- | --- | --- | --- | --- |
| 29 | [GHSA-3p2h-wqq4-wf4h](https://osv.dev/vulnerability/GHSA-3p2h-wqq4-wf4h) · CVE-2025-31650 | tomcat-embed-core | MODERATE | 9.0.104, 10.1.40, 11.0.6 | El conector está en el rango afectado. Confirmar en laboratorio la ruta efectiva de procesamiento de Priority y el transporte proxy a Tomcat. |
| 31 | [GHSA-563x-q5rq-57qp](https://osv.dev/vulnerability/GHSA-563x-q5rq-57qp) · CVE-2026-24880 | tomcat-embed-core | HIGH | 9.0.116, 10.1.52, 11.0.20 | Falta comprobar si el proxy y el backend discrepan en el procesamiento de solicitudes fragmentadas. La presencia del proxy no confirma esa condición. |
| 61 | [GHSA-wr62-c79q-cv37](https://osv.dev/vulnerability/GHSA-wr62-c79q-cv37) · CVE-2025-52520 | tomcat-embed-core | HIGH | 11.0.9, 10.1.43, 9.0.107 | Multipart activo. Falta cotejar la configuración efectiva del conector con las condiciones de desbordamiento indicadas por Apache. |
| 77 | [GHSA-cjpg-rgq5-fr37](https://osv.dev/vulnerability/GHSA-cjpg-rgq5-fr37) · CVE-2026-41853 | spring-webmvc | MODERATE | 7.0.8, 6.2.19 | Spring MVC y carga activos. Falta confirmar si el proxy o WAF analiza las partes y toma decisiones a partir de su contenido. |
| 90 | [GHSA-9fw2-h3hf-293r](https://osv.dev/vulnerability/GHSA-9fw2-h3hf-293r) · CVE-2026-41716 | spring-data-commons | HIGH | 4.0.6, 3.5.12 | Se usan proyecciones JPA de forma interna. Verificar que ningún resolver accesible desde HTTP permita claves de propiedades arbitrarias en el caché de Spring Data. |

### No aplicables a la configuración y al código observados

| N.º | Aviso y alias | Dependencia | Severidad OSV | Versiones de corrección registradas | Evidencia de SavorSync y alcance |
| ---: | --- | --- | --- | --- | --- |
| 1 | [GHSA-25qh-j22f-pwp8](https://osv.dev/vulnerability/GHSA-25qh-j22f-pwp8) · CVE-2025-11226 | logback-core | MODERATE | 1.5.19, 1.3.16 | Janino ausente del inventario. La configuración de logging está empaquetada y el guard rechaza las fuentes de configuración externa soportadas. |
| 2 | [GHSA-6v67-2wr5-gvf4](https://osv.dev/vulnerability/GHSA-6v67-2wr5-gvf4) · CVE-2024-12801 | logback-core | LOW | 1.5.13, 1.3.15 | Necesita controlar configuración XML o logging. No hay entrada HTTP que modifique esos archivos y el guard bloquea overrides de logging soportados. |
| 3 | [GHSA-jhq6-gfmj-v8fx](https://osv.dev/vulnerability/GHSA-jhq6-gfmj-v8fx) · CVE-2026-10532 | logback-core | LOW | 1.5.34 | El backend no inicia SimpleSocketServer o SimpleSSLSocketServer de Logback y usa logging local. |
| 4 | [GHSA-p47f-322f-whfh](https://osv.dev/vulnerability/GHSA-p47f-322f-whfh) · CVE-2026-9828 | logback-core | LOW | 1.5.33 | El backend no inicia SimpleSocketServer o SimpleSSLSocketServer de Logback y usa logging local. |
| 5 | [GHSA-pr98-23f8-jwxv](https://osv.dev/vulnerability/GHSA-pr98-23f8-jwxv) · CVE-2024-12798 | logback-core | MODERATE | 1.5.13, 1.3.15 | Janino ausente del inventario. La configuración de logging está empaquetada y el guard rechaza las fuentes de configuración externa soportadas. |
| 6 | [GHSA-qqpg-mvqg-649v](https://osv.dev/vulnerability/GHSA-qqpg-mvqg-649v) · CVE-2026-1225 | logback-core | LOW | 1.5.25 | Necesita controlar configuración XML o logging. No hay entrada HTTP que modifique esos archivos y el guard bloquea overrides de logging soportados. |
| 7 | [GHSA-72hv-8253-57qq](https://osv.dev/vulnerability/GHSA-72hv-8253-57qq) · CVE-2026-18401 | jackson-core | MODERATE | 3.1.0, 2.21.1, 2.18.6 | Requiere parser no bloqueante de Jackson. El HTTP del backend usa Spring MVC Servlet y los mappers revisados son bloqueantes. |
| 8 | [GHSA-7hhh-6rmp-j9qf](https://osv.dev/vulnerability/GHSA-7hhh-6rmp-j9qf) · CVE-2026-89425 | jackson-core | HIGH | 2.21.7, 2.22.3, 3.1.7, 3.2.3, 2.18.11 | La API no construye parsers Jackson sobre DataInput. Usa cuerpos HTTP Servlet, JSON de respuesta y el mapper del transporte HTTP. |
| 10 | [GHSA-r7wm-3cxj-wff9](https://osv.dev/vulnerability/GHSA-r7wm-3cxj-wff9) · CVE-2026-68494 | jackson-core | HIGH | 2.18.8, 2.21.4, 3.1.4 | Requiere parser no bloqueante de Jackson. El HTTP del backend usa Spring MVC Servlet y los mappers revisados son bloqueantes. |
| 11 | [GHSA-3pjw-73gf-8qr5](https://osv.dev/vulnerability/GHSA-3pjw-73gf-8qr5) · CVE-2026-59888 | jackson-databind | MODERATE | 2.18.8, 2.21.4, 3.1.4 | No se observó la combinación de record con @JsonIgnore y estrategia de renombrado afectada. |
| 12 | [GHSA-5gvw-p9qm-jgwh](https://osv.dev/vulnerability/GHSA-5gvw-p9qm-jgwh) · CVE-2026-59889 | jackson-databind | MODERATE | 2.21.5, 3.1.5, 2.18.9, 2.22.1, 3.2.1 | No se observó combinación de @JsonView con @JsonUnwrapped ni vista activa para datos de entrada. |
| 13 | [GHSA-5jmj-h7xm-6q6v](https://osv.dev/vulnerability/GHSA-5jmj-h7xm-6q6v) · CVE-2026-54515 | jackson-databind | MODERATE | 3.1.4, 2.18.9, 2.21.5, 2.22.1 | El DTO que ignora propiedades desconocidas no configura formato case insensitive por propiedad ni el patrón de exclusión anidada. |
| 14 | [GHSA-cxp5-3px4-pw24](https://osv.dev/vulnerability/GHSA-cxp5-3px4-pw24) · CVE-2026-91777 | jackson-databind | HIGH | 2.21.7, 3.1.7, 3.2.3, 2.18.11, 2.22.3 | No se observó @JsonIdentityInfo ni resolución de referencias de objeto en DTO deserializados. |
| 15 | [GHSA-gx83-3vf8-gh7j](https://osv.dev/vulnerability/GHSA-gx83-3vf8-gh7j) · CVE-2026-83557 | jackson-databind | MODERATE | 3.1.6, 3.2.2, 2.18.10, 2.21.6, 2.22.2 | No se observó tipado polimórfico con identificadores de clase ni el validador o allowlist que requiere el aviso. |
| 16 | [GHSA-hgj6-7826-r7m5](https://osv.dev/vulnerability/GHSA-hgj6-7826-r7m5) · CVE-2026-54514 | jackson-databind | MODERATE | 2.18.8, 2.21.4, 3.1.4 | Ningún DTO de entrada se enlaza a InetSocketAddress, InetAddress ni a esos tipos de red en payloads estructurados. |
| 17 | [GHSA-j3rv-43j4-c7qm](https://osv.dev/vulnerability/GHSA-j3rv-43j4-c7qm) · CVE-2026-54512 | jackson-databind | HIGH | 2.18.8, 3.1.4, 2.21.4 | No se observó tipado polimórfico con identificadores de clase ni el validador o allowlist que requiere el aviso. |
| 18 | [GHSA-q4xh-88c3-wmh7](https://osv.dev/vulnerability/GHSA-q4xh-88c3-wmh7) · CVE-2026-68497 | jackson-databind | HIGH | 3.2.2, 3.1.6, 2.18.10, 2.21.6, 2.22.2 | El contrato usa java.time. No recibe Duration XML ni XMLGregorianCalendar desde JSON. |
| 19 | [GHSA-rmj7-2vxq-3g9f](https://osv.dev/vulnerability/GHSA-rmj7-2vxq-3g9f) · CVE-2026-54513 | jackson-databind | HIGH | 2.18.8, 2.21.4, 3.1.4 | No se observó tipado polimórfico con identificadores de clase ni el validador o allowlist que requiere el aviso. |
| 20 | [GHSA-vvgp-rfg2-7rr6](https://osv.dev/vulnerability/GHSA-vvgp-rfg2-7rr6) · CVE-2026-77310 | jackson-databind | MODERATE | 2.18.9, 2.21.5, 2.22.1, 3.1.5, 3.2.1 | Ningún DTO de entrada se enlaza a InetSocketAddress, InetAddress ni a esos tipos de red en payloads estructurados. |
| 21 | [GHSA-wjgm-6hv5-3cvf](https://osv.dev/vulnerability/GHSA-wjgm-6hv5-3cvf) · CVE-2026-19032 | jackson-databind | MODERATE | 3.1.6, 3.2.2, 2.18.10, 2.21.6, 2.22.2 | El DTO no enlaza java.nio.file.Path desde el JSON. Los archivos se reciben mediante MultipartFile y nombres/campos de aplicación. |
| 22 | [GHSA-wv8q-qhhj-9h54](https://osv.dev/vulnerability/GHSA-wv8q-qhhj-9h54) · CVE-2026-91776 | jackson-databind | HIGH | 2.18.11, 2.21.7, 2.22.3, 3.1.7, 3.2.3 | El contrato no habilita @JsonTypeInfo con identificadores por nombre y tipo por defecto. |
| 23 | [GHSA-j288-q9x7-2f5v](https://osv.dev/vulnerability/GHSA-j288-q9x7-2f5v) · CVE-2025-48924 | commons-lang3 | MODERATE | 3.18.0 | El código no entrega nombres de clase elegidos por el consumidor a ClassUtils. El SDK usa estrategias y parámetros de tipos definidos. |
| 24 | [GHSA-7r82-7xv7-xcpj](https://osv.dev/vulnerability/GHSA-7r82-7xv7-xcpj) · CVE-2020-13956 | httpclient | MODERATE | 4.5.13, 5.0.3 | El backend entrega bytes al host fijo del SDK Cloudinary. No usa URI de destino de cliente en ese transporte ni activa fetch de URL externa. |
| 25 | [GHSA-qv9r-c865-cp47](https://osv.dev/vulnerability/GHSA-qv9r-c865-cp47) · CVE-2026-49844 | log4j-api | MODERATE | 2.25.5, 2.26.1 | No se observó serialización MapMessage.asJson en la configuración de logging. El backend usa la canalización SLF4J/Logback estándar. |
| 26 | [GHSA-23hv-mwm6-g8jf](https://osv.dev/vulnerability/GHSA-23hv-mwm6-g8jf) · CVE-2025-55668 | tomcat-embed-core | MODERATE | 11.0.8, 10.1.42, 9.0.106 | No se configura RewriteValve ni las reglas de reescritura del contenedor requeridas por el aviso. |
| 27 | [GHSA-25xr-qj8w-c4vf](https://osv.dev/vulnerability/GHSA-25xr-qj8w-c4vf) · CVE-2025-53506 | tomcat-embed-core | HIGH | 11.0.9, 10.1.43, 9.0.107 | HTTP/2 no está habilitado en la configuración backend inspeccionada. HTTP/2 del navegador o del edge no implica HTTP/2 hasta el conector. |
| 28 | [GHSA-27hp-xhwr-wr2m](https://osv.dev/vulnerability/GHSA-27hp-xhwr-wr2m) · CVE-2024-56337 | tomcat-embed-core | HIGH | 11.0.2, 10.1.34, 9.0.98 | DefaultServlet conserva solo lectura. La carga de imágenes ocurre en un controlador MVC y el runtime es Linux. No se publica JSP ni se usa persistencia de sesión contenedor. |
| 30 | [GHSA-42wg-hm62-jcwg](https://osv.dev/vulnerability/GHSA-42wg-hm62-jcwg) · CVE-2025-49124 | tomcat-embed-core | MODERATE | 11.0.8, 10.1.42, 9.0.106 | El artefacto se ejecuta Linux/amd64 con Tomcat embebido. No se usa instalador Windows de Tomcat. |
| 32 | [GHSA-5j33-cvvr-w245](https://osv.dev/vulnerability/GHSA-5j33-cvvr-w245) · CVE-2024-50379 | tomcat-embed-core | HIGH | 11.0.2, 10.1.34, 9.0.98 | DefaultServlet conserva solo lectura. La carga de imágenes ocurre en un controlador MVC y el runtime es Linux. No se publica JSP ni se usa persistencia de sesión contenedor. |
| 33 | [GHSA-5m62-pw8w-7w9f](https://osv.dev/vulnerability/GHSA-5m62-pw8w-7w9f) · CVE-2026-43515 | tomcat-embed-core | CRITICAL | 9.0.118, 10.1.55, 11.0.22 | Los roles y rutas se aplican en Spring Security. No se observó configuración de constraints de web.xml para métodos o subrutas del DefaultServlet. |
| 34 | [GHSA-5mp6-jrq3-r938](https://osv.dev/vulnerability/GHSA-5mp6-jrq3-r938) · CVE-2026-43513 | tomcat-embed-core | HIGH | 9.0.118, 10.1.55, 11.0.22 | No se usa LockOutRealm, JNDIRealm, DIGEST ni FORM del contenedor. La aplicación autentica con su servicio y Bearer. |
| 35 | [GHSA-5v3h-fjv2-54fg](https://osv.dev/vulnerability/GHSA-5v3h-fjv2-54fg) · CVE-2026-55956 | tomcat-embed-core | MODERATE | 11.0.23, 10.1.56, 9.0.119 | Los roles y rutas se aplican en Spring Security. No se observó configuración de constraints de web.xml para métodos o subrutas del DefaultServlet. |
| 36 | [GHSA-7895-gffq-w6jq](https://osv.dev/vulnerability/GHSA-7895-gffq-w6jq) · CVE-2026-55957 | tomcat-embed-core | HIGH | 11.0.5, 10.1.37, 9.0.101 | No se usa LockOutRealm, JNDIRealm, DIGEST ni FORM del contenedor. La aplicación autentica con su servicio y Bearer. |
| 37 | [GHSA-83qj-6fr2-vhqg](https://osv.dev/vulnerability/GHSA-83qj-6fr2-vhqg) · CVE-2025-24813 | tomcat-embed-core | CRITICAL | 11.0.3, 10.1.35, 9.0.99 | DefaultServlet conserva solo lectura. La carga de imágenes ocurre en un controlador MVC y el runtime es Linux. No se publica JSP ni se usa persistencia de sesión contenedor. |
| 38 | [GHSA-9m3c-qcxr-9x87](https://osv.dev/vulnerability/GHSA-9m3c-qcxr-9x87) · CVE-2026-25854 | tomcat-embed-core | MODERATE | 9.0.116, 10.1.53, 11.0.20 | No está habilitado LoadBalancerDrainingValve entre el conector y la API. |
| 39 | [GHSA-9m89-8frq-c98c](https://osv.dev/vulnerability/GHSA-9m89-8frq-c98c) · CVE-2026-43514 | tomcat-embed-core | LOW | 9.0.118, 10.1.55, 11.0.22 | No se observó conector AJP ni secreto AJP. |
| 40 | [GHSA-9xv2-5v5q-p794](https://osv.dev/vulnerability/GHSA-9xv2-5v5q-p794) · CVE-2026-65905 | tomcat-embed-core | CRITICAL | 11.0.25, 10.1.58, 9.0.121 | No se usa LockOutRealm, JNDIRealm, DIGEST ni FORM del contenedor. La aplicación autentica con su servicio y Bearer. |
| 41 | [GHSA-ff77-26x5-69cr](https://osv.dev/vulnerability/GHSA-ff77-26x5-69cr) · CVE-2025-31651 | tomcat-embed-core | LOW | 9.0.104, 10.1.40, 11.0.6 | No se configura RewriteValve ni las reglas de reescritura del contenedor requeridas por el aviso. |
| 42 | [GHSA-fpj8-gq4v-p354](https://osv.dev/vulnerability/GHSA-fpj8-gq4v-p354) · CVE-2025-66614 | tomcat-embed-core | MODERATE | 11.0.15, 10.1.50, 9.0.113 | No hay autenticación de clientes por certificado, ni virtual hosts TLS en Tomcat. VERIFY_IDENTITY pertenece al JDBC saliente. |
| 43 | [GHSA-fv25-8xcx-gqjc](https://osv.dev/vulnerability/GHSA-fv25-8xcx-gqjc) · CVE-2026-42498 | tomcat-embed-core | HIGH | 9.0.118, 10.1.55, 11.0.22 | No están habilitados WebSocket de aplicación ni su canal de autenticación. Tener el JAR de Tomcat WebSocket no abre ese canal. |
| 44 | [GHSA-gcx9-497g-6cp6](https://osv.dev/vulnerability/GHSA-gcx9-497g-6cp6) · CVE-2026-65182 | tomcat-embed-core | CRITICAL | 11.0.25, 10.1.58, 9.0.121 | Los roles y rutas se aplican en Spring Security. No se observó configuración de constraints de web.xml para métodos o subrutas del DefaultServlet. |
| 45 | [GHSA-gqp3-2cvr-x8m3](https://osv.dev/vulnerability/GHSA-gqp3-2cvr-x8m3) · CVE-2025-48989 | tomcat-embed-core | HIGH | 11.0.10, 10.1.44, 9.0.108 | HTTP/2 no está habilitado en la configuración backend inspeccionada. HTTP/2 del navegador o del edge no implica HTTP/2 hasta el conector. |
| 46 | [GHSA-gx5v-xp9w-j4cg](https://osv.dev/vulnerability/GHSA-gx5v-xp9w-j4cg) · CVE-2026-41284 | tomcat-embed-core | HIGH | 9.0.118, 10.1.55, 11.0.22 | No se registra WebdavServlet ni operaciones WebDAV abiertas. |
| 47 | [GHSA-h2fw-rfh5-95r3](https://osv.dev/vulnerability/GHSA-h2fw-rfh5-95r3) · CVE-2025-46701 | tomcat-embed-core | LOW | 9.0.105, 10.1.41, 11.0.7 | No se usa CGIServlet. El build actual ejecuta un JAR en Linux. |
| 49 | [GHSA-h3x4-894j-xpx5](https://osv.dev/vulnerability/GHSA-h3x4-894j-xpx5) · CVE-2026-68525 | tomcat-embed-core | CRITICAL | 11.0.25, 10.1.58, 9.0.121 | No se usa LockOutRealm, JNDIRealm, DIGEST ni FORM del contenedor. La aplicación autentica con su servicio y Bearer. |
| 50 | [GHSA-h6fc-48rj-7qqh](https://osv.dev/vulnerability/GHSA-h6fc-48rj-7qqh) · CVE-2026-43512 | tomcat-embed-core | CRITICAL | 9.0.118, 10.1.55, 11.0.22 | No se usa LockOutRealm, JNDIRealm, DIGEST ni FORM del contenedor. La aplicación autentica con su servicio y Bearer. |
| 51 | [GHSA-h792-v28v-ppgr](https://osv.dev/vulnerability/GHSA-h792-v28v-ppgr) · CVE-2026-53404 | tomcat-embed-core | HIGH | 11.0.23, 10.1.56, 9.0.119 | No se configura RewriteValve ni las reglas de reescritura del contenedor requeridas por el aviso. |
| 53 | [GHSA-mgp5-rv84-w37q](https://osv.dev/vulnerability/GHSA-mgp5-rv84-w37q) · CVE-2026-24734 | tomcat-embed-core | HIGH | 11.0.18, 10.1.52, 9.0.115 | TLS HTTP termina en el edge previsto. No se configuró Tomcat Native/FFM con OCSP. El JDBC usa JSSE y CA propia. |
| 54 | [GHSA-mqg3-r7h5-24x4](https://osv.dev/vulnerability/GHSA-mqg3-r7h5-24x4) · CVE-2026-55276 | tomcat-embed-core | CRITICAL | 11.0.23, 10.1.56, 9.0.119 | Los roles y rutas se aplican en Spring Security. No se observó configuración de constraints de web.xml para métodos o subrutas del DefaultServlet. |
| 55 | [GHSA-qvf5-hvjx-wm27](https://osv.dev/vulnerability/GHSA-qvf5-hvjx-wm27) · CVE-2024-52317 | tomcat-embed-core | MODERATE | 9.0.96, 10.1.31, 11.0.0 | HTTP/2 no está habilitado en la configuración backend inspeccionada. HTTP/2 del navegador o del edge no implica HTTP/2 hasta el conector. |
| 56 | [GHSA-r29c-68gh-xp6x](https://osv.dev/vulnerability/GHSA-r29c-68gh-xp6x) · CVE-2026-41293 | tomcat-embed-core | CRITICAL | 9.0.118, 10.1.55, 11.0.22 | HTTP/2 no está habilitado en la configuración backend inspeccionada. HTTP/2 del navegador o del edge no implica HTTP/2 hasta el conector. |
| 57 | [GHSA-rv64-5gf8-9qq8](https://osv.dev/vulnerability/GHSA-rv64-5gf8-9qq8) · CVE-2026-34483 | tomcat-embed-core | HIGH | 9.0.116, 10.1.54, 11.0.21 | No se habilita JsonAccessLogValve en el perfil revisado. |
| 58 | [GHSA-vfww-5hm6-hx2j](https://osv.dev/vulnerability/GHSA-vfww-5hm6-hx2j) · CVE-2025-55754 | tomcat-embed-core | LOW | 11.0.11, 10.1.45, 9.0.109 | El escenario identificado por el proveedor usa consola ANSI Windows de un servidor expuesto. El backend previsto corre en Linux. El desarrollo local carece de exposición de producción. |
| 59 | [GHSA-wc4r-xq3c-5cf3](https://osv.dev/vulnerability/GHSA-wc4r-xq3c-5cf3) · CVE-2025-49125 | tomcat-embed-core | MODERATE | 11.0.8, 10.1.42, 9.0.106 | No se configuran PreResources/PostResources mapeados fuera de la raíz, condición del aviso. |
| 60 | [GHSA-wmwf-9ccg-fff5](https://osv.dev/vulnerability/GHSA-wmwf-9ccg-fff5) · CVE-2025-55752 | tomcat-embed-core | HIGH | 11.0.11, 10.1.45, 9.0.109 | No se configura RewriteValve ni las reglas de reescritura del contenedor requeridas por el aviso. |
| 62 | [GHSA-x4m4-345f-5h5g](https://osv.dev/vulnerability/GHSA-x4m4-345f-5h5g) · CVE-2026-34487 | tomcat-embed-core | HIGH | 9.0.117, 10.1.54, 11.0.21 | No hay clustering Tomcat ni servicio de membresía en Kubernetes en esta arquitectura. |
| 63 | [GHSA-4gc7-5j7h-4qph](https://osv.dev/vulnerability/GHSA-4gc7-5j7h-4qph) · CVE-2024-38820 | spring-context, spring-web | MODERATE | 6.1.14 | La revisión no encontró configuraciones de disallowedFields en un DataBinder como control de privilegios. La entrada principal es JSON con DTO, y los roles y demás campos sensibles se fijan en lógica del backend. |
| 64 | [GHSA-4wp7-92pw-q264](https://osv.dev/vulnerability/GHSA-4wp7-92pw-q264) · CVE-2025-22233 | spring-context | LOW | 6.2.7, 6.1.20 | La revisión no encontró configuraciones de disallowedFields en un DataBinder como control de privilegios. La entrada principal es JSON con DTO, y los roles y demás campos sensibles se fijan en lógica del backend. |
| 65 | [GHSA-659m-px2c-25wj](https://osv.dev/vulnerability/GHSA-659m-px2c-25wj) · CVE-2026-41848 | spring-core | LOW | 7.0.8, 6.2.19 | Los patrones de autorización son estáticos. El usuario aporta rutas y valores, no patrones para AntPathMatcher. |
| 66 | [GHSA-jmp9-x22r-554x](https://osv.dev/vulnerability/GHSA-jmp9-x22r-554x) · CVE-2025-41249 | spring-core | HIGH | 6.2.11 | No se usa seguridad a nivel de método sobre supertipos genéricos. Los permisos HTTP se declaran en SecurityFilterChain. |
| 67 | [GHSA-9f52-rjqv-25qv](https://osv.dev/vulnerability/GHSA-9f52-rjqv-25qv) · CVE-2026-41852 | spring-expression | LOW | 7.0.8, 6.2.19 | No se evalúa SpEL de usuario. Los placeholders y predicados del backend son propios. |
| 68 | [GHSA-r5w3-xv2f-j59q](https://osv.dev/vulnerability/GHSA-r5w3-xv2f-j59q) · CVE-2026-41850 | spring-expression | HIGH | 7.0.8, 6.2.19 | No se evalúa SpEL de usuario. Los placeholders y predicados del backend son propios. |
| 69 | [GHSA-wxpp-56q6-5pcg](https://osv.dev/vulnerability/GHSA-wxpp-56q6-5pcg) · CVE-2026-41851 | spring-expression | MODERATE | 7.0.8, 6.2.19 | No se evalúa SpEL de usuario. Los placeholders y predicados del backend son propios. |
| 70 | [GHSA-6r3c-xf4w-jxjm](https://osv.dev/vulnerability/GHSA-6r3c-xf4w-jxjm) · CVE-2025-41234 | spring-web | MODERATE | 6.2.8, 6.1.21 | No se construye un Content-Disposition de descarga con nombre de usuario y charset en las rutas API auditadas. |
| 71 | [GHSA-3chg-m5w7-qfv5](https://osv.dev/vulnerability/GHSA-3chg-m5w7-qfv5) · CVE-2026-41845 | spring-webmvc | HIGH | 7.0.8, 6.2.19 | El backend es JSON. No se observó JavaScriptUtils para vistas, JSP Form Tags ni templates renderizados que cumplan la condición. |
| 72 | [GHSA-4773-3jfm-qmx3](https://osv.dev/vulnerability/GHSA-4773-3jfm-qmx3) · CVE-2026-22737 | spring-webmvc | MODERATE | 7.0.6, 6.2.17 | El backend es JSON. No se observó JavaScriptUtils para vistas, JSP Form Tags ni templates renderizados que cumplan la condición. |
| 73 | [GHSA-6hcq-hmm3-jj3c](https://osv.dev/vulnerability/GHSA-6hcq-hmm3-jj3c) · CVE-2026-22735 | spring-webmvc | LOW | 7.0.6, 6.2.17 | No hay un flujo Server-Sent Events en la API inspeccionada. |
| 74 | [GHSA-6p4f-wcwh-5vvm](https://osv.dev/vulnerability/GHSA-6p4f-wcwh-5vvm) · CVE-2026-22745 | spring-webmvc | MODERATE | 7.0.7, 6.2.18 | El backend de producción es Linux y no sirve estáticos desde el filesystem. Flutter Web se aloja como estático aparte. |
| 75 | [GHSA-72pg-x5f8-j25j](https://osv.dev/vulnerability/GHSA-72pg-x5f8-j25j) · CVE-2026-41843 | spring-webmvc | MODERATE | 7.0.8, 6.2.19 | No se configuraron resources versionados/encoded ni cadena de caché de recursos públicos en la API. La política deniega rutas no declaradas. |
| 76 | [GHSA-957g-f97v-vppc](https://osv.dev/vulnerability/GHSA-957g-f97v-vppc) · CVE-2026-41846 | spring-webmvc | MODERATE | 7.0.8, 6.2.19 | El backend es JSON. No se observó JavaScriptUtils para vistas, JSP Form Tags ni templates renderizados que cumplan la condición. |
| 78 | [GHSA-g5vr-rgqm-vf78](https://osv.dev/vulnerability/GHSA-g5vr-rgqm-vf78) · CVE-2024-38819 | spring-webmvc | HIGH | 6.1.14 | No hay RouterFunctions sirviendo FileSystemResource. No se usa un contenedor no conforme en el perfil previsto y no se publican recursos del filesystem. |
| 79 | [GHSA-h3qp-gqrc-q736](https://osv.dev/vulnerability/GHSA-h3qp-gqrc-q736) · CVE-2026-41844 | spring-webmvc | MODERATE | 7.0.8, 6.2.19 | No se configura un mapeo comodín que renderice una vista de nombre implícito, ni XsltView. Los controladores devuelven datos. |
| 80 | [GHSA-mq64-j8f9-9gcj](https://osv.dev/vulnerability/GHSA-mq64-j8f9-9gcj) · CVE-2026-41841 | spring-webmvc | MODERATE | 7.0.8, 6.2.19 | No se configuraron resources versionados/encoded ni cadena de caché de recursos públicos en la API. La política deniega rutas no declaradas. |
| 81 | [GHSA-pc63-qcmh-9cmg](https://osv.dev/vulnerability/GHSA-pc63-qcmh-9cmg) · CVE-2026-47884 | spring-webmvc | CRITICAL | 7.0.9 | No se configura un mapeo comodín que renderice una vista de nombre implícito, ni XsltView. Los controladores devuelven datos. |
| 82 | [GHSA-r936-gwx5-v52f](https://osv.dev/vulnerability/GHSA-r936-gwx5-v52f) · CVE-2025-41242 | spring-webmvc | MODERATE | 6.2.10 | No hay RouterFunctions sirviendo FileSystemResource. No se usa un contenedor no conforme en el perfil previsto y no se publican recursos del filesystem. |
| 83 | [GHSA-wg35-8jpf-2xv3](https://osv.dev/vulnerability/GHSA-wg35-8jpf-2xv3) · CVE-2026-22741 | spring-webmvc | LOW | 7.0.7, 6.2.18 | No se configuraron resources versionados/encoded ni cadena de caché de recursos públicos en la API. La política deniega rutas no declaradas. |
| 84 | [GHSA-x23c-287f-qqv5](https://osv.dev/vulnerability/GHSA-x23c-287f-qqv5) · CVE-2026-41842 | spring-webmvc | HIGH | 7.0.8, 6.2.19 | No se configuraron resources versionados/encoded ni cadena de caché de recursos públicos en la API. La política deniega rutas no declaradas. |
| 85 | [GHSA-rc42-6c7j-7h5r](https://osv.dev/vulnerability/GHSA-rc42-6c7j-7h5r) · CVE-2025-22235 | spring-boot | HIGH | 3.3.11, 3.4.5 | El health es un controlador propio. La cadena no usa EndpointRequest.to ni hay una ruta /null autorizada. |
| 86 | [GHSA-wwpq-f5c3-7hvx](https://osv.dev/vulnerability/GHSA-wwpq-f5c3-7hvx) · CVE-2026-40973 | spring-boot | HIGH | 4.0.6, 3.5.14 | El escenario principal requiere acceso local a temporales y sesiones servlet persistentes. Se usa Docker con proceso no root, JWT stateless y sin persistencia de sesión del contenedor. |
| 87 | [GHSA-ggg2-9786-hwc8](https://osv.dev/vulnerability/GHSA-ggg2-9786-hwc8) · CVE-2026-41001 | spring-boot-autoconfigure | MODERATE | 4.0.7, 3.5.15 | Artemis no forma parte del classpath efectivo ni de la configuración. |
| 88 | [GHSA-5m4m-73w9-8433](https://osv.dev/vulnerability/GHSA-5m4m-73w9-8433) · CVE-2026-41721 | spring-data-commons | MODERATE | 4.0.6, 3.5.12 | Las proyecciones consultadas por JPA son internas. No se enlazan @ProjectedPayload en los controladores. |
| 89 | [GHSA-5vpf-xvv7-c8vh](https://osv.dev/vulnerability/GHSA-5vpf-xvv7-c8vh) · CVE-2026-41711 | spring-data-commons | MODERATE | 4.0.6, 3.5.12 | No se encontraron argumentos Sort/Pageable de usuario ni llamadas a Sort parsing desde las rutas. |
| 91 | [GHSA-q3v6-hm2v-pw99](https://osv.dev/vulnerability/GHSA-q3v6-hm2v-pw99) · CVE-2024-38827 | spring-security-core | MODERATE | 5.7.14, 5.8.16, 6.0.14, 6.1.12, 6.2.8, 6.3.5 | Autoridades de la API construidas desde roles explícitos con Locale.ROOT. No hay conversión dependiente de locale identificada en esas decisiones. |
| 92 | [GHSA-vxf7-qj7q-83fh](https://osv.dev/vulnerability/GHSA-vxf7-qj7q-83fh) · CVE-2026-22746 | spring-security-core | LOW | 6.5.10, 7.0.5 | La verificación de cuenta se hace en AuthService con JWT y consultas propias. La cadena no usa DaoAuthenticationProvider para las rutas publicadas. |
| 94 | [GHSA-293q-567p-wmwq](https://osv.dev/vulnerability/GHSA-293q-567p-wmwq) · CVE-2026-47838 | spring-security-web | MODERATE | 6.5.11 | No hay autenticación de clientes por certificado, ni virtual hosts TLS en Tomcat. VERIFY_IDENTITY pertenece al JDBC saliente. |
| 95 | [GHSA-c4q5-6c82-3qpw](https://osv.dev/vulnerability/GHSA-c4q5-6c82-3qpw) · CVE-2024-38821 | spring-security-web | CRITICAL | 5.7.13, 5.8.15, 6.2.7, 6.0.13, 6.1.11, 6.3.4 | El servidor usa Spring MVC Servlet. Spring WebFlux no se resolvió en runtime. |
| 97 | [GHSA-x2r2-rvhq-2mqv](https://osv.dev/vulnerability/GHSA-x2r2-rvhq-2mqv) · CVE-2026-41706 | spring-security-web | MODERATE | 7.0.6, 6.5.11 | Sesiones stateless y login REST propio. No se configura CookieRequestCache ni redirección de login por cookie. |

## Inventario de runtime V3.5-C

Coordenadas del grafo desde el informe V3.5-C, incluidas plataformas y metadatos de resolución. El recuento histórico de bibliotecas empaquetadas fue 76. El grafo no identifica por sí solo los archivos del artefacto ni los paquetes del sistema operativo. Auditoría futura con tres inventarios independientes: grafo de Gradle, bibliotecas de BOOT-INF/lib y paquetes de la imagen sin contar dos veces una misma vulnerabilidad Maven.

| Coordenada Maven | Versión efectiva | Relación |
| --- | --- | --- |
| `ch.qos.logback:logback-classic` | 1.5.8 | transitiva |
| `ch.qos.logback:logback-core` | 1.5.8 | transitiva |
| `com.cloudinary:cloudinary-core` | 1.38.0 | transitiva |
| `com.cloudinary:cloudinary-http44` | 1.38.0 | directa |
| `com.fasterxml:classmate` | 1.7.0 | transitiva |
| `com.fasterxml.jackson.core:jackson-annotations` | 2.17.2 | transitiva |
| `com.fasterxml.jackson.core:jackson-core` | 2.17.2 | transitiva |
| `com.fasterxml.jackson.core:jackson-databind` | 2.17.2 | transitiva |
| `com.fasterxml.jackson.datatype:jackson-datatype-jdk8` | 2.17.2 | transitiva |
| `com.fasterxml.jackson.datatype:jackson-datatype-jsr310` | 2.17.2 | transitiva |
| `com.fasterxml.jackson.module:jackson-module-parameter-names` | 2.17.2 | transitiva |
| `com.mysql:mysql-connector-j` | 8.3.0 | directa |
| `com.sun.istack:istack-commons-runtime` | 4.1.2 | transitiva |
| `com.zaxxer:HikariCP` | 5.1.0 | transitiva |
| `commons-codec:commons-codec` | 1.16.1 | transitiva |
| `io.jsonwebtoken:jjwt-api` | 0.11.5 | directa |
| `io.jsonwebtoken:jjwt-impl` | 0.11.5 | directa |
| `io.jsonwebtoken:jjwt-jackson` | 0.11.5 | directa |
| `io.micrometer:micrometer-commons` | 1.13.4 | transitiva |
| `io.micrometer:micrometer-observation` | 1.13.4 | transitiva |
| `io.smallrye:jandex` | 3.1.2 | transitiva |
| `jakarta.activation:jakarta.activation-api` | 2.1.3 | transitiva |
| `jakarta.annotation:jakarta.annotation-api` | 2.1.1 | transitiva |
| `jakarta.inject:jakarta.inject-api` | 2.0.1 | transitiva |
| `jakarta.persistence:jakarta.persistence-api` | 3.1.0 | transitiva |
| `jakarta.transaction:jakarta.transaction-api` | 2.0.1 | transitiva |
| `jakarta.validation:jakarta.validation-api` | 3.0.2 | transitiva |
| `jakarta.xml.bind:jakarta.xml.bind-api` | 4.0.2 | transitiva |
| `net.bytebuddy:byte-buddy` | 1.14.19 | transitiva |
| `org.antlr:antlr4-runtime` | 4.13.0 | transitiva |
| `org.apache.commons:commons-lang3` | 3.14.0 | transitiva |
| `org.apache.httpcomponents:httpclient` | 4.4 | transitiva |
| `org.apache.httpcomponents:httpcore` | 4.4.16 | transitiva |
| `org.apache.httpcomponents:httpmime` | 4.4 | transitiva |
| `org.apache.logging.log4j:log4j-api` | 2.23.1 | transitiva |
| `org.apache.logging.log4j:log4j-to-slf4j` | 2.23.1 | transitiva |
| `org.apache.tomcat.embed:tomcat-embed-core` | 10.1.30 | transitiva |
| `org.apache.tomcat.embed:tomcat-embed-el` | 10.1.30 | transitiva |
| `org.apache.tomcat.embed:tomcat-embed-websocket` | 10.1.30 | transitiva |
| `org.aspectj:aspectjweaver` | 1.9.22.1 | transitiva |
| `org.eclipse.angus:angus-activation` | 2.0.2 | transitiva |
| `org.eclipse.angus:jakarta.mail` | 2.0.3 | transitiva |
| `org.flywaydb:flyway-core` | 11.15.0 | directa |
| `org.flywaydb:flyway-mysql` | 11.15.0 | directa |
| `org.glassfish.jaxb:jaxb-core` | 4.0.5 | transitiva |
| `org.glassfish.jaxb:jaxb-runtime` | 4.0.5 | transitiva |
| `org.glassfish.jaxb:txw2` | 4.0.5 | transitiva |
| `org.hibernate.common:hibernate-commons-annotations` | 6.0.6.Final | transitiva |
| `org.hibernate.orm:hibernate-core` | 6.5.3.Final | transitiva |
| `org.hibernate.validator:hibernate-validator` | 8.0.1.Final | transitiva |
| `org.jboss.logging:jboss-logging` | 3.5.3.Final | transitiva |
| `org.slf4j:jul-to-slf4j` | 2.0.16 | transitiva |
| `org.slf4j:slf4j-api` | 2.0.16 | transitiva |
| `org.springframework:spring-aop` | 6.1.13 | transitiva |
| `org.springframework:spring-aspects` | 6.1.13 | transitiva |
| `org.springframework:spring-beans` | 6.1.13 | transitiva |
| `org.springframework:spring-context` | 6.1.13 | transitiva |
| `org.springframework:spring-context-support` | 6.1.13 | transitiva |
| `org.springframework:spring-core` | 6.1.13 | transitiva |
| `org.springframework:spring-expression` | 6.1.13 | transitiva |
| `org.springframework:spring-jcl` | 6.1.13 | transitiva |
| `org.springframework:spring-jdbc` | 6.1.13 | transitiva |
| `org.springframework:spring-orm` | 6.1.13 | transitiva |
| `org.springframework:spring-tx` | 6.1.13 | transitiva |
| `org.springframework:spring-web` | 6.1.13 | transitiva |
| `org.springframework:spring-webmvc` | 6.1.13 | transitiva |
| `org.springframework.boot:spring-boot` | 3.3.4 | transitiva |
| `org.springframework.boot:spring-boot-autoconfigure` | 3.3.4 | transitiva |
| `org.springframework.boot:spring-boot-starter` | 3.3.4 | transitiva |
| `org.springframework.boot:spring-boot-starter-aop` | 3.3.4 | transitiva |
| `org.springframework.boot:spring-boot-starter-data-jpa` | 3.3.4 | directa |
| `org.springframework.boot:spring-boot-starter-jdbc` | 3.3.4 | transitiva |
| `org.springframework.boot:spring-boot-starter-json` | 3.3.4 | transitiva |
| `org.springframework.boot:spring-boot-starter-logging` | 3.3.4 | transitiva |
| `org.springframework.boot:spring-boot-starter-mail` | 3.3.4 | directa |
| `org.springframework.boot:spring-boot-starter-security` | 3.3.4 | directa |
| `org.springframework.boot:spring-boot-starter-tomcat` | 3.3.4 | transitiva |
| `org.springframework.boot:spring-boot-starter-validation` | 3.3.4 | directa |
| `org.springframework.boot:spring-boot-starter-web` | 3.3.4 | directa |
| `org.springframework.data:spring-data-commons` | 3.3.4 | transitiva |
| `org.springframework.data:spring-data-jpa` | 3.3.4 | transitiva |
| `org.springframework.security:spring-security-config` | 6.3.3 | transitiva |
| `org.springframework.security:spring-security-core` | 6.3.3 | transitiva |
| `org.springframework.security:spring-security-crypto` | 6.3.3 | transitiva |
| `org.springframework.security:spring-security-web` | 6.3.3 | transitiva |
| `org.yaml:snakeyaml` | 2.2 | transitiva |

## Avisos adicionales evaluados durante V3.6-A

| Aviso | Clasificación y evidencia |
| --- | --- |
| CVE-2026-110879 | No aplicable al flujo JSON inventariado. Requiere tipos polimórficos no confiables con el validador y la regla descritos por el proveedor. Aun así, alinear databind a una versión corregida y probar el rechazo de tipos de entrada ajenos. [Proveedor](https://github.com/FasterXML/jackson-databind/security/advisories/GHSA-m8xf-2cr7-77ph) · [NVD](https://nvd.nist.gov/vuln/detail/CVE-2026-110879). |
| CVE-2026-59414 | Spring Boot 3.3.4 está en el intervalo del aviso. El código observado usa coincidencias explícitas de rutas y denegación por defecto. La condición descrita por Spring requiere los matchers Servlet EndpointRequest o PathRequest. Revisar si aparecen al migrar. [Spring](https://spring.io/security/cve-2026-59414/). |
| CVE-2026-133325 | Riesgo condicionado de Tomcat 11.0.29, candidato a laboratorio. Requiere activar TLS-PSK para tráfico de clúster con TLS 1.3. El proyecto usa Tomcat embebido sin ese clúster. Verificar el contenedor efectivo y actualizar cuando esté publicado el parche de esa línea. Esta condición no afecta ni justifica cambiar el TLS de JDBC. [Apache Tomcat 11](https://tomcat.apache.org/security-11.html). |
| CVE-2025-15467 | Pendiente de comprobación del proveedor. El aviso upstream de MySQL incluye 8.4.11 en el rango 8.4.0–8.4.12 para el componente OpenSSL. Se desconoce la compilación y el estado de backports de Aiven. [Oracle MySQL](https://dev.mysql.com/community/security/advisories/2026-10-20/). |

Las comprobaciones públicas de artefactos candidatos son parciales y están sujetas al desfase entre avisos, publicación Maven y bases de datos. Una respuesta vacía de OSV no acredita ausencia de vulnerabilidades. El informe principal documenta las condiciones para una auditoría SCA sobre el runtime efectivamente resuelto y la imagen construida.
