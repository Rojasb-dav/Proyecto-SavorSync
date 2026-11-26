package co.edu.umb.foodies.backend.repository;

import co.edu.umb.foodies.backend.model.Like;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;

public interface LikeRepository extends JpaRepository<Like, String> {
    boolean existsByPostIdAndClienteId(String postId, String clienteId);
    Optional<Like> findByPostIdAndClienteId(String postId, String clienteId);

    @Modifying
    @Transactional
    void deleteByPostIdAndClienteId(String postId, String clienteId);

    @Query("select l.postId from Like l where l.clienteId = :viewerId and l.postId in :postIds")
    List<String> findLikedPostIds(String viewerId, List<String> postIds);

    @Query("""
            select l.postId as postId, count(l) as total from Like l
            where l.postId in :postIds group by l.postId
            """)
    List<PostLikeCount> countByPostIds(List<String> postIds);

    interface PostLikeCount {
        String getPostId();
        long getTotal();
    }

    @Query(value = """
            SELECT id FROM likes WHERE publicacion_id = :postId AND cliente_id = :clienteId FOR UPDATE
            """, nativeQuery = true)
    Optional<String> findIdForUpdate(String postId, String clienteId);
}
