# Contratos REST de SavorSync

Flutter Web y Android comparten la base `/api/v1`, configurada mediante `API_BASE_URL`. Las rutas protegidas reciben `Authorization: Bearer <token>`. `X-Platform` declara la plataforma y no concede permisos. La [matriz de autorización](AUTHORIZATION_MATRIX.md) especifica roles, titularidad, visibilidad y cobertura por ruta.

## Identidad, sesiones y archivos

| Método y ruta | Contrato actual | Seguridad / estado |
|---|---|---|
| POST `/auth/register` | Entrada `RegisterRequest`. 202 `RegistrationResponse` con `verificationRequired`, `challengeId`, `expiresInMs` y `requestedRole`. No crea sesión. | Público. sólo `foodie` y solicitud `restaurant_admin`. El tipo solicitado se conserva separado del rol efectivo. |
| POST `/auth/email/verification` | Reenvío validado. 202 `RegistrationResponse`. | Público y limitado por identidad/origen. No devuelve el código. |
| POST `/auth/email/verify` | `EmailVerificationRequest` con desafío y seis dígitos. AuthResponse sólo tras verificar y persistir sesión. | Público. 400 para inválido/expirado. código de un solo uso. |
| POST `/auth/login` | Credenciales. 200 AuthResponse con Bearer y expiración positiva. | Cuenta activa y correo verificado. usuario no verificado recibe 403 sin sesión. |
| POST `/auth/forgot-password` | `ForgotPasswordRequest`. 202 con mensaje genérico. | Público. no confirma si la cuenta existe. |
| POST `/auth/reset-password` | `ResetPasswordRequest` con email, código y contraseña nueva. 200, 400 si el desafío no es válido. | Código PASSWORD_RESET de un solo uso. revoca sesiones de esa identidad. |
| POST `/auth/restaurant-admin/request` | Descripción validada. 202 con solicitud PQRS. | Foodie activo y verificado, incluso si se registró como Foodie. Actualiza el tipo solicitado y reutiliza la solicitud pendiente. La aprobación del establecimiento es un proceso separado. |
| POST `/auth/restaurant-admin/requests/{id}/approve` | UserResponse. | ROLE_ADMIN_SISTEMA. promociona rol efectivo y revoca sesiones existentes. |
| POST `/files/upload` | multipart `file`. 201 `{url, publicId}`. | Cuenta activa/verificada. el servidor valida JPEG/PNG, MIME real, ≤10 MiB y ≤12 MP, sube a Cloudinary y registra propietario. El API secret no se incluye en Flutter. |
| GET `/auth/me` | 200 `UserResponse`. | Bearer vigente. Flutter restaura la sesión por esta ruta. |
| POST `/auth/logout` | 200 `{message}`. | Revoca la sesión del Bearer. |
| GET `/actuator/health` (fuera de `/api/v1`) | 200 `{"status":"UP"}` o 503 `{"status":"DOWN"}`. | Público, comprueba la base de datos. |

`AuthResponse` contiene `token`, `tokenType` (Bearer), `expiresInMs` y `user`. El servidor persiste la sesión antes de emitir la respuesta. El reenvío acepta email y contraseña desde login o un identificador vigente del desafío anterior. Una petición sin prueba válida recibe 202 genérico sin desafío ni rol. El reenvío autorizado conserva el tipo solicitado. Los empleados existentes siguen el flujo individual de verificación de su identidad interna.

La carga usa Cloudinary firmado desde el backend y registra el propietario. La asociación autoriza el mismo recurso y propietario en reintentos, y rechaza reutilizaciones ajenas o arbitrarias. La aprobación de la cuenta y la publicación del restaurante son operaciones distintas.

## Recursos

### Usuarios y seguidores

| Método y ruta | Entrada | Respuesta de éxito declarada |
|---|---|---|
| GET `/users` | Bearer de moderación o administración | 200 `UserResponse[]` |
| GET `/users/{id}` | ID de cliente | 200 `UserResponse` |
| GET `/users/username/{username}` | Nombre de usuario | 200 `UserResponse` |
| PUT `/users/{id}` | `UpdateProfileRequest` | 200 `UserResponse` |
| PUT `/users/{id}/avatar` | `{avatarUrl}` | 200 `UserResponse` |
| PUT `/users/{id}/status` | ID de cliente | 200 `UserResponse` |
| PUT `/users/{id}/toggle-active` | ID de cliente | 200 `UserResponse` |
| DELETE `/users/{id}` | ID de cliente | 204, desactiva la cuenta y revoca sus sesiones |
| POST `/follows/{userId}` | ID de cuenta activa | 200 idempotente, 400 si es la misma cuenta |
| DELETE `/follows/{userId}` | ID destino | 200 vacío |


### Publicaciones, comentarios y likes

| Método y ruta | Entrada | Respuesta de éxito declarada |
|---|---|---|
| GET `/posts` | Bearer opcional para personalizar likes | 200 `PostDTO[]` |
| GET `/posts/user/{userId}` | ID de autor | 200 `PostDTO[]` |
| POST `/posts` | `PostDTO`, calificación entera entre 1 y 5 y `restaurantId` opcional de un local activo | 201 `PostDTO` |
| DELETE `/posts/{id}` | ID de publicación propia | 204, oculta y conserva las referencias |
| GET `/posts/{postId}/comments` | ID publicación | 200 `CommentDTO[]`, 404 |
| POST `/posts/{postId}/comments` | `content` o `contenido`, `parentId` opcional de la misma publicación | 201 `CommentDTO`, 400 si el padre es inválido, 404 si la publicación no está visible |
| POST `/posts/{postId}/like` | ID publicación | 200 vacío, 404 |


### Restaurantes y menú

| Método y ruta | Entrada | Respuesta de éxito declarada |
|---|---|---|
| GET `/restaurants` | Bearer opcional | 200 `Restaurant[]` |
| GET `/restaurants/{id}` | ID restaurante | 200 `Restaurant`, 404 |
| POST `/restaurants` | Nombre, dirección, categoría y campos descriptivos | 201 `Restaurant` en estado pendiente, propietario derivado de la sesión |
| PUT `/restaurants/{id}/status` | Entidad `Restaurant` con `status` | 200 `Restaurant` |
| DELETE `/restaurants/{id}` | ID de restaurante propio o supervisado por Admin sistema | 204, desactiva y conserva las dependencias |
| GET `/restaurants/{id}/menu` | ID restaurante | 200 `MenuItem[]` |
| POST `/restaurants/{id}/menu` | Entidad `MenuItem` | 201 `MenuItem` |


### Reservas

| Método y ruta | Entrada | Respuesta de éxito declarada |
|---|---|---|
| GET `/reservations` | `userId?`, `restaurantId?` | 200 `ReservationDTO[]` |
| POST `/reservations` | Restaurante, fecha, hora y número de personas | 201 `ReservationDTO`, 400 para entrada inválida, 409 si el local no está activo o el horario no admite la reserva |
| PUT `/reservations/{id}` | `estado` o `status` | 200 `ReservationDTO`, 400 para estado inválido y 409 para una reserva cerrada |


### PQRS, notificaciones y archivos

| Método y ruta | Entrada | Respuesta de éxito declarada |
|---|---|---|
| GET `/pqrs` | Bearer vigente, `userId?` | 200 `Pqrs[]` |
| POST `/pqrs` | Entidad `Pqrs` | 200 `Pqrs` |
| PUT `/pqrs/{id}` | Entidad parcial con `estado`, `respuesta` | 200 `Pqrs` |
| GET `/notifications` | `userId?` | 200 `Notification[]` |
| POST `/notifications` | Entidad `Notification` | 200 `Notification` |
| PUT `/notifications/{id}/read` | ID notificación | 200 `Notification`, 404 |
| DELETE `/notifications/{id}` | ID notificación | 204, 404 |

Los perfiles ocultan datos de contacto a terceros salvo vistas administrativas autorizadas. Reservas usa los estados `pendiente`, `confirmada`, `cancelada` y `completada`. Los restaurantes usan `pendiente`, `activo` y `suspendido`. PQRS usa `peticion`, `queja`, `reclamo` y `sugerencia`, con estados `recibida`, `en_gestion`, `resuelta` y `cerrada`.

## Errores y límites del contrato

Los errores sanitizados incluyen `status`, `code`, `message` y `timestamp`. Se distinguen autenticación (401), permisos (403), recurso no visible o inexistente (404), conflicto (409), tamaño (413), cuota (429) e indisponibilidad (503). Los OTP y secretos quedan fuera de las respuestas. El JWT solo aparece en la respuesta de autenticación prevista.

Consultar los [pendientes vigentes](../README.md#hallazgos-y-validaciones-pendientes) antes de asumir soporte para cualquier llamada Flutter sin equivalente confirmado. Los problemas históricos de DTO y consumidores se conservan en el [historial de versiones](../VERSIONES_DEL_PROYECTO.md).
