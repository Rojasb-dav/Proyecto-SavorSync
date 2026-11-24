package co.edu.umb.foodies.backend.controller;

import co.edu.umb.foodies.backend.model.MenuItem;
import co.edu.umb.foodies.backend.model.Restaurant;
import co.edu.umb.foodies.backend.repository.MenuItemRepository;
import co.edu.umb.foodies.backend.repository.RestaurantRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/restaurants")
@RequiredArgsConstructor
public class RestaurantController {

    private final RestaurantRepository restaurantRepository;
    private final MenuItemRepository menuItemRepository;

    @GetMapping
    public ResponseEntity<List<Restaurant>> getAllRestaurants() {
        return ResponseEntity.ok(restaurantRepository.findAll());
    }

    @GetMapping("/{id}")
    public ResponseEntity<Restaurant> getRestaurantById(@PathVariable String id) {
        return restaurantRepository.findById(id)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @PostMapping
    public ResponseEntity<Restaurant> createRestaurant(@RequestBody Restaurant restaurant) {
        return ResponseEntity.ok(restaurantRepository.save(restaurant));
    }

    @PutMapping("/{id}/status")
    public ResponseEntity<Restaurant> updateStatus(@PathVariable String id, @RequestBody Restaurant body) {
        return restaurantRepository.findById(id).map(r -> {
            r.setStatus(body.getStatus());
            return ResponseEntity.ok(restaurantRepository.save(r));
        }).orElse(ResponseEntity.notFound().build());
    }

    @GetMapping("/{id}/menu")
    public ResponseEntity<List<MenuItem>> getMenu(@PathVariable String id) {
        return ResponseEntity.ok(menuItemRepository.findByRestaurantId(id));
    }

    @PostMapping("/{id}/menu")
    public ResponseEntity<MenuItem> createMenuItem(@PathVariable String id, @RequestBody MenuItem item) {
        item.setRestaurantId(id);
        return ResponseEntity.ok(menuItemRepository.save(item));
    }
}
