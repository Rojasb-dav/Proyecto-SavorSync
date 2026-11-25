package co.edu.umb.foodies.backend.repository;

import co.edu.umb.foodies.backend.model.EmployeeSession;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface EmployeeSessionRepository extends JpaRepository<EmployeeSession, String> {
    Optional<EmployeeSession> findBySessionTokenAndIsActiveTrue(String sessionToken);
}
