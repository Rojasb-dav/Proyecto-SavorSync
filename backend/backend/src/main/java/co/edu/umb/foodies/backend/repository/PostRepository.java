package co.edu.umb.foodies.backend.repository;

import co.edu.umb.foodies.backend.model.Post;
import co.edu.umb.foodies.backend.model.User;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface PostRepository extends JpaRepository<Post, String> {
    List<Post> findByUserOrderByCreatedAtDesc(User user);
    List<Post> findAllByOrderByCreatedAtDesc();
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select p from Post p where p.id = :id")
    Optional<Post> findByIdForUpdate(String id);

    @Query("""
            select count(p) from Post p
            where p.id = :postId and p.deletedAt is null
              and p.user.isActive = true
              and p.user.emailVerified = true
              and ((p.isPublic = true and p.status = :publicStatus) or p.user.id = :viewerId)
            """)
    long countVisiblePost(@Param("postId") String postId, @Param("viewerId") String viewerId,
                          @Param("publicStatus") Post.PostStatus publicStatus);
}
