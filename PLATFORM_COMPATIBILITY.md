# Compatibilidad de SavorSync Web y Mobile

Diagnóstico estático de `8a9101e2b627e609f359f92189c1cf11f85810c8` y de los cambios locales presentes al iniciar la remediación. Los resultados de ejecución se registran en [TEST_REPORT.md](TEST_REPORT.md). Las restricciones de acceso por plataforma requieren confirmación con los requisitos aprobados.

**Actualización P0.1.** Flutter Web y Android comparten la contención de Google Sign-In. El botón queda deshabilitado y la llamada falla sin usar una contraseña compartida. Los resultados de pruebas y los límites de la validación figuran en [TEST_REPORT.md](TEST_REPORT.md).

## Arquitectura y configuración

| Elemento | Web | Android | iOS si se confirma el alcance |
| --- | --- | --- | --- |
| API | El mismo cliente Dio apunta a la URL HTTPS de Render e identifica la plataforma con `X-Platform: web`. Verificar OPTIONS y orígenes autorizados desde Vercel. | El cliente usa la misma URL y envía `X-Platform: mobile`. El manifiesto de producción declara Internet. Verificar TLS, inicio en frío y expiración. | Comparte cliente y encabezado móvil. Verificar TLS y requisitos de red del dispositivo. |
| Sesión | Flutter restaura la identidad mediante `GET /auth/me`. Un 401 invalida el token rechazado y un fallo temporal habilita reintento. | Usa el mismo flujo. El cierre local indica cuándo el servidor no confirmó la revocación. Verificar reapertura y revocación en dispositivo. | Comparte la implementación. Validar en iOS si se aprueba su alcance. |
| Google | La plantilla web carece de configuración de cliente OAuth. El flujo auditado usaba una contraseña compartida para acceder a SavorSync y carecía de validación de identidad en la API. | Está aplicado Google Services. El archivo de configuración incluye clientes OAuth de Android y Web. Quedan por verificar las huellas SHA, las audiencias permitidas y la emisión del JWT propio. La configuración de release firma con la clave de depuración. | Faltan el esquema de retorno de OAuth y su configuración en `Info.plist`. |
| Imágenes | La aplicación lee `XFile` como bytes. Validar selector, multipart, visualización y acceso al CDN desde el navegador. | El manifiesto declara cámara. Las publicaciones ofrecen cámara y galería. Validar ambos orígenes y la visualización luego de reabrir la aplicación. | El proyecto Runner no declara las descripciones de uso de cámara o fotos en `Info.plist`. |
| Geolocalización | Usa Geolocator. Verificar permiso en origen HTTPS y comunicar el resultado de un rechazo. | Declara ubicación precisa y aproximada. El mapa evita solicitar de nuevo si el permiso se denegó permanentemente y calcula distancias desde el centro de Bogotá cuando falta la ubicación. | El proyecto Runner no declara una descripción de uso de ubicación en `Info.plist`. |
| Notificaciones | La interfaz usa un stream que emite una sola consulta. La actualización y el borrado masivos tienen prefijo duplicado y silencian errores. | Comparte el servicio y el estado. El manifiesto declara permisos de notificaciones y vibración. La revisión del Dart encontró notificaciones REST dentro de la aplicación. | Comparte la interfaz y servicio REST. Confirmar si el alcance incluye push antes de configurar el servicio. |
| Navegación | Foodie usa navegación inferior. El panel administrativo usa `NavigationRail` con ancho mínimo fijo. Moderación y administración del sistema abren las mismas páginas. | Comparte el shell por roles con Web. Verificar restricciones aprobadas, controles táctiles y tamaño de ventana. | Comparte navegación con Android. Prueba funcional pendiente de alcance y entorno macOS. |

[Cliente Dio](mobile/lib/core/services/api_service.dart#L13) · [Manifiesto Android](mobile/android/app/src/main/AndroidManifest.xml#L1) · [Gradle Android](mobile/android/app/build.gradle.kts#L30) · [Info.plist](mobile/ios/Runner/Info.plist) · [Plantilla Web](mobile/web/index.html) · [Navegación por roles](mobile/lib/screens/shell/role_based_shell.dart#L43)

El manifiesto web referencia recursos con `Icon-192.png` y `Icon-512.png`. Los archivos localizados tienen prefijo `icon` en minúscula. Hay que contrastar las rutas en un servidor con nombres sensibles a mayúsculas. El proyecto incluye también empaque Linux y macOS. Su existencia no confirma un alcance de pruebas para esas plataformas. En Android se usa AGP 8.9.1, Kotlin 2.1.0, Gradle 8.14.7, compileSdk 36 y Java 17 como objetivo de compilación. `gradle.properties` fija una ruta local a JDK 21 de Windows y desactiva la comprobación de metadatos AAR, condiciones que deben contrastarse en CI y otros equipos. El archivo bloqueado de dependencias requiere Dart 3.11 y Flutter 3.41, frente a Dart 3.5 y Flutter 3.27 declarados en el manifiesto de dependencias.

[Manifiesto Web](mobile/web/manifest.json) · [Gradle settings](mobile/android/settings.gradle.kts#L20) · [pubspec.yaml](mobile/pubspec.yaml#L6) · [pubspec.lock](mobile/pubspec.lock#L1080)

## Inspección por carpeta

| Ruta en `mobile` | Resultado de inspección |
| --- | --- |
| `lib/core/constants` | Tema, tipografía y colores compartidos. Preservar el lenguaje visual durante la adaptación. |
| `lib/core/services` | Dio fuerza cierre local ante cualquier 401, aunque la solicitud sea pública. Ocho consultas convierten errores HTTP o de deserialización en listas vacías. El servicio de notificaciones duplica `/api` para operaciones de escritura y captura errores. [API](mobile/lib/core/services/api_service.dart#L36) · [Notificaciones](mobile/lib/core/services/notification_service.dart#L20) |
| `lib/core/utils` | El JWT, el ID y los favoritos se guardan en SharedPreferences. La clave de favoritos es común al dispositivo o al navegador. La rutina de cierre borra el JWT y el ID. [Almacenamiento](mobile/lib/core/utils/token_storage.dart#L3) |
| `lib/models` | Los lectores Dart admiten alias y aplican valores por defecto que ocultan contratos incompletos, incluidas fechas actuales, nombres de reserva y coordenadas de Bogotá. `NotificationModel` acepta `userId` y `cliente_id`. El contrato debe contrastarse con el DTO activo. [Reservas](mobile/lib/models/reservation_model.dart#L28) · [Restaurantes](mobile/lib/models/restaurant_model.dart#L40) · [Notificaciones](mobile/lib/models/notification_model.dart#L22) |
| `lib/providers` | El proveedor autentica con la identidad confirmada por REST y distingue sesión ausente de servicio temporalmente indisponible. El proveedor de tema administra la preferencia visual. [Sesión](mobile/lib/providers/auth_provider.dart) · [Tema](mobile/lib/providers/theme_provider.dart) |
| `lib/screens/admin` | El panel de menú selecciona un restaurante ajeno como respaldo y edita la colección en memoria. El perfil del establecimiento toma el primer resultado y guarda con POST. Analítica también puede tomar el primer establecimiento. La bandeja de moderación muestra un estado vacío fijo. Los formularios de moderador usan registro público y ese método persiste la nueva sesión. [Menú](mobile/lib/screens/admin/menu_management_screen.dart#L41) · [Establecimiento](mobile/lib/screens/admin/restaurant_admin_dashboard.dart#L52) · [Analítica](mobile/lib/screens/admin/analytics_dashboard.dart#L27) · [Moderación](mobile/lib/screens/admin/moderation_screen.dart#L129) · [Gobierno](mobile/lib/screens/admin/user_governance_screen.dart#L178) |
| `lib/screens/auth` | El registro conserva la selección de rol en el formulario y acepta cualquier respuesta exitosa. La pantalla de recuperación solicita el correo y termina con un regreso a login. La llamada Dart para enviar código y contraseña existe sin invocación desde la interfaz. [Registro](mobile/lib/screens/auth/register_screen.dart#L70) · [Recuperación](mobile/lib/screens/auth/forgot_password_screen.dart#L86) |
| `lib/screens/home` | Feed y badge se alimentan de REST. La pantalla intenta mostrar errores del feed, pero el servicio devuelve una colección vacía al fallar. [Inicio](mobile/lib/screens/home/home_screen.dart#L41) |
| `lib/screens/map` | Permiso denegado, servicios deshabilitados o excepción pueden dejar la ubicación ausente sin mensaje específico. El mapa obtiene restaurantes mediante `FutureBuilder` y emplea la lista vacía cuando falta el resultado. [Mapa](mobile/lib/screens/map/restaurant_map_screen.dart#L35) |
| `lib/screens/notifications` | Lectura y acciones masivas comparten el servicio. La pantalla muestra confirmación incluso cuando el servicio absorbió la excepción. [Centro](mobile/lib/screens/notifications/notification_center_screen.dart#L70) |
| `lib/screens/posts` | La creación ofrece cámara y galería. Sustituye un error de subida por una foto externa y manda identidad del autor. La pantalla de detalle reutiliza la tarjeta. [Creación](mobile/lib/screens/posts/create_post_screen.dart#L123) · [Detalle](mobile/lib/screens/posts/post_detail_screen.dart) |
| `lib/screens/pqrs` | El formulario manda identidad, correo y nombre del cliente. El historial del usuario y la gestión usan el mismo endpoint. La gestión recoge la respuesta oficial y solo transmite el estado. [Radicados](mobile/lib/screens/pqrs/create_pqrs_screen.dart#L42) · [Respuesta](mobile/lib/screens/admin/pqrs_management_screen.dart#L104) |
| `lib/screens/profile` | Consultar un perfil ajeno intenta cargar las reservas de su titular. Los favoritos parten de la base local. Vincular Google envía `emailVerified` como dato editable. [Perfil](mobile/lib/screens/profile/profile_screen.dart#L53) · [Edición](mobile/lib/screens/profile/edit_profile_screen.dart#L51) |
| `lib/screens/restaurants` | Detalle consulta menú y publicaciones, y modifica favoritos en local. El modal de reservas envía campos duplicados y un teléfono de respaldo, luego delega la notificación al cliente. El ticket consume el modelo Dart de reserva. [Detalle](mobile/lib/screens/restaurants/restaurant_detail_screen.dart#L56) · [Reserva](mobile/lib/screens/restaurants/create_reservation_modal.dart#L45) · [Ticket](mobile/lib/screens/restaurants/reservation_ticket_modal.dart) |
| `lib/screens/search` | Descarga la colección de locales y filtra en memoria. Fallo de comunicación y búsqueda vacía pueden mostrarse igual. [Búsqueda](mobile/lib/screens/search/search_screen.dart#L42) |
| `lib/screens/settings` | El interruptor de notificaciones modifica estado local. La pantalla solicita permiso de ubicación. [Ajustes](mobile/lib/screens/settings/settings_screen.dart#L80) |
| `lib/screens/shell` | Reservas administrativas se abre sin pasar `restaurantId`. El shell combina moderador y administrador del sistema. [Navegación](mobile/lib/screens/shell/role_based_shell.dart#L52) |
| `lib/screens/splash` | La pantalla inicial observa el estado de la restauración y ofrece reintento ante indisponibilidad. [Pantalla inicial](mobile/lib/screens/splash/splash_screen.dart) |
| `lib/services` | Cloudinary intenta primero la subida directa con preset público y luego el backend. [Imágenes](mobile/lib/services/cloudinary_service.dart#L10) |
| `lib/widgets` | Likes y guardados cambian visualmente antes de confirmación. El like no se revierte si falla el servidor y guardar una publicación solo cambia estado local. Comentarios envía autor desde Flutter y borra el borrador antes del resultado. El recomendador clasifica localmente a partir del catálogo REST. [Tarjeta](mobile/lib/widgets/post_card.dart#L49) · [Comentarios](mobile/lib/widgets/comments_modal.dart#L53) · [Recomendador](mobile/lib/widgets/smart_recommendation_modal.dart#L45) |
| `android`, `ios`, `web` | Se revisaron manifiestos, entrada Android, Gradle de la aplicación, plantilla Web y configuración Runner. Los resultados específicos figuran arriba. |
| `test` | Existe una única prueba de inicialización de `SavorSyncApp`. No contiene aserciones de autenticación, contratos, persistencia o navegación. [Prueba](mobile/test/widget_test.dart#L12) |

## Evidencia pendiente

| Validación | Estado |
| --- | --- |
| Flutter Web y APK Android con la misma URL y respuestas JSON | PENDIENTE de pruebas de aplicación y revisión de contratos en [API_CONTRACTS.md](API_CONTRACTS.md). |
| Registro, ciclo de sesión, correo, recuperación y Google | PENDIENTE de entorno controlado con servicios habilitados. La configuración de OAuth y los requisitos de cada rol en web y móvil requieren confirmación del propietario. |
| Cámara, galería, selector web, GPS, operación sin red y navegación táctil | PENDIENTE de ejecución en dispositivo Android y navegador. |
| Publicaciones, reservas, menús, PQRS, perfil, favoritos, notificaciones y persistencia cruzada | PENDIENTE de completar el gate de seguridad y probar contra la misma base de pruebas. |
| Firma Android de distribución | PENDIENTE de clave de release autorizada y huellas de OAuth correspondientes. |
| iOS | PENDIENTE de confirmación de alcance y entorno macOS. |

## Actualización Web y Android V3.1 — 2026-11-25

- El flujo correo/código usa widgets y servicios Flutter compartidos. Registro queda sin sesión hasta confirmación Spring; verificación requiere seis dígitos y navega según rol efectivo devuelto.
- La plataforma usa `kIsWeb` en código compartido. Dio envía `X-Platform: web` o `mobile`; Spring lo guarda como metadato. Roles, identidad y titularidad se verifican con el JWT.
- Se retiraron subidas directas unsigned, configuración Cloudinary hardcodeada y URLs de respaldo falsas. `XFile` se valida por tamaño y se carga al backend como bytes; el backend valida contenido binario y controla el proveedor.
- Google Sign-In permanece deshabilitado. No se agregó Firebase Auth; JWT de Spring continúa como autoridad.
- La revisión es estática. Builds, tests, selector web, cámara y galería se informan por separado en TEST_REPORT.md. CORS no es una barrera para clientes Android.
| Configuración publicada de Aiven, Render, Vercel, Cloudinary y Google | PENDIENTE de acceso autorizado o de evidencias del propietario. |

## Cierre de seguridad multiplataforma V3.2 — 2026-11-25

Flutter mantiene seleccionado y pendiente el tipo de cuenta entre reinicios, y actualiza challenge y expiración al pedir reenvío; al verificar, navega por el rol efectivo devuelto por Spring. El recorrido de restaurante sigue siendo Foodie hasta que apruebe el admin sistema. X-Platform se usa sólo como dato informativo y no impide que el backend aplique permisos a clientes nativos.

La suite Flutter y los builds Web/Android de esta iteración se reportan en P0_V32_AUDIT_HANDOFF.md. No se ejecutaron pruebas físicas de cámara/galería ni E2E de navegador; Cloudinary, correo, CORS en producción y TLS de Aiven dependen de servicios externos y no están verificados.
