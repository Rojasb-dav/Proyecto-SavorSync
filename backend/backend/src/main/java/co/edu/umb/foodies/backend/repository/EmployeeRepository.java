package co.edu.umb.foodies.backend.repository;

import co.edu.umb.foodies.backend.model.Employee;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface EmployeeRepository extends JpaRepository<Employee, String> {
    Optional<Employee> findByEmail(String email);
    Optional<Employee> findByUsername(String username);
    boolean existsByEmail(String email);
    boolean existsByUsername(String username);
}
