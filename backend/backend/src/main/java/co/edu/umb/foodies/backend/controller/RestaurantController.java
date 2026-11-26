package co.edu.umb.foodies.backend.controller;

import co.edu.umb.foodies.backend.model.MenuItem;
import co.edu.umb.foodies.backend.model.Restaurant;
import co.edu.umb.foodies.backend.repository.MenuItemRepository;
import co.edu.umb.foodies.backend.repository.RestaurantRepository;
import co.edu.umb.foodies.backend.repository.UserRepository;
import co.edu.umb.foodies.backend.model.User;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.time.LocalDateTime;
import java.util.List;

@RestController
@RequestMapping("/api/v1/restaurants")
@RequiredArgsConstructor
public class RestaurantController {

    private final RestaurantRepository restaurantRepository;
    private final MenuItemRepository menuItemRepository;
    private final UserRepository userRepository;

    @GetMapping
    public ResponseEntity<List<Restaurant>> getAllRestaurants(HttpServletRequest request) {
        if (request.isUserInRole("MODERADOR") || request.isUserInRole("ADMIN_SISTEMA")) {
            return ResponseEntity.ok(restaurantRepository.findAll().stream().filter(r -> r.getDeactivatedAt() == null).toList());
        }
        if (request.isUserInRole("RESTAURANT_ADMIN")) {
            return ResponseEntity.ok(restaurantRepository.findByStatusOrOwnerId(
                    Restaurant.RestaurantStatus.activo, request.getUserPrincipal().getName())
                    .stream().filter(r -> r.getDeactivatedAt() == null).toList());
        }
        return ResponseEntity.ok(restaurantRepository.findByStatus(Restaurant.RestaurantStatus.activo));
    }

    @GetMapping("/{id}")
    public ResponseEntity<Restaurant> getRestaurantById(@PathVariable String id, HttpServletRequest request) {
        return restaurantRepository.findById(id).filter(restaurant -> canView(restaurant, request))
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @Transactional
    @PostMapping
    public ResponseEntity<Restaurant> createRestaurant(@RequestBody Restaurant restaurant, HttpServletRequest request) {
        restaurant.setId(null);
        restaurant.setOwnerId(requireEligibleOwner(request.getUserPrincipal().getName()).getId());
        restaurant.setCreatedAt(null);
        restaurant.setStatus(Restaurant.RestaurantStatus.pendiente);
        requireRestaurantFields(restaurant);
        restaurant.setRatingAverage(null);
        restaurant.setReviewsCount(null);
        return ResponseEntity.status(HttpStatus.CREATED).body(restaurantRepository.save(restaurant));
    }

    @Transactional
    @PutMapping("/{id}")
    public ResponseEntity<Restaurant> updateRestaurant(@PathVariable String id, @RequestBody Restaurant body, HttpServletRequest request) {
        Restaurant r = requireEditableRestaurant(id, request);
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
        requireRestaurantFields(r);
        return ResponseEntity.ok(r);
    }

    @Transactional
    @PutMapping("/{id}/status")
    public ResponseEntity<Restaurant> updateStatus(@PathVariable String id, @RequestBody Restaurant body,
                                                    HttpServletRequest request) {
        Restaurant.RestaurantStatus status = body.getStatus();
        if (status == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Estado no especificado");
        }
        if (status == Restaurant.RestaurantStatus.activo) {
            // Use the same account-before-restaurant lock order as account deactivation.
            String ownerId = restaurantRepository.findOwnerId(id)
                    .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Restaurante no encontrado"));
            requireEligibleOwner(ownerId);
        }
        Restaurant restaurant = lockRestaurant(id);
        requireNotDeactivated(restaurant);
        restaurant.setStatus(status);
        if (status == Restaurant.RestaurantStatus.activo) {
            restaurant.setApprovedBy(request.getUserPrincipal().getName());
            restaurant.setApprovedAt(LocalDateTime.now());
        }
        return ResponseEntity.ok(restaurant);
    }

    @Transactional
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteRestaurant(@PathVariable String id, HttpServletRequest request) {
        if (request.isUserInRole("RESTAURANT_ADMIN")) {
            requireEligibleOwner(request.getUserPrincipal().getName());
        }
        Restaurant restaurant = lockRestaurant(id);
        if (!request.isUserInRole("ADMIN_SISTEMA") && !isOwner(restaurant, request)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "No puedes desactivar este restaurante");
        }

        if (restaurant.getDeactivatedAt() == null) {
            restaurant.setDeactivatedAt(LocalDateTime.now());
            restaurant.setStatus(Restaurant.RestaurantStatus.suspendido);
        }
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/{id}/menu")
    public ResponseEntity<List<MenuItem>> getMenu(@PathVariable String id, HttpServletRequest request) {
        restaurantRepository.findById(id).filter(r -> canView(r, request))
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Restaurante no encontrado"));
        return ResponseEntity.ok(menuItemRepository.findByRestaurantId(id));
    }

    @Transactional
    @PostMapping("/{id}/menu")
    public ResponseEntity<MenuItem> createMenuItem(@PathVariable String id, @RequestBody MenuItem item,
                                                   HttpServletRequest request) {
        requireEditableRestaurant(id, request);
        item.setId(null);
        item.setCreatedAt(null);
        item.setRestaurantId(id);
        return ResponseEntity.status(HttpStatus.CREATED).body(menuItemRepository.save(item));
    }

    @Transactional
    @PutMapping("/{id}/menu/{itemId}")
    public ResponseEntity<MenuItem> updateMenuItem(@PathVariable String id, @PathVariable String itemId, @RequestBody MenuItem body, HttpServletRequest request) {
        requireEditableRestaurant(id, request);
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

    @Transactional
    @DeleteMapping("/{id}/menu/{itemId}")
    public ResponseEntity<Void> deleteMenuItem(@PathVariable String id, @PathVariable String itemId, HttpServletRequest request) {
        requireEditableRestaurant(id, request);
        MenuItem item = menuItemRepository.findById(itemId).filter(i -> i.getRestaurantId().equals(id))
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Plato no encontrado"));
        menuItemRepository.delete(item);
        return ResponseEntity.noContent().build();
    }

    private boolean canView(Restaurant restaurant, HttpServletRequest request) {
        return restaurant.getDeactivatedAt() == null
                && (restaurant.getStatus() == Restaurant.RestaurantStatus.activo
                    || isOwner(restaurant, request)
                    || request.isUserInRole("MODERADOR")
                    || request.isUserInRole("ADMIN_SISTEMA"));
    }

    private User requireEligibleOwner(String id) {
        return userRepository.findByIdForUpdate(id)
                .filter(user -> user.getRole() == User.Role.restaurant_admin
                        && Boolean.TRUE.equals(user.getIsActive())
                        && Boolean.TRUE.equals(user.getEmailVerified()))
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.FORBIDDEN, "Propietario no habilitado"));
    }

    private Restaurant requireEditableRestaurant(String id, HttpServletRequest request) {
        requireEligibleOwner(request.getUserPrincipal().getName());
        Restaurant restaurant = lockRestaurant(id);
        if (!isOwner(restaurant, request)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "No puedes modificar este restaurante");
        }
        requireNotDeactivated(restaurant);
        return restaurant;
    }

    private Restaurant lockRestaurant(String id) {
        return restaurantRepository.findByIdForUpdate(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Restaurante no encontrado"));
    }

    private static void requireNotDeactivated(Restaurant restaurant) {
        if (restaurant.getDeactivatedAt() != null) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "El restaurante está desactivado");
        }
    }

    private static void requireRestaurantFields(Restaurant restaurant) {
        if (restaurant.getName() == null || restaurant.getName().isBlank()
                || restaurant.getAddress() == null || restaurant.getAddress().isBlank()
                || restaurant.getCategory() == null || restaurant.getCategory().isBlank()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Nombre, dirección y categoría son obligatorios");
        }
    }

    private boolean isOwner(Restaurant restaurant, HttpServletRequest request) {
        return request.isUserInRole("RESTAURANT_ADMIN")
                && request.getUserPrincipal().getName().equals(restaurant.getOwnerId());
    }
}
