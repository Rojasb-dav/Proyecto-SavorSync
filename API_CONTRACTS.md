# Contratos REST de SavorSync

Inventario estático inicial de P0 sobre la rama `fix/savorsync-remediation-v2`, con base `8a9101e2b627e609f359f92189c1cf11f85810c8` y los cambios locales preexistentes. Describe lo declarado en el código al inicio de la auditoría. El inventario por sí solo no acredita conectividad, persistencia ni autorización en ejecución.

**Actualización P0.1.** Google queda temporalmente deshabilitado en la aplicación Flutter y el servicio cliente rechaza la operación. El contrato de OAuth permanece pendiente en P1.10. El resto del inventario documenta el estado inicial.

## Base compartida y autenticación

- Spring MVC declara las rutas bajo `/api/v1`. Flutter Web y Android usan el mismo `ApiService` y la misma base HTTPS de Render con ese sufijo. Los segmentos de la tabla se agregan a esa base. [ApiService](mobile/lib/core/services/api_service.dart#L14)
- El cliente añade `Authorization: Bearer <token>` cuando existe una sesión local, y `X-Platform: web` o `X-Platform: mobile` según la compilación. Los formularios JSON usan `application/json` y la subida REST usa `multipart/form-data` con el campo `file`. [ApiService](mobile/lib/core/services/api_service.dart#L19) · [CloudinaryService](mobile/lib/services/cloudinary_service.dart#L32)
- Spring permite `OPTIONS`, el registro, el inicio de sesión, la recuperación y los GET públicos existentes. El logout y `GET /auth/me` requieren una sesión válida. Si se envía un Bearer inválido, Spring responde 401 en las rutas que procesan sesión. El filtro valida firma, expiración, vínculo con la cuenta, actividad y rol vigente. La indisponibilidad del repositorio de sesiones devuelve 503. P0.3 aplica restricciones por método, rol y titularidad en las rutas documentadas abajo. [SecurityConfig](backend/backend/src/main/java/co/edu/umb/foodies/backend/security/config/SecurityConfig.java) · [JwtAuthenticationFilter](backend/backend/src/main/java/co/edu/umb/foodies/backend/security/jwt/JwtAuthenticationFilter.java)

## Rutas declaradas

### Identidad y sesiones

| Método y ruta | Entrada | Respuesta de éxito declarada | Consumo Flutter y observación |
| --- | --- | --- | --- |
| POST `/auth/register` | `RegisterRequest` | 200 `AuthResponse` | `AuthService.register` envía `role`. El servicio fija `foodie`. Los formularios administrativos necesitan un flujo protegido separado. |
| POST `/auth/login` | `LoginRequest`, `X-Platform` | 200 `AuthResponse` | `AuthService.login`. Roles administrativos obtienen 403 si el cliente declara `mobile`. La cabecera proviene del cliente. |
| GET `/auth/me` | Bearer vigente | 200 `UserResponse`, 401, 503 | Devuelve el usuario autenticado desde la identidad validada por Spring Security. Flutter usa esta ruta para restaurar la sesión. |
| POST `/auth/logout` | Bearer vigente | 200 `{message}`, 401, 503 | Revoca la sesión del Bearer. Si falla la comunicación, Flutter informa que el cierre solo se confirmó en el dispositivo. |
| POST `/auth/forgot-password` | `{email}` | 200 `{message}` | `AuthService.forgotPassword`. Mensaje uniforme, envío asíncrono sin confirmación de entrega. |
| POST `/auth/reset-password` | `{email, code, newPassword}` | 200 `{message}` | `AuthService.resetPassword`. El método Dart carece de consumidor de pantalla localizado. El mapa carece de DTO validado y la operación no revoca sesiones. |

[AuthController](backend/backend/src/main/java/co/edu/umb/foodies/backend/controller/AuthController.java#L16) · [AuthService Java](backend/backend/src/main/java/co/edu/umb/foodies/backend/service/AuthService.java#L44) · [AuthService Dart](mobile/lib/core/services/auth_service.dart#L14)

### Usuarios y seguidores

| Método y ruta | Entrada | Respuesta de éxito declarada | Consumo Flutter y observación |
| --- | --- | --- | --- |
| GET `/users` | Bearer de moderación o administración | 200 `UserResponse[]` | Moderación recibe perfiles sin contacto ajeno. Administración del sistema dispone de esos campos en el listado de gobierno. |
| GET `/users/{id}` | ID de cliente | 200 `UserResponse` | Correo y teléfono solo en el perfil propio. |
| GET `/users/username/{username}` | Nombre de usuario | 200 `UserResponse` | Aplica la misma política de contacto que el perfil por ID. |
| PUT `/users/{id}` | `UpdateProfileRequest` | 200 `UserResponse` | Edición de perfil y enlace de Google. DTO permite modificar `emailVerified`. |
| PUT `/users/{id}/avatar` | `{avatarUrl}` | 200 `UserResponse` | Sin consumo localizado. La pantalla utiliza el PUT general. |
| PUT `/users/{id}/status` | ID de cliente | 200 `UserResponse` | Administración del sistema y moderación. Moderación solo puede gestionar cuentas `foodie` y `restaurant_admin`. La suspensión revoca sesiones. |
| PUT `/users/{id}/toggle-active` | ID de cliente | 200 `UserResponse` | Alias del PUT de estado, sin consumo localizado. |
| DELETE `/users/{id}` | ID de cliente | 200 vacío | Exclusivo de `admin_sistema`. La integridad referencial del borrado permanece en P1.9. |
| POST `/follows/{userId}` | ID destino | 200 vacío | Perfil. Usa la identidad del JWT y persiste la relación JPA. El autoseguimiento termina sin error. |
| DELETE `/follows/{userId}` | ID destino | 200 vacío | Perfil. Retira la relación y termina sin error si no existe. |

[UserController](backend/backend/src/main/java/co/edu/umb/foodies/backend/controller/UserController.java#L17) · [FollowController](backend/backend/src/main/java/co/edu/umb/foodies/backend/controller/FollowController.java#L11) · [UserService](backend/backend/src/main/java/co/edu/umb/foodies/backend/service/UserService.java#L27) · [Gobierno](mobile/lib/screens/admin/user_governance_screen.dart#L32) · [Perfil](mobile/lib/screens/profile/profile_screen.dart#L62)

### Publicaciones, comentarios y likes

| Método y ruta | Entrada | Respuesta de éxito declarada | Consumo Flutter y observación |
| --- | --- | --- | --- |
| GET `/posts` | Bearer opcional para personalizar likes | 200 `PostDTO[]` | Feed público con publicaciones visibles. Una cuenta autenticada puede consultar además las propias. |
| GET `/posts/user/{userId}` | ID de autor | 200 `PostDTO[]` | Aplica la misma visibilidad del feed al perfil solicitado. |
| POST `/posts` | `PostDTO` | 200 `PostDTO` | Vincula al autor autenticado. El DTO carece de `restaurantId` y la entidad difiere de SQL. |
| DELETE `/posts/{id}` | ID publicación | 200 vacío | Borrado. Verifica autoría. quedan pendientes el contrato de moderación y las relaciones de eliminación. |
| GET `/posts/{postId}/comments` | ID publicación | 200 `CommentDTO[]`, 404 | Requiere que la publicación sea visible para el solicitante. El manejo de errores de la consulta de comentarios queda en P1.2. |
| POST `/posts/{postId}/comments` | `content` o `contenido` | 200 `CommentDTO`, 404 | Vincula al autor autenticado y exige visibilidad de la publicación. El contador queda en P1.6. |
| POST `/posts/{postId}/like` | ID publicación | 200 vacío, 404 | Solo la cuenta autenticada puede alternar su reacción sobre una publicación visible. |

[PostController](backend/backend/src/main/java/co/edu/umb/foodies/backend/controller/PostController.java#L28) · [PostService](backend/backend/src/main/java/co/edu/umb/foodies/backend/service/PostService.java#L32) · [ApiService](mobile/lib/core/services/api_service.dart#L62)

### Restaurantes y menú

| Método y ruta | Entrada | Respuesta de éxito declarada | Consumo Flutter y observación |
| --- | --- | --- | --- |
| GET `/restaurants` | Bearer opcional | 200 `Restaurant[]` | Público consulta activos. El administrador de restaurante ve además sus propios establecimientos. Moderación y administración pueden revisar todos los estados. |
| GET `/restaurants/{id}` | ID restaurante | 200 `Restaurant`, 404 | Activos públicos. Otros estados a su propietario y al personal autorizado. |
| POST `/restaurants` | Entidad `Restaurant` | 200 `Restaurant` | Alta por `restaurant_admin`, con propietario obtenido de la sesión y estado pendiente. La edición sigue en P1.4. |
| PUT `/restaurants/{id}/status` | Entidad `Restaurant` con `status` | 200 `Restaurant` | Cambio de estado por moderación o administración del sistema. |
| DELETE `/restaurants/{id}` | ID restaurante | 200 vacío | Propietario `restaurant_admin` o `admin_sistema`. La integridad referencial se sigue en P1.4. |
| GET `/restaurants/{id}/menu` | ID restaurante | 200 `MenuItem[]` | Detalle y panel administrativo. La entidad apunta a `menu_restaurantes`. El SQL versionado declara `menu_restaurante`. |
| POST `/restaurants/{id}/menu` | Entidad `MenuItem` | 200 `MenuItem` | Requiere `restaurant_admin` propietario. La alineación de la tabla y el CRUD completo siguen en P0.5 y P1.5. |

[RestaurantController](backend/backend/src/main/java/co/edu/umb/foodies/backend/controller/RestaurantController.java#L20) · [ApiService](mobile/lib/core/services/api_service.dart#L112) · [Panel](mobile/lib/screens/admin/restaurant_admin_dashboard.dart#L181) · [Menú](mobile/lib/screens/admin/menu_management_screen.dart#L41) · [SQL de referencia](schema_foodies_db.sql#L253)

### Reservas

| Método y ruta | Entrada | Respuesta de éxito declarada | Consumo Flutter y observación |
| --- | --- | --- | --- |
| GET `/reservations` | `userId?`, `restaurantId?` | 200 `ReservationDTO[]` | Consulta propia o por establecimiento del administrador propietario. Si el panel entra sin ID, se acota a sus establecimientos. |
| POST `/reservations` | Entidad `Reservation` | 200 `ReservationDTO` | Modal. Envía alias duplicados, fecha `yyyy-MM-dd` y hora `HH:mm`. El backend fuerza `pendiente`, con reglas de disponibilidad pendientes. |
| PUT `/reservations/{id}` | `estado` o `status` | 200 `ReservationDTO` | Solo el administrador propietario del restaurante. La validación de transiciones sigue en P1.3. |

[ReservationController](backend/backend/src/main/java/co/edu/umb/foodies/backend/controller/ReservationController.java#L24) · [ReservationDTO](backend/backend/src/main/java/co/edu/umb/foodies/backend/dto/ReservationDTO.java#L19) · [ApiService](mobile/lib/core/services/api_service.dart#L143) · [Modal](mobile/lib/screens/restaurants/create_reservation_modal.dart#L45) · [Panel](mobile/lib/screens/admin/restaurant_reservations_screen.dart#L28)

### PQRS, notificaciones y archivos

| Método y ruta | Entrada | Respuesta de éxito declarada | Consumo Flutter y observación |
| --- | --- | --- | --- |
| GET `/pqrs` | Bearer vigente, `userId?` | 200 `Pqrs[]` | Titular consulta las propias. Moderación y administración pueden listar o filtrar por cliente. |
| POST `/pqrs` | Entidad `Pqrs` | 200 `Pqrs` | `foodie` crea con su identidad y estado `recibida`. Campos administrativos se asignan del lado servidor. |
| PUT `/pqrs/{id}` | Entidad parcial con `estado`, `respuesta` | 200 `Pqrs` | Moderación y administración. La transmisión del texto desde Flutter queda en P1.7. |
| GET `/notifications` | `userId?` | 200 `Notification[]` | Obtiene las notificaciones de quien presenta el Bearer. Rechaza un filtro que señale otra cuenta. |
| POST `/notifications` | Entidad `Notification` | 200 `Notification` | Creación directa restringida a `admin_sistema`. Las notificaciones de negocio desde servicios Spring usan su propio flujo. |
| PUT `/notifications/{id}/read` | ID notificación | 200 `Notification`, 404 | Solo el titular puede marcarla como leída. |
| DELETE `/notifications/{id}` | ID notificación | 200 vacío, 404 | Solo el titular puede borrarla. |
| POST `/files/upload` | `multipart/form-data`, campo `file` | 200 `{url}` | Respaldo de Cloudinary. La primera vía de Flutter utiliza la API de Cloudinary y un preset de subida sin firma. El servidor limita tamaño y revisa el MIME declarado, sin validar contenido binario. |

[PqrsController](backend/backend/src/main/java/co/edu/umb/foodies/backend/controller/PqrsController.java#L12) · [NotificationController](backend/backend/src/main/java/co/edu/umb/foodies/backend/controller/NotificationController.java#L12) · [FileController](backend/backend/src/main/java/co/edu/umb/foodies/backend/controller/FileController.java#L15) · [Gestión PQRS](mobile/lib/screens/admin/pqrs_management_screen.dart#L108) · [Notificaciones Flutter](mobile/lib/core/services/notification_service.dart#L11)

## Llamadas sin contrato correspondiente

| Llamada o funcionalidad | Evidencia |
| --- | --- |
| `POST /api/notifications/broadcast`, `PUT /api/notifications/user/{id}/read-all`, `DELETE /api/notifications/user/{id}` como segmentos de Dio | Prefijo adicional y ausencia de equivalentes en `NotificationController`. La prioridad de broadcast depende de los requerimientos aprobados. [NotificationService](mobile/lib/core/services/notification_service.dart#L33) |
| Actualizar restaurante, consultar restaurante propio, menú por plato | Falta PUT de restaurante, GET de restaurante propio y PUT/DELETE de plato. La edición del restaurante reutiliza creación y la edición del menú es local. [RestaurantController](backend/backend/src/main/java/co/edu/umb/foodies/backend/controller/RestaurantController.java#L29) |
| Reservas personales, administrativas y detalle por ID | La consulta genérica concentra el alcance. Faltan rutas separadas para la persona, para el restaurante y para un ticket por ID. [ReservationController](backend/backend/src/main/java/co/edu/umb/foodies/backend/controller/ReservationController.java#L33) |
| Google Sign-In, verificación de correo y creación administrativa de moderadores | Ausencia de contratos REST específicos en autenticación o usuarios. La auditoría inicial observó un flujo de Google con contraseña compartida en Flutter. Revisar la contención P0.1 antes de utilizar el flujo. [AuthController](backend/backend/src/main/java/co/edu/umb/foodies/backend/controller/AuthController.java#L22) · [AuthService Dart](mobile/lib/core/services/auth_service.dart#L84) |
| Favoritos, reportes, analítica, promociones y acciones de moderación | Hay tablas de soporte en el SQL y pantallas con operaciones locales o adaptadas a otros recursos. El inventario no halló contratos REST dedicados bajo estos recursos. [Esquema SQL](schema_foodies_db.sql) |

El cliente de geocodificación del panel y la apertura de rutas en Maps son conexiones externas. No forman parte del prefijo de SavorSync. [Panel de restaurante](mobile/lib/screens/admin/restaurant_admin_dashboard.dart#L109) · [Mapa](mobile/lib/screens/map/restaurant_map_screen.dart#L85)

## Formas JSON y tipos revisados

| Modelo | Campos y tipos actuales | Diferencia observada |
| --- | --- | --- |
| `LoginRequest`, `RegisterRequest` | Strings `email` y `password`. El registro agrega `username`, `fullName?`, `role?`. | DTO de registro acepta `username` hasta 60 y `fullName` hasta 150. `User` y SQL declaran 50 y 100, respectivamente. |
| `AuthResponse` | `token` string, `tokenType` (`Bearer`), `expiresInMs` entero positivo, `user` objeto. | Spring entrega el JWT después de persistir la sesión. La duración proviene del vencimiento real del JWT. Flutter valida el token y los datos de identidad antes de guardar la credencial. |
| `UserResponse`, `UserModel` | ID y datos personales strings, rol, indicadores booleanos y contadores enteros. Roles `foodie`, `restaurant_admin`, `moderador`, `admin_sistema`. | `restaurantId` existe en Dart, falta en Java. `email` y `phone` salen en respuestas de perfil a terceros. `UpdateProfileRequest.phone` permite 30 y SQL 20. |
| `PostDTO`, `PostModel` | ID, autor, nombre/dirección del restaurante, contenido, imagen, calificación numérica, contadores, indicadores y `createdAt`. | Falta `restaurantId` en Java, falta persistencia para `savedByMe` y la imagen usa una sola URL en DTO mientras SQL tiene registros relacionados. SQL usa calificación entera de 1 a 5. |
| `CommentDTO`, `CommentModel` | Strings `id`, `postId`, `authorId`, `authorName`, `authorAvatarUrl?`, `content`, más `createdAt`. | El modelo JPA tiene `parentId`. Ni la respuesta ni el procesamiento de entrada del controlador implementan el hilo del comentario. |
| `ReservationDTO`, `ReservationModel` | Strings `id`, `restaurantId`, `restaurantName`, `clienteId`, `clienteNombre`, `notas?`, entero `numPersonas` y fecha y hora como strings en JSON. | Estado `pendiente`, `confirmada`, `cancelada` o `completada`. Los tres métodos Java devuelven el DTO en la copia local. Queda pendiente confirmar el formato exacto de hora en ambas plataformas. |
| `Restaurant`, `RestaurantModel` | Strings de identificación y contacto, números para coordenadas/calificación y `status` `pendiente`, `activo` o `suspendido`. | El cliente espera imagen, favoritos, visitas y `adminIds`. Java no los expone y los predeterminados de Dart pueden enmascarar faltantes. |
| `MenuItem`, `MenuItemModel` | Strings `id`, `restaurantId`, `name`, `description?`, `category?`. precio decimal, `isAvailable` booleano y orden entero en Java. | La imagen existe como campo en Dart y queda fuera del contrato JPA y del plato en el SQL versionado. |
| `Pqrs` | `clienteId`, `empleadoId?`, `tipo`, `asunto`, `descripcion`, `estado`, `respuesta?`, `fechaGestion?`, `fechaCierre?`, fechas de creación y actualización. | El cliente usa mapas. Envía `clienteEmail` y `clienteNombre` sin campos Java equivalentes y omite `respuesta` en actualización. Tipos `peticion`, `queja`, `reclamo`, `sugerencia`. Estados `recibida`, `en_gestion`, `resuelta`, `cerrada`. |
| `Notification`, `NotificationModel` | Java expone `id`, `clienteId`, `type`, `title`, `body`, `read`, `channel`, `createdAt`. | Dart lee `userId` o `cliente_id`, omite `clienteId` y espera `targetId`. Java admite `like`, `comentario`, `seguidor`, `respuesta_resena`, `promocion`, `reserva`, `pqrs`. Algunas acciones de Flutter usan nombres en inglés. |

[DTO Java](backend/backend/src/main/java/co/edu/umb/foodies/backend/dto) · [Entidades](backend/backend/src/main/java/co/edu/umb/foodies/backend/model) · [Modelos Dart](mobile/lib/models) · [Esquema SQL](schema_foodies_db.sql)

## Errores y trabajo pendiente

- El advice MVC entrega `{timestamp, status, message}` para validación, excepciones con estado y fallas genéricas. El manejador genérico de la copia local usa un mensaje público estable. Razones de excepciones emitidas por controladores aún pueden contener detalles internos. El formato de errores producidos por Spring Security requiere prueba. [GlobalExceptionHandler](backend/backend/src/main/java/co/edu/umb/foodies/backend/controller/GlobalExceptionHandler.java#L18) · [PostController](backend/backend/src/main/java/co/edu/umb/foodies/backend/controller/PostController.java#L152)
- Flutter mezcla interpretación explícita del error con capturas que devuelven listas vacías o datos aparentes. El interceptor limpia el token frente a cualquier 401, incluidos errores de operaciones de autenticación. [ApiService](mobile/lib/core/services/api_service.dart#L36) · [AuthService Dart](mobile/lib/core/services/auth_service.dart#L123)
- La fase P1 debe acordar con Flutter los códigos `200`, `201`, `204`, `400`, `401`, `403`, `404`, `409`, `413`, `429`, `500` y `503`, documentar los DTO en OpenAPI y probar los consumidores directos. Los cambios de prefijo, de códigos y de representación quedan pendientes de esa fase. [Gradle backend](backend/backend/build.gradle#L21)
