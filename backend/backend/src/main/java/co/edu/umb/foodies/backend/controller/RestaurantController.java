package co.edu.umb.foodies.backend.controller;

import co.edu.umb.foodies.backend.model.MenuItem;
import co.edu.umb.foodies.backend.model.Restaurant;
import co.edu.umb.foodies.backend.repository.MenuItemRepository;
import co.edu.umb.foodies.backend.repository.ReservationRepository;
import co.edu.umb.foodies.backend.repository.RestaurantRepository;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;

@RestController
@RequestMapping("/api/v1/restaurants")
@RequiredArgsConstructor
public class RestaurantController {

    private final RestaurantRepository restaurantRepository;
    private final MenuItemRepository menuItemRepository;
    private final ReservationRepository reservationRepository;

    @GetMapping
    public ResponseEntity<List<Restaurant>> getAllRestaurants(HttpServletRequest request) {
        if (request.isUserInRole("MODERADOR") || request.isUserInRole("ADMIN_SISTEMA")) {
            return ResponseEntity.ok(restaurantRepository.findAll());
        }
        if (request.isUserInRole("RESTAURANT_ADMIN")) {
            return ResponseEntity.ok(restaurantRepository.findByStatusOrOwnerId(
                    Restaurant.RestaurantStatus.activo, request.getUserPrincipal().getName()));
        }
        return ResponseEntity.ok(restaurantRepository.findByStatus(Restaurant.RestaurantStatus.activo));
    }

    @GetMapping("/{id}")
    public ResponseEntity<Restaurant> getRestaurantById(@PathVariable String id, HttpServletRequest request) {
        return restaurantRepository.findById(id).filter(restaurant -> canView(restaurant, request))
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @PostMapping
    public ResponseEntity<Restaurant> createRestaurant(@RequestBody Restaurant restaurant, HttpServletRequest request) {
        restaurant.setId(null);
        restaurant.setOwnerId(request.getUserPrincipal().getName());
        restaurant.setStatus(Restaurant.RestaurantStatus.pendiente);
        restaurant.setRatingAverage(null);
        restaurant.setReviewsCount(null);
        return ResponseEntity.status(HttpStatus.CREATED).body(restaurantRepository.save(restaurant));
    }

    @PutMapping("/{id}/status")
    public ResponseEntity<Restaurant> updateStatus(@PathVariable String id, @RequestBody Restaurant body) {
        return restaurantRepository.findById(id).map(r -> {
            if (body.getStatus() != null) {
                r.setStatus(body.getStatus());
            }
            return ResponseEntity.ok(restaurantRepository.save(r));
        }).orElse(ResponseEntity.notFound().build());
    }

    @Transactional
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteRestaurant(@PathVariable String id, HttpServletRequest request) {
        Restaurant restaurant = restaurantRepository.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Restaurante no encontrado"));

        if (!request.isUserInRole("ADMIN_SISTEMA") && !isOwner(restaurant, request)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "No puedes eliminar este restaurante");
        }
        try {
            menuItemRepository.findByRestaurantId(id).forEach(menuItemRepository::delete);
            reservationRepository.findByRestaurantId(id).forEach(reservationRepository::delete);
            restaurantRepository.delete(restaurant);
            return ResponseEntity.noContent().build();
        } catch (Exception e) {
            System.err.println("WARN: Error al borrar restaurante: " + e.getMessage());
            return ResponseEntity.status(500).build();
        }
    }

    @GetMapping("/{id}/menu")
    public ResponseEntity<List<MenuItem>> getMenu(@PathVariable String id, HttpServletRequest request) {
        restaurantRepository.findById(id).filter(r -> canView(r, request))
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Restaurante no encontrado"));
        return ResponseEntity.ok(menuItemRepository.findByRestaurantId(id));
    }

    @PostMapping("/{id}/menu")
    public ResponseEntity<MenuItem> createMenuItem(@PathVariable String id, @RequestBody MenuItem item,
                                                   HttpServletRequest request) {
        if (restaurantRepository.findById(id).filter(r -> isOwner(r, request)).isEmpty()) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "No puedes gestionar este menú");
        }
        item.setId(null);
        item.setRestaurantId(id);
        return ResponseEntity.status(HttpStatus.CREATED).body(menuItemRepository.save(item));
    }

    private boolean canView(Restaurant restaurant, HttpServletRequest request) {
        return restaurant.getStatus() == Restaurant.RestaurantStatus.activo
                || isOwner(restaurant, request)
                || request.isUserInRole("MODERADOR")
                || request.isUserInRole("ADMIN_SISTEMA");
    }

    private boolean isOwner(Restaurant restaurant, HttpServletRequest request) {
        return request.isUserInRole("RESTAURANT_ADMIN")
                && request.getUserPrincipal().getName().equals(restaurant.getOwnerId());
    }
}
