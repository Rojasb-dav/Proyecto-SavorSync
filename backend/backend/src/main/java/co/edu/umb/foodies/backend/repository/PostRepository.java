package co.edu.umb.foodies.backend.repository;

import co.edu.umb.foodies.backend.model.Post;
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
    @Query("""
            select p from Post p join fetch p.user author left join fetch p.images
            where p.deletedAt is null and author.isActive = true and author.emailVerified = true
              and ((p.isPublic = true and p.status = :publicStatus) or author.id = :viewerId)
              and (:authorId is null or author.id = :authorId)
            order by p.createdAt desc
            """)
    List<Post> findVisibleFeed(String authorId, String viewerId, Post.PostStatus publicStatus);


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
