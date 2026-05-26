package co.edu.umb.foodies.backend.service;

import co.edu.umb.foodies.backend.dto.request.UpdateProfileRequest;
import co.edu.umb.foodies.backend.dto.response.UserResponse;
import co.edu.umb.foodies.backend.model.User;
import co.edu.umb.foodies.backend.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

@Service
@RequiredArgsConstructor
public class UserService {

    private final UserRepository userRepository;

    public UserResponse getById(String id, String authUserId) {
        User user = userRepository.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Usuario no encontrado"));
        return UserResponse.from(user, authUserId);
    }

    public UserResponse getByUsername(String username, String authUserId) {
        User user = userRepository.findByUsername(username)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Usuario no encontrado"));
        return UserResponse.from(user, authUserId);
    }

    @Transactional
    public UserResponse updateProfile(String authUserId, String targetId, UpdateProfileRequest req) {
        if (!authUserId.equals(targetId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "No puedes modificar este perfil");
        }
        User user = userRepository.findById(targetId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Usuario no encontrado"));

        if (req.getFullName() != null) user.setFullName(req.getFullName());
        if (req.getBio() != null) user.setBio(req.getBio());
        if (req.getPhone() != null) user.setPhone(req.getPhone());
        if (req.getUsername() != null && !req.getUsername().equals(user.getUsername())) {
            if (userRepository.existsByUsername(req.getUsername())) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "El nombre de usuario ya existe");
            }
            user.setUsername(req.getUsername());
        }

        return UserResponse.from(userRepository.save(user));
    }

    @Transactional
    public UserResponse updateAvatar(String authUserId, String targetId, String avatarUrl) {
        if (!authUserId.equals(targetId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "No puedes modificar este perfil");
        }
        User user = userRepository.findById(targetId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Usuario no encontrado"));
        user.setAvatarUrl(avatarUrl);
        return UserResponse.from(userRepository.save(user));
    }

    @Transactional
    public void follow(String followerId, String followingId) {
        if (followerId.equals(followingId)) return;
        User follower = userRepository.findById(followerId).orElseThrow();
        User following = userRepository.findById(followingId).orElseThrow();
        follower.getFollowing().add(following);
        userRepository.save(follower);
    }

    @Transactional
    public void unfollow(String followerId, String followingId) {
        User follower = userRepository.findById(followerId).orElseThrow();
        User following = userRepository.findById(followingId).orElseThrow();
        follower.getFollowing().remove(following);
        userRepository.save(follower);
    }
}
