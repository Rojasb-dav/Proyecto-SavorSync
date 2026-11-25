package co.edu.umb.foodies.backend.repository;

import co.edu.umb.foodies.backend.model.EmployeeSession;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Optional;

public interface EmployeeSessionRepository extends JpaRepository<EmployeeSession, String> {
    Optional<EmployeeSession> findBySessionTokenAndIsActiveTrue(String sessionToken);

    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("update EmployeeSession s set s.isActive = false where s.employeeId = :employeeId and s.isActive = true")
    int revokeActiveByEmployeeId(@Param("employeeId") String employeeId);
}
