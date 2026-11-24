package co.edu.umb.foodies.backend.repository;

import co.edu.umb.foodies.backend.model.Notification;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface NotificationRepository extends JpaRepository<Notification, String> {
    List<Notification> findByClienteId(String clienteId);
}
