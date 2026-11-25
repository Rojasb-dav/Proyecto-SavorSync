# Matriz de autorización V3.2

Fecha: 2026-11-25. Describe el código local de fix/savorsync-remediation-v3 y el contrato observado en controladores, SecurityConfig y servicios. No acredita permisos configurados en producción.

## Roles y respuestas

- Visitante: sin credencial. Lee únicamente contenido que el servicio expone como público y activo.
- No verificado: el registro no emite JWT; no existe sesión normal hasta confirmar el correo. Un JWT histórico/inconsistente no recibe los roles efectivos.
- Foodie: cliente verificado. Puede efectuar operaciones sociales propias y crear reservas/PQRS para sí mismo.
- Restaurant admin: cuenta aprobada con rol efectivo; sólo gestiona establecimientos que le pertenecen.
- Moderador: empleado verificado con autoridad de moderación, limitada a las operaciones expresas.
- Admin sistema: empleado verificado con permisos de administración del sistema.
- Respuesta general: visitante en ruta protegida: 401; identidad válida con rol insuficiente: 403; recurso privado, inexistente, inactivo o no visible que se oculta: 404. Errores de validación conservan 4xx. OPTIONS /** está permitido para preflight.

## Endpoints

| Método y ruta | Visitante | No verificado | Foodie | Restaurant admin | Moderador | Admin sistema | Titularidad/estado y denegación | Respuesta autorizada | Pruebas |
|---|---|---|---|---|---|---|---|---|---|
| POST /api/v1/auth/register | Permitir | Permitir | Permitir | Permitir | Permitir | Permitir | DTO acepta foodie o restaurant_admin; HTTP 202 sin JWT. Duplicados 409. | 202 | SessionMySqlTest, pruebas de identidad |
| POST /api/v1/auth/login | Permitir | Permitir | Permitir | Permitir | Permitir | Permitir | Sólo cuenta activa y correo verificado obtiene sesión; inválido 401/403. | 200 | SessionMySqlTest, AuthServiceSessionTest |
| POST /api/v1/auth/email/verification | Permitir | Permitir | Permitir | Permitir | Permitir | Permitir | HTTP 202. Requiere contraseña válida o desafío vigente de la identidad para renovar. Solicitudes sin prueba reciben cuerpo genérico. | 202 | SessionMySqlTest, EmailVerificationServiceTest |
| POST /api/v1/auth/email/verify | Permitir | Permitir | Permitir | Permitir | Permitir | Permitir | Challenge y código válido/no consumido; inválido o expirado 400. Sesión sólo tras verificar. | 200 | SessionMySqlTest, EmailVerificationServiceTest |
| GET /api/v1/auth/me, POST /api/v1/auth/logout | 401 | 403 | Permitir | Permitir | Permitir | Permitir | Sesión vigente de la propia cuenta. Perfil 200, logout 200 y revocación. | 200 | SessionMySqlTest, JwtAuthenticationFilterTest |
| POST /api/v1/auth/forgot-password, /api/v1/auth/reset-password | Permitir | Permitir | Permitir | Permitir | Permitir | Permitir | Respuesta de solicitud genérica; código asociado a propósito e identidad. | 202 solicitud, 200 cambio | AuthServiceSessionTest, EmailVerificationServiceTest |
| GET /api/v1/posts, /api/v1/posts/user/{userId} | Público | Público | Permitir | Permitir | Permitir | Permitir | Sólo publicaciones visibles, vigentes y de cuentas activas; privadas/inactivas no se exponen. | 200 | AuthorizationMvcTest, SessionMySqlTest |
| GET /api/v1/posts/{postId}/comments | Público si post visible | Igual | Permitir | Permitir | Permitir | Permitir | Post no visible: 404 al visitante; comentarios activos únicamente. | 200 | AuthorizationMvcTest, SessionMySqlTest |
| POST /api/v1/posts, /api/v1/posts/{postId}/comments, /api/v1/posts/{postId}/like, POST/DELETE /api/v1/follows/{userId}, DELETE /api/v1/posts/{id} | 401 | 403 | Permitir | 403 | 403 | 403 | Escrituras sociales Foodie únicamente; autor desde sesión; borrado sólo por autor; destino visible/activo. | 201 publicación y comentario, 200 like/seguir/dejar de seguir, 204 borrado | AuthorizationMvcTest, SessionMySqlTest |
| GET /api/v1/restaurants, /api/v1/restaurants/{id} | Público | Público | Permitir | Permitir | Permitir | Permitir | Visita pública limitada a activos. El dueño y los roles internos pueden ver estados no públicos. | 200 | AuthorizationMvcTest |
| GET /api/v1/restaurants/{id}/menu | Público | Público | Permitir | Permitir | Permitir | Permitir | Visitantes y Foodies sólo en restaurantes activos. El dueño y los roles internos pueden consultar estados privados. | 200 | AuthorizationMvcTest |
| POST /api/v1/restaurants, POST /api/v1/restaurants/{id}/menu, PUT /api/v1/restaurants/{id}, PUT /api/v1/restaurants/{id}/menu/{itemId}, DELETE /api/v1/restaurants/{id}/menu/{itemId} | 401 | 403 | 403 | Permitir con propiedad | 403 | 403 | Servicio comprueba dueño autenticado y consistencia menú-restaurante; ajeno: 403/404. | 201 altas, 200 ediciones, 204 borrado | AuthorizationMvcTest |
| PUT /api/v1/restaurants/{id}/status | 401 | 403 | 403 | 403 | Permitir | Permitir | Moderación y sistema cambian el estado con valores del enum. | 200 | AuthorizationMvcTest |
| DELETE /api/v1/restaurants/{id} | 401 | 403 | 403 | Permitir con propiedad | 403 | Permitir | Admin restaurante sólo su establecimiento; no se borran imágenes históricas automáticamente. | 204 | Inspección del controlador |
| GET /api/v1/users/{id}, GET /api/v1/users/username/{username} | Vista pública | Vista pública | Igual | Igual | Igual | Igual | DTO público evita datos privados; inactivos/no visibles ocultos. | 200 | AuthorizationMvcTest, UserServiceSessionTest |
| GET /api/v1/users | 401 | 403 | 403 | 403 | Permitir | Permitir | Lista completa sólo Moderador/Admin sistema. | 200 | AuthorizationMvcTest |
| PUT /api/v1/users/{id}, PUT /api/v1/users/{id}/avatar | 401 | 403 | Sólo self | Sólo self | 403 | 403 | Campos controlados; rol/verificación/estado no vienen del cliente. URL nueva debe pertenecer al dueño. | 200 | AuthorizationMvcTest, SessionMySqlTest |
| PUT /api/v1/users/{id}/status, PUT /api/v1/users/{id}/toggle-active | 401 | 403 | 403 | 403 | Permitir | Permitir | Sólo Moderador/Admin sistema; suspender revoca sesiones. | 200 | AuthorizationMvcTest, SessionMySqlTest |
| DELETE /api/v1/users/{id} | 401 | 403 | 403 | 403 | 403 | Permitir | Sólo Admin sistema. | 204 | AuthorizationMvcTest |
| GET /api/v1/reservations | 401 | 403 | Propias | Restaurantes propios | 403 | 403 | No acepta identidad/restaurantId como autoridad; ajeno 403/404. | 200 | AuthorizationMvcTest |
| POST /api/v1/reservations | 401 | 403 | Permitir | 403 | 403 | 403 | Foodie verificado/activo; cliente desde JWT y restaurante activo. | 201 | AuthorizationMvcTest |
| PUT /api/v1/reservations/{id} | 401 | 403 | 403 | Sólo restaurante propio | 403 | 403 | Admin no actualiza reservas de otro establecimiento. | 200 | AuthorizationMvcTest |
| GET /api/v1/notifications | 401 | 403 | Propias | Propias | 403 | 403 | No leer bandeja ajena. | 200 | AuthorizationMvcTest |
| PUT /api/v1/notifications/{id}/read, DELETE /api/v1/notifications/{id} | 401 | 403 | Sólo propia | Sólo propia | 403 | 403 | Titular del registro obligatorio. | 200 al marcar, 204 al borrar | AuthorizationMvcTest |
| POST /api/v1/notifications | 401 | 403 | 403 | 403 | 403 | Permitir | Sólo Admin sistema crea notificación por esta ruta. | 201 | AuthorizationMvcTest |
| GET /api/v1/pqrs | 401 | 403 | Propias | 403 | Permitir | Permitir | Foodie ve las propias; Moderador/Admin gestiona; userId ajeno se restringe en servicio. | 200 | AuthorizationMvcTest |
| POST /api/v1/pqrs | 401 | 403 | Permitir | 403 | 403 | 403 | Autor desde sesión Foodie. | 201 | AuthorizationMvcTest |
| PUT /api/v1/pqrs/{id} | 401 | 403 | 403 | 403 | Permitir | Permitir | Moderador/Admin cambia estado y respuesta. Las solicitudes de restaurante se reservan al Admin sistema. | 200 | AuthorizationMvcTest |
| POST /api/v1/auth/restaurant-admin/request | 401 | 403 | Permitir | 403 | 403 | 403 | Solicitud asociada al Foodie; no eleva rol. | 202 | SessionMySqlTest |
| POST /api/v1/auth/restaurant-admin/requests/{id}/approve | 401 | 403 | 403 | 403 | 403 | Permitir | Sólo Admin sistema; cambio de rol revoca sesiones anteriores. | 200 | SessionMySqlTest |
| POST /api/v1/auth/moderators | 401 | 403 | 403 | 403 | 403 | Permitir | Creación interna; correo aún debe verificarse. | 201 | SessionMySqlTest |
| POST /api/v1/files/upload | 401 | 403 | Permitir | Permitir | 403 | 403 | JPEG/PNG validado en servidor; límites de bytes/píxeles; asociación al propietario. | 201 | FileUploadP08Test, SessionMySqlTest |
| Cualquier ruta restante | Denegar | Denegar | Denegar | Denegar | Denegar | Denegar | SecurityConfig usa anyRequest().denyAll(). | — | AuthorizationMvcTest |

## Alcance de la evidencia

Hay pruebas negativas de roles internos frente a escrituras sociales, usuario no verificado, restaurante no aprobado y propiedad de perfiles/archivos; pruebas MySQL verifican registro–OTP–sesión, solicitud/aprobación, revocación y titularidad de archivos. Existen pruebas unitarias/MockMvc de reservas, PQRS y notificaciones. No se ejecutó una prueba combinatoria de cada celda ni E2E en Flutter Web/Android. Las filas sin caso específico son reglas inspeccionadas, no cobertura exhaustiva. No se afirman permisos efectivos en producción.
