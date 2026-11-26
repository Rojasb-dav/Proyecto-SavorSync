package co.edu.umb.foodies.backend.repository;

import co.edu.umb.foodies.backend.model.Reservation;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import java.util.Optional;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface ReservationRepository extends JpaRepository<Reservation, String> {
    List<Reservation> findByClienteId(String clienteId);
    List<Reservation> findByRestaurantId(String restaurantId);
    @Query("select r.restaurantId from Reservation r where r.id = :id")
    Optional<String> findRestaurantId(String id);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select r from Reservation r where r.id = :id")
    Optional<Reservation> findByIdForUpdate(String id);
}
