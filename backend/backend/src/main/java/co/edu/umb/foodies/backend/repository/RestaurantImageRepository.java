package co.edu.umb.foodies.backend.repository;

import co.edu.umb.foodies.backend.model.RestaurantImage;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface RestaurantImageRepository extends JpaRepository<RestaurantImage, String> {
    List<RestaurantImage> findByRestaurantId(String restaurantId);
}
