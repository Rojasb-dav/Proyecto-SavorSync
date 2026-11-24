package co.edu.umb.foodies.backend.repository;

import co.edu.umb.foodies.backend.model.Restaurant;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface RestaurantRepository extends JpaRepository<Restaurant, String> {
    List<Restaurant> findByStatus(Restaurant.RestaurantStatus status);
    Optional<Restaurant> findByOwnerId(String ownerId);
}
