package co.edu.umb.foodies.backend.service;

import co.edu.umb.foodies.backend.dto.PostDTO;
import co.edu.umb.foodies.backend.model.Like;
import co.edu.umb.foodies.backend.model.Notification;
import co.edu.umb.foodies.backend.model.Post;
import co.edu.umb.foodies.backend.model.PostImage;
import co.edu.umb.foodies.backend.model.Restaurant;
import co.edu.umb.foodies.backend.model.User;
import co.edu.umb.foodies.backend.repository.LikeRepository;
import co.edu.umb.foodies.backend.repository.NotificationRepository;
import co.edu.umb.foodies.backend.repository.PostRepository;
import co.edu.umb.foodies.backend.repository.RestaurantRepository;
import co.edu.umb.foodies.backend.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class PostService {

    private final PostRepository postRepository;
    private final UserRepository userRepository;
    private final RestaurantRepository restaurantRepository;
    private final NotificationRepository notificationRepository;
    private final LikeRepository likeRepository;
    private final CloudinaryAssetRegistry assetRegistry;

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
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Usuario no encontrado"));
        requireFoodie(user);

        String restaurantId = null;
        if (dto.getRestaurantName() != null) {
            // Buscamos un restaurante por nombre para el demo
            Restaurant rest = restaurantRepository.findAll().stream()
                .filter(r -> r.getName().equalsIgnoreCase(dto.getRestaurantName())
                        && r.getStatus() == Restaurant.RestaurantStatus.activo)
                .findFirst().orElse(null);
            if (rest != null) {
                restaurantId = rest.getId();
            }
        }

        Post post = Post.builder()
                .id(UUID.randomUUID().toString())
                .user(user)
                .restaurantId(restaurantId)
                .contenido(dto.getContent() != null ? dto.getContent() : "Reseña gastronómica")
                .rating(dto.getRating() != null ? dto.getRating() : 5.0)
                .status(Post.PostStatus.publicada)
                .isPublic(true)
                .likesCount(0)
                .commentsCount(0)
                .createdAt(LocalDateTime.now())
                .updatedAt(LocalDateTime.now())
                .build();

        if (dto.getImageUrl() != null && !dto.getImageUrl().isBlank()) {
            PostImage img = PostImage.builder()
                .id(UUID.randomUUID().toString())
                .postId(post.getId())
                .clientId(user.getId())
                .url(dto.getImageUrl())
                .orderIndex(0)
                .createdAt(LocalDateTime.now())
                .build();
            post.setImages(new ArrayList<>(List.of(img)));
        } else {
            post.setImages(new ArrayList<>());
        }

        if (dto.getImageUrl() != null && !dto.getImageUrl().isBlank()
                && !assetRegistry.attachIfOwned("client", finalUserId, dto.getImageUrl(), "post", post.getId())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN,
                    "La imagen no pertenece a tu cuenta o ya está asociada a otro recurso.");
        }

        post = postRepository.save(post);
        return convertToDTO(post, finalUserId);
    }

    @Transactional(readOnly = true)
    public void requireVisiblePost(String postId, String viewerId) {
        if (postRepository.countVisiblePost(postId, viewerId, Post.PostStatus.publicada) == 0) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Publicación no encontrada");
        }
    }

    private static void requireFoodie(User user) {
        if (user.getRole() != User.Role.foodie) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN,
                    "Esta operación está disponible para cuentas Foodie.");
        }
    }

    private boolean canView(Post post, String viewerId) {
        User author = post.getUser();
        if (author == null || !Boolean.TRUE.equals(author.getIsActive())
                || !Boolean.TRUE.equals(author.getEmailVerified())) {
            return false;
        }
        return (Boolean.TRUE.equals(post.getIsPublic()) && post.getStatus() == Post.PostStatus.publicada)
                || (viewerId != null && viewerId.equals(author.getId()));
    }

    @Transactional
    public void toggleLike(String postId, String userId) {
        Post post = postRepository.findById(postId).filter(p -> canView(p, userId))
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Publicación no encontrada"));
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Usuario no encontrado"));
        requireFoodie(user);

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
                    Restaurant rest = post.getRestaurantId() != null ? restaurantRepository.findById(post.getRestaurantId()).orElse(null) : null;
                    String restName = rest != null ? rest.getName() : "un restaurante";
                    notificationRepository.save(Notification.builder()
                            .id(UUID.randomUUID().toString())
                            .clienteId(post.getUser().getId())
                            .type(Notification.NotificationType.like)
                            .title("¡A alguien le gusta tu reseña! ❤️")
                            .body("@" + user.getUsername() + " le ha dado Me Gusta a tu reseña sobre " + restName)
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

        Restaurant rest = null;
        if (post.getRestaurantId() != null) {
            rest = restaurantRepository.findById(post.getRestaurantId())
                    .filter(found -> found.getStatus() == Restaurant.RestaurantStatus.activo)
                    .orElse(null);
        }

        String img = (post.getImages() != null && !post.getImages().isEmpty()) ? post.getImages().get(0).getUrl() : null;

        return PostDTO.builder()
                .id(post.getId())
                .userId(post.getUser() != null ? post.getUser().getId() : "")
                .username(post.getUser() != null ? post.getUser().getUsername() : "")
                .fullName(post.getUser() != null ? post.getUser().getFullName() : "")
                .userAvatarUrl(post.getUser() != null ? post.getUser().getAvatarUrl() : null)
                .restaurantName(rest != null ? rest.getName() : null)
                .restaurantAddress(rest != null ? rest.getAddress() : null)
                .content(post.getContenido())
                .rating(post.getRating())
                .imageUrl(img)
                .likesCount(likesCount)
                .commentsCount(post.getCommentsCount() != null ? post.getCommentsCount() : 0)
                .likedByMe(likedByMe)
                .createdAt(post.getCreatedAt())
                .build();
    }
}
