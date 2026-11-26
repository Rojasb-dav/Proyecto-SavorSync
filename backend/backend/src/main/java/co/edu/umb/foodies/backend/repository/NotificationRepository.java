package co.edu.umb.foodies.backend.repository;

import co.edu.umb.foodies.backend.model.Notification;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface NotificationRepository extends JpaRepository<Notification, String> {
    List<Notification> findByClienteId(String clienteId);
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    Optional<Notification> findByIdAndClienteId(String id, String clienteId);
}
