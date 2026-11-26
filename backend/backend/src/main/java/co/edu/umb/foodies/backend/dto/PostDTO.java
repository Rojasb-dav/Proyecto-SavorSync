package co.edu.umb.foodies.backend.dto;

import com.fasterxml.jackson.annotation.JsonAlias;
import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.*;

import java.time.LocalDateTime;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class PostDTO {

    @JsonProperty("id")
    private String id;

    @JsonProperty("userId")
    @JsonAlias({"cliente_id", "userId", "user_id", "clienteId"})
    private String userId;

    @JsonProperty("username")
    private String username;

    @JsonProperty("fullName")
    @JsonAlias({"full_name", "fullName"})
    private String fullName;

    @JsonProperty("userAvatarUrl")
    @JsonAlias({"user_avatar_url", "userAvatarUrl", "avatarUrl"})
    private String userAvatarUrl;

    @JsonAlias({"restaurante_id", "restaurant_id"})
    private String restaurantId;

    @JsonProperty("restaurantName")
    @JsonAlias({"nombre_restaurante", "restaurantName", "restaurant_name"})
    private String restaurantName;

    @JsonProperty("restaurantAddress")
    @JsonAlias({"direccion_restaurante", "restaurantAddress", "restaurant_address"})
    private String restaurantAddress;

    @JsonProperty("content")
    @JsonAlias({"contenido", "content", "descripcion"})
    private String content;

    @JsonProperty("rating")
    @JsonAlias({"calificacion", "rating"})
    private Double rating;

    @JsonProperty("imageUrl")
    @JsonAlias({"url_imagen", "imageUrl", "image_url"})
    private String imageUrl;

    @JsonProperty("likesCount")
    @JsonAlias({"conteo_likes", "likesCount"})
    private int likesCount;

    @JsonProperty("commentsCount")
    @JsonAlias({"conteo_comentarios", "commentsCount"})
    private int commentsCount;

    @JsonProperty("likedByMe")
    private boolean likedByMe;

    @JsonProperty("savedByMe")
    private boolean savedByMe;

    @JsonProperty("createdAt")
    private LocalDateTime createdAt;
}
