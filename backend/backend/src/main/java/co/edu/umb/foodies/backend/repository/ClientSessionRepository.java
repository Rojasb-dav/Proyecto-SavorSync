package co.edu.umb.foodies.backend.repository;

import co.edu.umb.foodies.backend.model.ClientSession;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Optional;

public interface ClientSessionRepository extends JpaRepository<ClientSession, String> {
    Optional<ClientSession> findBySessionTokenAndIsActiveTrue(String sessionToken);

    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("update ClientSession s set s.isActive = false where s.userId = :userId and s.isActive = true")
    int revokeActiveByUserId(@Param("userId") String userId);
}
