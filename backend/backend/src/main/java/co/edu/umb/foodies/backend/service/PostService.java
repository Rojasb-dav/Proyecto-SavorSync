package co.edu.umb.foodies.backend.service;

import co.edu.umb.foodies.backend.dto.PostDTO;
import co.edu.umb.foodies.backend.model.Post;
import co.edu.umb.foodies.backend.model.User;
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

    @Transactional(readOnly = true)
    public List<PostDTO> getAllPosts(String currentUserId) {
        return postRepository.findAllByOrderByCreatedAtDesc().stream()
                .map(post -> convertToDTO(post, currentUserId))
                .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public List<PostDTO> getUserPosts(String userId, String currentUserId) {
        User user = userRepository.findById(userId).orElseThrow();
        return postRepository.findByUserOrderByCreatedAtDesc(user).stream()
                .map(post -> convertToDTO(post, currentUserId))
                .collect(Collectors.toList());
    }

    @Transactional
    public PostDTO createPost(PostDTO dto, String userId) {
        User user = userRepository.findById(userId).orElseThrow();
        Post post = Post.builder()
                .user(user)
                .restaurantName(dto.getRestaurantName())
                .restaurantAddress(dto.getRestaurantAddress())
                .content(dto.getContent())
                .rating(dto.getRating())
                .imageUrl(dto.getImageUrl())
                .build();
        
        post = postRepository.save(post);
        return convertToDTO(post, userId);
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
                .content(post.getContent())
                .rating(post.getRating())
                .imageUrl(post.getImageUrl())
                .likesCount(post.getLikedBy() != null ? post.getLikedBy().size() : 0)
                .commentsCount(0) // Comentarios no implementados aún
                .likedByMe(post.getLikedBy() != null && post.getLikedBy().stream()
                        .anyMatch(u -> u.getId().equals(currentUserId)))
                .createdAt(post.getCreatedAt())
                .build();
    }
}
