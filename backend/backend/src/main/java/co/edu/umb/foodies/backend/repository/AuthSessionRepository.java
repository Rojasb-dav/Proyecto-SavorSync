package co.edu.umb.foodies.backend.repository;

import co.edu.umb.foodies.backend.model.AuthSession;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface AuthSessionRepository extends JpaRepository<AuthSession, String> {
    Optional<AuthSession> findBySessionTokenAndIsActiveTrue(String sessionToken);

    @Modifying(flushAutomatically = true)
    @Query("update AuthSession s set s.isActive = false where s.userId = :userId and s.isActive = true")
    int revokeAllByUserId(@Param("userId") String userId);
}
