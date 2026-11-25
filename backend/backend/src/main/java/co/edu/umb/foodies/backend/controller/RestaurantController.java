package co.edu.umb.foodies.backend.controller;

import co.edu.umb.foodies.backend.model.MenuItem;
import co.edu.umb.foodies.backend.model.Restaurant;
import co.edu.umb.foodies.backend.repository.MenuItemRepository;
import co.edu.umb.foodies.backend.repository.ReservationRepository;
import co.edu.umb.foodies.backend.repository.RestaurantRepository;
import co.edu.umb.foodies.backend.repository.PostRepository;
import co.edu.umb.foodies.backend.repository.RestaurantImageRepository;
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
    private final PostRepository postRepository;
    private final RestaurantImageRepository restaurantImageRepository;

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

    @PutMapping("/{id}")
    public ResponseEntity<Restaurant> updateRestaurant(@PathVariable String id, @RequestBody Restaurant body, HttpServletRequest request) {
        return restaurantRepository.findById(id).map(r -> {
            if (!isOwner(r, request)) {
                throw new ResponseStatusException(HttpStatus.FORBIDDEN, "No puedes modificar este restaurante");
            }
            if (body.getName() != null) r.setName(body.getName());
            if (body.getDescription() != null) r.setDescription(body.getDescription());
            if (body.getAddress() != null) r.setAddress(body.getAddress());
            if (body.getCity() != null) r.setCity(body.getCity());
            if (body.getPhone() != null) r.setPhone(body.getPhone());
            if (body.getEmail() != null) r.setEmail(body.getEmail());
            if (body.getWebsite() != null) r.setWebsite(body.getWebsite());
            if (body.getCategory() != null) r.setCategory(body.getCategory());
            if (body.getPriceRange() != null) r.setPriceRange(body.getPriceRange());
            if (body.getLatitude() != null) r.setLatitude(body.getLatitude());
            if (body.getLongitude() != null) r.setLongitude(body.getLongitude());
            return ResponseEntity.ok(restaurantRepository.save(r));
        }).orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Restaurante no encontrado"));
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

        menuItemRepository.findByRestaurantId(id).forEach(menuItemRepository::delete);
        reservationRepository.findByRestaurantId(id).forEach(reservationRepository::delete);

        // Limpiar FKs en publicaciones y borrar imagenes del restaurante
        postRepository.findByRestaurantId(id).forEach(post -> {
            post.setRestaurantId(null);
            postRepository.save(post);
        });
        restaurantImageRepository.findByRestaurantId(id).forEach(restaurantImageRepository::delete);

        restaurantRepository.delete(restaurant);
        return ResponseEntity.noContent().build();
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

    @PutMapping("/{id}/menu/{itemId}")
    public ResponseEntity<MenuItem> updateMenuItem(@PathVariable String id, @PathVariable String itemId, @RequestBody MenuItem body, HttpServletRequest request) {
        if (restaurantRepository.findById(id).filter(r -> isOwner(r, request)).isEmpty()) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "No puedes gestionar este menú");
        }
        return menuItemRepository.findById(itemId).filter(item -> item.getRestaurantId().equals(id)).map(item -> {
            if (body.getName() != null) item.setName(body.getName());
            if (body.getDescription() != null) item.setDescription(body.getDescription());
            if (body.getCategory() != null) item.setCategory(body.getCategory());
            if (body.getPrice() != null) item.setPrice(body.getPrice());
            if (body.getIsAvailable() != null) item.setIsAvailable(body.getIsAvailable());
            if (body.getOrder() != null) item.setOrder(body.getOrder());
            return ResponseEntity.ok(menuItemRepository.save(item));
        }).orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Plato no encontrado"));
    }

    @DeleteMapping("/{id}/menu/{itemId}")
    public ResponseEntity<Void> deleteMenuItem(@PathVariable String id, @PathVariable String itemId, HttpServletRequest request) {
        if (restaurantRepository.findById(id).filter(r -> isOwner(r, request)).isEmpty()) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "No puedes gestionar este menú");
        }
        MenuItem item = menuItemRepository.findById(itemId).filter(i -> i.getRestaurantId().equals(id))
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Plato no encontrado"));
        menuItemRepository.delete(item);
        return ResponseEntity.noContent().build();
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
