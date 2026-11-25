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

    public List<UserResponse> getAllUsers(String authUserId) {
        return userRepository.findAll().stream()
                .map(u -> UserResponse.fromPublic(u, authUserId))
                .toList();
    }

    public UserResponse getById(String id, String authUserId) {
        User user = userRepository.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Usuario no encontrado"));
        return UserResponse.fromPublic(user, authUserId);
    }

    public UserResponse getByUsername(String username, String authUserId) {
        User user = userRepository.findByUsername(username)
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
        if (req.getAvatarUrl() != null && !req.getAvatarUrl().isBlank()) user.setAvatarUrl(req.getAvatarUrl());

        if (req.getUsername() != null && !req.getUsername().equals(user.getUsername())) {
            if (userRepository.existsByUsername(req.getUsername())) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "El nombre de usuario ya existe");
            }
            user.setUsername(req.getUsername());
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
        user.setAvatarUrl(avatarUrl);
        return UserResponse.fromSelf(userRepository.save(user));
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
            clientSessionRepository.findAll().stream()
                .filter(s -> saved.getId().equals(s.getUserId()) && s.getIsActive())
                .forEach(s -> {
                    s.setIsActive(false);
                    clientSessionRepository.save(s);
                });
        }
        return UserResponse.fromPublic(saved, null);
    }

    @Transactional
    public void deleteUser(String targetId) {
        userRepository.deleteById(targetId);
    }

    @Transactional
    public void follow(String followerId, String followingId) {
        if (followerId == null || followingId == null || followerId.equals(followingId)) return;
        User follower = userRepository.findById(followerId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Seguidor no encontrado"));
        User following = userRepository.findById(followingId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Usuario a seguir no encontrado"));

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

    @Transactional
    public void unfollow(String followerId, String followingId) {
        if (followerId == null || followingId == null) return;
        User follower = userRepository.findById(followerId).orElse(null);
        User following = userRepository.findById(followingId).orElse(null);
        if (follower != null && following != null && follower.getFollowing() != null) {
            follower.getFollowing().remove(following);
            userRepository.save(follower);
        }
    }
}
