package co.edu.umb.foodies.backend.repository;

import co.edu.umb.foodies.backend.model.Pqrs;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface PqrsRepository extends JpaRepository<Pqrs, String> {
    List<Pqrs> findByClienteId(String clienteId);
}
