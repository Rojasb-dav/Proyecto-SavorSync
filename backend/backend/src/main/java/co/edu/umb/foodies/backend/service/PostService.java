package co.edu.umb.foodies.backend.service;

import co.edu.umb.foodies.backend.dto.PostDTO;
import co.edu.umb.foodies.backend.dto.CommentDTO;
import co.edu.umb.foodies.backend.model.Comment;
import co.edu.umb.foodies.backend.repository.CommentRepository;
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
import java.util.Objects;
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
    private final CommentRepository comments;

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
        User user = requireFoodieForUpdate(targetUserId);
        String restaurantId = resolveRestaurantId(dto);

        Double rating = dto.getRating();
        if (rating != null && (!Double.isFinite(rating) || rating < 1 || rating > 5 || rating != Math.rint(rating))) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "La calificación debe ser un entero de 1 a 5");
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
                    .post(post)
                .clientId(user.getId())
                .url(dto.getImageUrl())
                .orderIndex(0)
                .createdAt(LocalDateTime.now())
                .build();
            post.setImages(new ArrayList<>(List.of(img)));
        } else {
            post.setImages(new ArrayList<>());
        }

        post = postRepository.saveAndFlush(post);
        if (dto.getImageUrl() != null && !dto.getImageUrl().isBlank()
                && !assetRegistry.attachIfOwned("client", user.getId(), dto.getImageUrl(), "post", post.getId())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN,
                    "La imagen no pertenece a tu cuenta o ya está asociada a otro recurso.");
        }

        return convertToDTO(post, user.getId());
    }

    private String resolveRestaurantId(PostDTO dto) {
        if (dto.getRestaurantId() != null && !dto.getRestaurantId().isBlank()) {
            return restaurantRepository.findByIdForUpdate(dto.getRestaurantId())
                    .filter(restaurant -> restaurant.getStatus() == Restaurant.RestaurantStatus.activo
                            && restaurant.getDeactivatedAt() == null)
                    .map(Restaurant::getId)
                    .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND,
                            "Restaurante no encontrado o no disponible"));
        }
        if (dto.getRestaurantName() == null) return null;
        List<String> candidates = restaurantRepository.findActiveIdsByNameForUpdate(dto.getRestaurantName());
        return candidates.size() == 1 ? candidates.get(0) : null;
    }

    @Transactional(readOnly = true)
    public List<CommentDTO> getComments(String postId, String viewerId) {
        requireVisiblePost(postId, viewerId);
        return comments.findByPostId(postId).stream()
                .filter(comment -> "activo".equals(comment.getStatus()))
                .map(comment -> userRepository.findById(comment.getClienteId())
                        .filter(user -> Boolean.TRUE.equals(user.getIsActive()))
                        .map(user -> CommentDTO.from(comment, user)).orElse(null))
                .filter(Objects::nonNull)
                .toList();
    }

    private void requireVisiblePost(String postId, String viewerId) {
        if (postRepository.countVisiblePost(postId, viewerId, Post.PostStatus.publicada) == 0) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Publicación no encontrada");
        }
    }

    private User requireFoodieForUpdate(String userId) {
        return userRepository.findByIdForUpdate(userId)
                .filter(user -> user.getRole() == User.Role.foodie && Boolean.TRUE.equals(user.getIsActive())
                        && Boolean.TRUE.equals(user.getEmailVerified()))
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.FORBIDDEN,
                        "Esta operación está disponible para cuentas Foodie verificadas."));
    }

    private boolean canView(Post post, String viewerId) {
        if (post.getDeletedAt() != null) return false;
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
        User user = requireFoodieForUpdate(userId);
        Post post = lockVisiblePost(postId, userId);

        boolean exists = likeRepository.findIdForUpdate(postId, userId).isPresent();
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

            if (!post.getUser().getId().equals(userId)) {
                notifyAuthor(post, Notification.NotificationType.like, "Nuevo Me Gusta en tu reseña",
                        "@" + user.getUsername() + " le ha dado Me Gusta a tu reseña.");
            }
        }
        // The post lock serializes deltas, independently of the transaction's read snapshot.
        int previous = post.getLikesCount() == null ? 0 : post.getLikesCount();
        post.setLikesCount(exists ? Math.max(0, previous - 1) : previous + 1);
    }

    @Transactional
    public CommentDTO addComment(String postId, String userId, String content, String parentId) {
        if (content.isBlank() || content.length() > 200) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "El comentario debe contener entre 1 y 200 caracteres.");
        }
        User author = requireFoodieForUpdate(userId);
        Post post = lockVisiblePost(postId, userId);
        if (parentId != null && comments.findById(parentId)
                .filter(parent -> postId.equals(parent.getPostId()) && "activo".equals(parent.getStatus()))
                .isEmpty()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "El comentario padre no pertenece a esta publicación o no está disponible.");
        }

        Comment saved = comments.save(Comment.builder()
                .id(UUID.randomUUID().toString())
                .postId(postId)
                .clienteId(author.getId())
                .parentId(parentId)
                .content(content)
                .status("activo")
                .createdAt(LocalDateTime.now())
                .updatedAt(LocalDateTime.now())
                .build());
        post.setCommentsCount((post.getCommentsCount() == null ? 0 : post.getCommentsCount()) + 1);
        if (!post.getUser().getId().equals(userId)) {
            notifyAuthor(post, Notification.NotificationType.comentario, "Nuevo comentario en tu reseña",
                    "@" + author.getUsername() + " comentó: \"" + content + "\"");
        }
        return CommentDTO.from(saved, author);
    }

    private void notifyAuthor(Post post, Notification.NotificationType type, String title, String body) {
        notificationRepository.save(Notification.builder()
                .id(UUID.randomUUID().toString())
                .clienteId(post.getUser().getId())
                .type(type)
                .title(title)
                .body(body)
                .read(false)
                .channel(Notification.Channel.in_app)
                .createdAt(LocalDateTime.now())
                .build());
    }

    private Post lockVisiblePost(String postId, String viewerId) {
        return postRepository.findByIdForUpdate(postId).filter(post -> canView(post, viewerId))
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Publicación no encontrada"));
    }

    @Transactional
    public void deletePost(String postId, String userId) {
        requireFoodieForUpdate(userId);
        Post post = postRepository.findByIdForUpdate(postId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Publicación no encontrada"));

        if (!post.getUser().getId().equals(userId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "No tienes permiso para eliminar esta publicación");
        }
        if (post.getDeletedAt() == null) {
            post.setDeletedAt(LocalDateTime.now());
            post.setIsPublic(false);
            post.setStatus(Post.PostStatus.oculta);
        }
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
                .restaurantId(rest != null ? rest.getId() : null)
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
