package co.edu.umb.foodies.backend.repository;

import co.edu.umb.foodies.backend.model.ClientSession;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface ClientSessionRepository extends JpaRepository<ClientSession, String> {
    Optional<ClientSession> findBySessionTokenAndIsActiveTrue(String sessionToken);
}
