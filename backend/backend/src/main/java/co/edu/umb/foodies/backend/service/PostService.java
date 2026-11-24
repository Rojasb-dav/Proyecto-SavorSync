package co.edu.umb.foodies.backend.service;

import co.edu.umb.foodies.backend.dto.PostDTO;
import co.edu.umb.foodies.backend.model.Notification;
import co.edu.umb.foodies.backend.model.Post;
import co.edu.umb.foodies.backend.model.User;
import co.edu.umb.foodies.backend.repository.NotificationRepository;
import co.edu.umb.foodies.backend.repository.PostRepository;
import co.edu.umb.foodies.backend.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class PostService {

    private final PostRepository postRepository;
    private final UserRepository userRepository;
    private final NotificationRepository notificationRepository;

    @Transactional(readOnly = true)
    public List<PostDTO> getAllPosts(String currentUserId) {
        return postRepository.findAllByOrderByCreatedAtDesc().stream()
                .map(post -> convertToDTO(post, currentUserId))
                .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public List<PostDTO> getUserPosts(String userId, String currentUserId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("Usuario no encontrado"));
        return postRepository.findByUserOrderByCreatedAtDesc(user).stream()
                .map(post -> convertToDTO(post, currentUserId))
                .collect(Collectors.toList());
    }

    @Transactional
    public PostDTO createPost(PostDTO dto, String userId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("Usuario no encontrado"));
        
        Post post = Post.builder()
                .user(user)
                .restaurantName(dto.getRestaurantName())
                .restaurantAddress(dto.getRestaurantAddress())
                .contenido(dto.getContent())
                .rating(dto.getRating())
                .imageUrl(dto.getImageUrl())
                .build();
        
        post = postRepository.save(post);
        return convertToDTO(post, userId);
    }

    @Transactional
    public void toggleLike(String postId, String userId) {
        if (userId == null) return;
        Post post = postRepository.findById(postId)
                .orElseThrow(() -> new RuntimeException("Publicación no encontrada"));
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("Usuario no encontrado"));

        if (post.getLikedBy().contains(user)) {
            post.getLikedBy().remove(user);
        } else {
            post.getLikedBy().add(user);

            // Enviar notificacion automatica al autor de la reseña
            if (!post.getUser().getId().equals(userId)) {
                try {
                    notificationRepository.save(Notification.builder()
                            .clienteId(post.getUser().getId())
                            .type(Notification.NotificationType.like)
                            .title("¡A alguien le gusta tu reseña! ❤️")
                            .body("@" + user.getUsername() + " le ha dado Me Gusta a tu reseña sobre " + post.getRestaurantName())
                            .read(false)
                            .build());
                } catch (Exception e) {
                    System.err.println("WARN: Fallo al notificar Like: " + e.getMessage());
                }
            }
        }
        postRepository.save(post);
    }

    @Transactional
    public void deletePost(String postId, String userId) {
        Post post = postRepository.findById(postId)
                .orElseThrow(() -> new RuntimeException("Publicación no encontrada"));
        
        if (!post.getUser().getId().equals(userId)) {
            throw new RuntimeException("No tienes permiso para eliminar esta publicación");
        }
        postRepository.delete(post);
    }

    private PostDTO convertToDTO(Post post, String currentUserId) {
        return PostDTO.builder()
                .id(post.getId())
                .userId(post.getUser().getId())
                .username(post.getUser().getUsername())
                .fullName(post.getUser().getFullName())
                .userAvatarUrl(post.getUser().getAvatarUrl())
                .restaurantName(post.getRestaurantName())
                .restaurantAddress(post.getRestaurantAddress())
                .content(post.getContenido())
                .rating(post.getRating())
                .imageUrl(post.getImageUrl())
                .likesCount(post.getLikedBy() != null ? post.getLikedBy().size() : 0)
                .commentsCount(0)
                .likedByMe(post.getLikedBy() != null && post.getLikedBy().stream()
                        .anyMatch(u -> u.getId().equals(currentUserId)))
                .createdAt(post.getCreatedAt())
                .build();
    }
}
