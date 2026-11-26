package co.edu.umb.foodies.backend.repository;

import co.edu.umb.foodies.backend.model.Follow;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;

public interface FollowRepository extends JpaRepository<Follow, String> {

    @Query(value = """
            SELECT id FROM seguidores
            WHERE seguidor_id = :followerId AND seguido_id = :followedId
            FOR UPDATE
            """, nativeQuery = true)
    java.util.Optional<String> findPairForUpdate(String followerId, String followedId);

    boolean existsByFollowerIdAndFollowedId(String followerId, String followedId);

    @Modifying
    @Query("delete from Follow f where f.follower.id = :followerId and f.followed.id = :followedId")
    void deletePair(String followerId, String followedId);
}
