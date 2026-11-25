package co.edu.umb.foodies.backend.repository;

import co.edu.umb.foodies.backend.model.Pqrs;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface PqrsRepository extends JpaRepository<Pqrs, String> {
    List<Pqrs> findByClienteId(String clienteId);

    Optional<Pqrs> findFirstByClienteIdAndAsuntoAndEstadoIn(
            String clienteId, String asunto, List<Pqrs.PqrsStatus> estados);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select p from Pqrs p where p.id = :id")
    Optional<Pqrs> findByIdForUpdate(@Param("id") String id);
}
