package co.edu.umb.foodies.backend.service;

import co.edu.umb.foodies.backend.dto.PostDTO;
import co.edu.umb.foodies.backend.model.Like;
import co.edu.umb.foodies.backend.model.Notification;
import co.edu.umb.foodies.backend.model.Post;
import co.edu.umb.foodies.backend.model.User;
import co.edu.umb.foodies.backend.repository.LikeRepository;
import co.edu.umb.foodies.backend.repository.NotificationRepository;
import co.edu.umb.foodies.backend.repository.PostRepository;
import co.edu.umb.foodies.backend.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class PostService {

    private final PostRepository postRepository;
    private final UserRepository userRepository;
    private final NotificationRepository notificationRepository;
    private final LikeRepository likeRepository;

    @Transactional(readOnly = true)
    public List<PostDTO> getAllPosts(String currentUserId) {
        return postRepository.findAllByOrderByCreatedAtDesc().stream()
                .filter(post -> canView(post, currentUserId))
                .map(post -> convertToDTO(post, currentUserId))
                .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public List<PostDTO> getUserPosts(String userId, String currentUserId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Usuario no encontrado"));
        return postRepository.findByUserOrderByCreatedAtDesc(user).stream()
                .filter(post -> canView(post, currentUserId))
                .map(post -> convertToDTO(post, currentUserId))
                .collect(Collectors.toList());
    }

    @Transactional
    public PostDTO createPost(PostDTO dto, String targetUserId) {
        if (targetUserId == null || targetUserId.isBlank()) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Debes iniciar sesión");
        }
        String finalUserId = targetUserId;
        User user = userRepository.findById(finalUserId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Usuario no encontrado con ID: " + finalUserId));
        
        Post post = Post.builder()
                .id(UUID.randomUUID().toString())
                .user(user)
                .restaurantName(dto.getRestaurantName() != null ? dto.getRestaurantName() : "Restaurante Bogotá")
                .restaurantAddress(dto.getRestaurantAddress())
                .contenido(dto.getContent() != null ? dto.getContent() : "Reseña gastronómica")
                .rating(dto.getRating() != null ? dto.getRating() : 5.0)
                .imageUrl(dto.getImageUrl())
                .status(Post.PostStatus.publicada)
                .isPublic(true)
                .likesCount(0)
                .commentsCount(0)
                .createdAt(LocalDateTime.now())
                .updatedAt(LocalDateTime.now())
                .build();
        
        post = postRepository.save(post);
        return convertToDTO(post, finalUserId);
    }

    @Transactional(readOnly = true)
    public void requireVisiblePost(String postId, String viewerId) {
        if (postRepository.countVisiblePost(postId, viewerId, Post.PostStatus.publicada) == 0) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Publicación no encontrada");
        }
    }

    private boolean canView(Post post, String viewerId) {
        return (Boolean.TRUE.equals(post.getIsPublic()) && post.getStatus() == Post.PostStatus.publicada)
                || (viewerId != null && post.getUser() != null && viewerId.equals(post.getUser().getId()));
    }

    @Transactional
    public void toggleLike(String postId, String userId) {
        Post post = postRepository.findById(postId).filter(p -> canView(p, userId))
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Publicación no encontrada"));
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Usuario no encontrado"));

        boolean exists = likeRepository.existsByPostIdAndClienteId(postId, userId);
        if (exists) {
            likeRepository.deleteByPostIdAndClienteId(postId, userId);
        } else {
            Like like = Like.builder()
                    .id(UUID.randomUUID().toString())
                    .postId(postId)
                    .clienteId(userId)
                    .createdAt(LocalDateTime.now())
                    .build();
            likeRepository.save(like);

            if (post.getUser() != null && !post.getUser().getId().equals(userId)) {
                try {
                    notificationRepository.save(Notification.builder()
                            .id(UUID.randomUUID().toString())
                            .clienteId(post.getUser().getId())
                            .type(Notification.NotificationType.like)
                            .title("¡A alguien le gusta tu reseña! ❤️")
                            .body("@" + user.getUsername() + " le ha dado Me Gusta a tu reseña sobre " + post.getRestaurantName())
                            .read(false)
                            .channel(Notification.Channel.in_app)
                            .createdAt(LocalDateTime.now())
                            .build());
                } catch (Exception e) {
                    System.err.println("WARN: Fallo al notificar Like: " + e.getMessage());
                }
            }
        }
        int newLikesCount = (int) likeRepository.countByPostId(postId);
        post.setLikesCount(newLikesCount);
        postRepository.save(post);
    }

    @Transactional
    public void deletePost(String postId, String userId) {
        Post post = postRepository.findById(postId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Publicación no encontrada"));
        
        if (!post.getUser().getId().equals(userId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "No tienes permiso para eliminar esta publicación");
        }
        likeRepository.deleteByPostIdAndClienteId(postId, userId);
        postRepository.delete(post);
    }

    private PostDTO convertToDTO(Post post, String currentUserId) {
        int likesCount = (post.getLikesCount() != null) ? post.getLikesCount() : (int) likeRepository.countByPostId(post.getId());
        boolean likedByMe = currentUserId != null && likeRepository.existsByPostIdAndClienteId(post.getId(), currentUserId);

        return PostDTO.builder()
                .id(post.getId())
                .userId(post.getUser() != null ? post.getUser().getId() : "")
                .username(post.getUser() != null ? post.getUser().getUsername() : "")
                .fullName(post.getUser() != null ? post.getUser().getFullName() : "")
                .userAvatarUrl(post.getUser() != null ? post.getUser().getAvatarUrl() : null)
                .restaurantName(post.getRestaurantName())
                .restaurantAddress(post.getRestaurantAddress())
                .content(post.getContenido())
                .rating(post.getRating())
                .imageUrl(post.getImageUrl())
                .likesCount(likesCount)
                .commentsCount(post.getCommentsCount() != null ? post.getCommentsCount() : 0)
                .likedByMe(likedByMe)
                .createdAt(post.getCreatedAt())
                .build();
    }
}
