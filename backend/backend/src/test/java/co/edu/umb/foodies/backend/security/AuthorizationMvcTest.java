package co.edu.umb.foodies.backend.security;

import co.edu.umb.foodies.backend.controller.*;
import co.edu.umb.foodies.backend.dto.PostDTO;
import co.edu.umb.foodies.backend.dto.response.UserResponse;
import co.edu.umb.foodies.backend.model.Notification;
import co.edu.umb.foodies.backend.model.Restaurant;
import co.edu.umb.foodies.backend.repository.*;
import co.edu.umb.foodies.backend.security.config.SecurityConfig;
import co.edu.umb.foodies.backend.security.jwt.JwtAuthenticationFilter;
import co.edu.umb.foodies.backend.security.jwt.JwtUtil;
import co.edu.umb.foodies.backend.service.UserService;
import co.edu.umb.foodies.backend.service.PostService;
import co.edu.umb.foodies.backend.service.CloudinaryService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import java.util.List;
import java.util.Optional;

import static org.mockito.Mockito.*;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.user;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;

@WebMvcTest({UserController.class, ReservationController.class, RestaurantController.class,
        PqrsController.class, NotificationController.class, PostController.class, FileController.class})
@Import({SecurityConfig.class, JwtAuthenticationFilter.class, RestSecurityErrors.class})
class AuthorizationMvcTest {

    @Autowired private MockMvc mvc;

    @MockBean private UserService userService;
    @MockBean private ClientSessionRepository sessions;
    @MockBean private EmployeeSessionRepository employeeSessions;
    @MockBean private JwtUtil jwtUtil;
    @MockBean private UserRepository users;
    @MockBean private EmployeeRepository employeeRepository;
    @MockBean private ReservationRepository reservations;
    @MockBean private RestaurantRepository restaurants;
    @MockBean private MenuItemRepository menu;
    @MockBean private PqrsRepository pqrs;
    @MockBean private NotificationRepository notifications;
    @MockBean private PostRepository posts;
    @MockBean private CommentRepository comments;
    @MockBean private PostService postService;
    @MockBean private CloudinaryService cloudinary;
    @MockBean private RestaurantImageRepository restaurantImageRepository;

    @Test
    void profileContactIsOnlyReturnedToItsOwner() throws Exception {
        when(userService.getById(eq("owner"), anyString())).thenAnswer(call -> {
            String viewerId = call.getArgument(1);
            boolean isOwner = "owner".equals(viewerId);
            return UserResponse.builder()
                .id("owner").email(isOwner ? "owner@example.test" : null).phone(isOwner ? "123" : null).build();
        });
        mvc.perform(get("/api/v1/users/owner").with(user("another").roles("FOODIE")))
                .andExpect(status().isOk()).andExpect(jsonPath("$.email").doesNotExist())
                .andExpect(jsonPath("$.phone").doesNotExist());
        mvc.perform(get("/api/v1/users/owner").with(user("owner").roles("FOODIE")))
                .andExpect(status().isOk()).andExpect(jsonPath("$.email").value("owner@example.test"));
    }

    @Test
    void postsUseAuthenticatedAuthorAndUploadsRequireAuthentication() throws Exception {
        mvc.perform(post("/api/v1/files/upload")).andExpect(status().isUnauthorized());
        mvc.perform(post("/api/v1/posts").with(user("author").roles("FOODIE"))
                        .contentType(MediaType.APPLICATION_JSON).content("{\"userId\":\"other\"}"))
                .andExpect(status().isCreated());
        verify(postService).createPost(any(PostDTO.class), eq("author"));
        verifyNoInteractions(cloudinary);
    }

    @Test
    void pqrsIsPrivateAndUsesTheCurrentAccount() throws Exception {
        mvc.perform(get("/api/v1/pqrs")).andExpect(status().isUnauthorized());
        mvc.perform(get("/api/v1/pqrs").param("userId", "another")
                        .with(user("owner").roles("FOODIE"))).andExpect(status().isForbidden());
        when(pqrs.findByClienteId("owner")).thenReturn(List.of());
        mvc.perform(get("/api/v1/pqrs").with(user("owner").roles("FOODIE")))
                .andExpect(status().isOk());
        verify(pqrs).findByClienteId("owner");
        verify(pqrs, never()).findAll();
    }

    @Test
    void governanceAndPqrsWritesRejectUnprivilegedRoles() throws Exception {
        mvc.perform(put("/api/v1/users/another/status").with(user("customer").roles("FOODIE")))
                .andExpect(status().isForbidden());
        mvc.perform(delete("/api/v1/users/another").with(user("moderator").roles("MODERADOR")))
                .andExpect(status().isForbidden());
        mvc.perform(put("/api/v1/pqrs/case").with(user("customer").roles("FOODIE"))
                        .contentType(MediaType.APPLICATION_JSON).content("{}"))
                .andExpect(status().isForbidden());
        verifyNoInteractions(userService, pqrs);
    }

    @Test
    void restaurantQueriesAndMenuWritesRequireOwnership() throws Exception {
        Restaurant other = Restaurant.builder().id("restaurant").ownerId("actual-owner").build();
        when(restaurants.findById("restaurant")).thenReturn(Optional.of(other));
        mvc.perform(get("/api/v1/reservations").param("restaurantId", "restaurant")
                        .with(user("unrelated-admin").roles("RESTAURANT_ADMIN"))).andExpect(status().isForbidden());
        mvc.perform(post("/api/v1/restaurants/restaurant/menu").with(user("unrelated-admin").roles("RESTAURANT_ADMIN"))
                        .contentType(MediaType.APPLICATION_JSON).content("{}")).andExpect(status().isForbidden());
        mvc.perform(put("/api/v1/restaurants/restaurant/status").with(user("customer").roles("FOODIE"))
                        .contentType(MediaType.APPLICATION_JSON).content("{}")).andExpect(status().isForbidden());
        when(reservations.findByRestaurantId("restaurant")).thenReturn(List.of());
        mvc.perform(get("/api/v1/reservations").param("restaurantId", "restaurant")
                        .with(user("actual-owner").roles("RESTAURANT_ADMIN"))).andExpect(status().isOk());
        verify(reservations).findByRestaurantId("restaurant");
        verifyNoInteractions(menu);
    }

    @Test
    void customerReservationsUseTheAuthenticatedAccount() throws Exception {
        mvc.perform(get("/api/v1/reservations").param("userId", "another")
                        .with(user("customer").roles("FOODIE"))).andExpect(status().isForbidden());
        when(reservations.findByClienteId("customer")).thenReturn(List.of());
        mvc.perform(get("/api/v1/reservations").with(user("customer").roles("FOODIE")))
                .andExpect(status().isOk());
        verify(reservations).findByClienteId("customer");
        verifyNoMoreInteractions(reservations);
    }

    @Test
    void notificationsCannotBeReadOrMutatedByAnotherAccount() throws Exception {
        when(notifications.findById("notice")).thenReturn(Optional.of(
                Notification.builder().id("notice").clienteId("owner").build()));
        mvc.perform(get("/api/v1/notifications").param("userId", "owner")
                        .with(user("another").roles("FOODIE"))).andExpect(status().isForbidden());
        mvc.perform(put("/api/v1/notifications/notice/read").with(user("another").roles("FOODIE")))
                .andExpect(status().isNotFound());
        mvc.perform(delete("/api/v1/notifications/notice").with(user("another").roles("FOODIE")))
                .andExpect(status().isNotFound());
        mvc.perform(post("/api/v1/notifications").with(user("another").roles("FOODIE"))
                        .contentType(MediaType.APPLICATION_JSON).content("{}")).andExpect(status().isForbidden());
        verify(notifications, times(2)).findById("notice");
        verifyNoMoreInteractions(notifications);
    }
}
