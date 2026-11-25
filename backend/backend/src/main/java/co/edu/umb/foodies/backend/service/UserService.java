package co.edu.umb.foodies.backend.service;

import co.edu.umb.foodies.backend.dto.request.UpdateProfileRequest;
import co.edu.umb.foodies.backend.dto.response.UserResponse;
import co.edu.umb.foodies.backend.model.Notification;
import co.edu.umb.foodies.backend.model.User;
import co.edu.umb.foodies.backend.repository.ClientSessionRepository;
import co.edu.umb.foodies.backend.repository.NotificationRepository;
import co.edu.umb.foodies.backend.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.time.LocalDateTime;
import java.util.HashSet;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class UserService {

    private final UserRepository userRepository;
    private final NotificationRepository notificationRepository;
    private final ClientSessionRepository clientSessionRepository;
    private final AccountIdentityRegistry identities;
    private final CloudinaryAssetRegistry assetRegistry;

    public List<UserResponse> getAllUsers(String authUserId) {
        return userRepository.findAll().stream()
                .map(u -> UserResponse.fromPublic(u, authUserId))
                .toList();
    }

    public UserResponse getById(String id, String authUserId) {
        User user = userRepository.findById(id)
                .filter(found -> Boolean.TRUE.equals(found.getIsActive())
                        || id.equals(authUserId))
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Usuario no encontrado"));
        return UserResponse.fromPublic(user, authUserId);
    }

    public UserResponse getByUsername(String username, String authUserId) {
        User user = userRepository.findByUsername(username)
                .filter(found -> Boolean.TRUE.equals(found.getIsActive())
                        || found.getId().equals(authUserId))
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Usuario no encontrado"));
        return UserResponse.fromPublic(user, authUserId);
    }

    @Transactional
    public UserResponse updateProfile(String authUserId, String targetId, UpdateProfileRequest req) {
        if (!authUserId.equals(targetId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "No puedes modificar este perfil");
        }
        User user = userRepository.findByIdForUpdate(targetId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Usuario no encontrado"));

        if (req.getFullName() != null) user.setFullName(req.getFullName());
        if (req.getBio() != null) user.setBio(req.getBio());
        if (req.getPhone() != null) user.setPhone(req.getPhone());
        if (req.getAvatarUrl() != null && !req.getAvatarUrl().isBlank()
                && !req.getAvatarUrl().equals(user.getAvatarUrl())) {
            requireOwnedAvatar(targetId, req.getAvatarUrl());
            user.setAvatarUrl(req.getAvatarUrl());
        }

        if (req.getUsername() != null && !req.getUsername().equals(user.getUsername())) {
            String username = req.getUsername().trim();
            if (userRepository.existsByUsername(username)) {
                throw new ResponseStatusException(HttpStatus.CONFLICT, "El nombre de usuario ya existe");
            }
            identities.updateUsername("client", targetId, username);
            user.setUsername(username);
        }

        return UserResponse.fromSelf(userRepository.save(user));
    }

    @Transactional
    public UserResponse updateAvatar(String authUserId, String targetId, String avatarUrl) {
        if (!authUserId.equals(targetId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "No puedes modificar este perfil");
        }
        User user = userRepository.findByIdForUpdate(targetId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Usuario no encontrado"));
        if (avatarUrl == null || avatarUrl.isBlank()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Selecciona una imagen válida.");
        }
        if (!avatarUrl.equals(user.getAvatarUrl())) {
            requireOwnedAvatar(targetId, avatarUrl);
            user.setAvatarUrl(avatarUrl);
        }
        return UserResponse.fromSelf(userRepository.save(user));
    }

    private void requireOwnedAvatar(String userId, String avatarUrl) {
        if (!assetRegistry.attachIfOwned("client", userId, avatarUrl, "profile", userId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN,
                    "La imagen no pertenece a tu cuenta o ya está asociada a otro recurso.");
        }
    }

    @Transactional
    public UserResponse toggleUserStatus(String targetId) {
        return toggleUserStatus(targetId, false);
    }

    @Transactional
    public UserResponse toggleUserStatus(String targetId, boolean restrictToCustomers) {
        User user = userRepository.findByIdForUpdate(targetId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Usuario no encontrado"));
        if (restrictToCustomers && user.getRole() != User.Role.foodie
                && user.getRole() != User.Role.restaurant_admin) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "No puedes gestionar esta cuenta");
        }
        boolean activating = !Boolean.TRUE.equals(user.getIsActive());
        user.setIsActive(activating);
        User saved = userRepository.save(user);
        if (!activating) {
            clientSessionRepository.revokeActiveByUserId(saved.getId());
        }
        return UserResponse.fromPublic(saved, null);
    }

    @Transactional
    public void deleteUser(String targetId) {
        clientSessionRepository.revokeActiveByUserId(targetId);
        userRepository.deleteById(targetId);
        identities.delete("client", targetId);
    }

    @Transactional
    public void follow(String followerId, String followingId) {
        if (followerId == null || followingId == null || followerId.equals(followingId)) return;
        User follower = userRepository.findById(followerId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Seguidor no encontrado"));
        User following = userRepository.findById(followingId)
                .filter(user -> Boolean.TRUE.equals(user.getIsActive()))
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Usuario a seguir no encontrado"));
        requireFoodie(follower);

        if (follower.getFollowing() == null) {
            follower.setFollowing(new HashSet<>());
        }

        if (!follower.getFollowing().contains(following)) {
            follower.getFollowing().add(following);
            userRepository.save(follower);

            try {
                notificationRepository.save(Notification.builder()
                        .id(UUID.randomUUID().toString())
                        .clienteId(followingId)
                        .type(Notification.NotificationType.seguidor)
                        .title("¡Tienes un nuevo seguidor! 👥")
                        .body("@" + follower.getUsername() + " ha comenzado a seguirte en SavorSync.")
                        .read(false)
                        .channel(Notification.Channel.in_app)
                        .createdAt(LocalDateTime.now())
                        .build());
            } catch (Exception e) {
                System.err.println("WARN: Fallo al notificar Follow: " + e.getMessage());
            }
        }
    }

    private static void requireFoodie(User user) {
        if (user.getRole() != User.Role.foodie) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN,
                    "Esta operación está disponible para cuentas Foodie.");
        }
    }

    @Transactional
    public void unfollow(String followerId, String followingId) {
        if (followerId == null || followingId == null) return;
        User follower = userRepository.findById(followerId).orElse(null);
        User following = userRepository.findById(followingId).orElse(null);
        if (follower != null && following != null && follower.getFollowing() != null) {
            requireFoodie(follower);
            follower.getFollowing().remove(following);
            userRepository.save(follower);
        }
    }
}
