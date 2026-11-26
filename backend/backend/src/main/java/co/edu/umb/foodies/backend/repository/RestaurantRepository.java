package co.edu.umb.foodies.backend.repository;

import co.edu.umb.foodies.backend.model.Restaurant;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface RestaurantRepository extends JpaRepository<Restaurant, String> {
    List<Restaurant> findByStatus(Restaurant.RestaurantStatus status);
    List<Restaurant> findAllByOwnerId(String ownerId);
    List<Restaurant> findByStatusOrOwnerId(Restaurant.RestaurantStatus status, String ownerId);
    @Query(value = """
            SELECT id FROM restaurantes
            WHERE nombre = :name AND estado = 'activo' AND deactivated_at IS NULL
            ORDER BY id LIMIT 2 FOR UPDATE
            """, nativeQuery = true)
    List<String> findActiveIdsByNameForUpdate(String name);

    @Query("select r.ownerId from Restaurant r where r.id = :id")
    Optional<String> findOwnerId(String id);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select r from Restaurant r where r.id = :id")
    Optional<Restaurant> findByIdForUpdate(String id);

    @Modifying
    @Query("""
            update Restaurant r set r.status = 'suspendido', r.updatedAt = CURRENT_TIMESTAMP
            where r.ownerId = :ownerId and r.status = 'activo'
            """)
    void suspendOwnedRestaurants(String ownerId);
}
