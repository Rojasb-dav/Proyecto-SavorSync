package co.edu.umb.foodies.backend.repository;

import co.edu.umb.foodies.backend.model.AuthSession;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface AuthSessionRepository extends JpaRepository<AuthSession, String> {
    Optional<AuthSession> findBySessionTokenAndIsActiveTrue(String sessionToken);
}
