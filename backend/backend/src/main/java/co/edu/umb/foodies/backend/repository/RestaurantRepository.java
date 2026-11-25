package co.edu.umb.foodies.backend.repository;

import co.edu.umb.foodies.backend.model.Restaurant;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface RestaurantRepository extends JpaRepository<Restaurant, String> {
    List<Restaurant> findByStatus(Restaurant.RestaurantStatus status);
    List<Restaurant> findAllByOwnerId(String ownerId);
    List<Restaurant> findByStatusOrOwnerId(Restaurant.RestaurantStatus status, String ownerId);
}
