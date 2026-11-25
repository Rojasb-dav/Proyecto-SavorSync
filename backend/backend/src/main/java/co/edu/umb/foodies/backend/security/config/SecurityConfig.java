package co.edu.umb.foodies.backend.security.config;

import co.edu.umb.foodies.backend.security.RestSecurityErrors;
import co.edu.umb.foodies.backend.security.jwt.JwtAuthenticationFilter;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.web.servlet.FilterRegistrationBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

import java.util.Arrays;
import java.util.List;

@Configuration
@RequiredArgsConstructor
public class SecurityConfig {

    private final JwtAuthenticationFilter jwtAuthenticationFilter;
    private final RestSecurityErrors securityErrors;

    @Bean
    public FilterRegistrationBean<JwtAuthenticationFilter> jwtFilterServletRegistration() {
        var registration = new FilterRegistrationBean<>(jwtAuthenticationFilter);
        registration.setEnabled(false);
        return registration;
    }

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }

    @Bean
    public CorsConfigurationSource corsConfigurationSource(
            @Value("${app.cors.allowed-origins:http://localhost:8080,http://127.0.0.1:8080}") String allowedOrigins) {
        CorsConfiguration cfg = new CorsConfiguration();
        cfg.setAllowedOrigins(Arrays.stream(allowedOrigins.split(","))
                .map(String::trim)
                .filter(origin -> !origin.isBlank())
                .toList());
        cfg.setAllowedMethods(List.of("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"));
        cfg.setAllowedHeaders(List.of("Authorization", "Content-Type", "X-Platform", "Accept", "Origin"));
        cfg.setExposedHeaders(List.of("Authorization"));
        cfg.setAllowCredentials(true);
        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", cfg);
        return source;
    }

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        http
            .cors(cors -> {})
            .csrf(AbstractHttpConfigurer::disable)
            .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .exceptionHandling(exceptions -> exceptions
                .authenticationEntryPoint(securityErrors)
                .accessDeniedHandler(securityErrors)
            )
            .authorizeHttpRequests(auth -> auth
                .requestMatchers(HttpMethod.OPTIONS, "/**").permitAll()
                .requestMatchers(HttpMethod.POST,
                        "/api/v1/auth/register",
                        "/api/v1/auth/login",
                        "/api/v1/auth/email/verification",
                        "/api/v1/auth/email/verify",
                        "/api/v1/auth/forgot-password",
                        "/api/v1/auth/reset-password").permitAll()
                .requestMatchers(HttpMethod.GET, "/api/v1/posts", "/api/v1/posts/*",
                        "/api/v1/restaurants", "/api/v1/restaurants/*").permitAll()
                .requestMatchers("/api/files/view/**", "/api/v1/files/view/**").permitAll()
                .requestMatchers(HttpMethod.GET, "/api/v1/users", "/api/v1/users/**")
                        .hasAnyRole("FOODIE", "RESTAURANT_ADMIN", "MODERADOR", "ADMIN_SISTEMA")
                .requestMatchers(HttpMethod.PUT, "/api/v1/users/*/status", "/api/v1/users/*/toggle-active")
                        .hasAnyRole("MODERADOR", "ADMIN_SISTEMA")
                .requestMatchers(HttpMethod.DELETE, "/api/v1/users/*").hasRole("ADMIN_SISTEMA")
                .requestMatchers(HttpMethod.POST, "/api/v1/restaurants", "/api/v1/restaurants/*/menu")
                        .hasRole("RESTAURANT_ADMIN")
                .requestMatchers(HttpMethod.PUT, "/api/v1/restaurants/*/status", "/api/v1/pqrs/*")
                        .hasAnyRole("MODERADOR", "ADMIN_SISTEMA")
                .requestMatchers(HttpMethod.DELETE, "/api/v1/restaurants/*")
                        .hasAnyRole("RESTAURANT_ADMIN", "ADMIN_SISTEMA")
                .requestMatchers(HttpMethod.PUT, "/api/v1/reservations/*").hasRole("RESTAURANT_ADMIN")
                .requestMatchers(HttpMethod.POST, "/api/v1/reservations", "/api/v1/pqrs").hasRole("FOODIE")
                .requestMatchers(HttpMethod.POST, "/api/v1/notifications").hasRole("ADMIN_SISTEMA")
                .requestMatchers(HttpMethod.POST, "/api/v1/auth/moderators").hasRole("ADMIN_SISTEMA")
                .requestMatchers(HttpMethod.POST, "/api/v1/auth/restaurant-admin/requests/*/approve")
                        .hasRole("ADMIN_SISTEMA")
                .requestMatchers(HttpMethod.POST, "/api/v1/auth/restaurant-admin/request").hasRole("FOODIE")
                .requestMatchers("/error").permitAll()
                .anyRequest().hasAnyRole("FOODIE", "RESTAURANT_ADMIN", "MODERADOR", "ADMIN_SISTEMA")
            )
            .addFilterBefore(jwtAuthenticationFilter, UsernamePasswordAuthenticationFilter.class);
        return http.build();
    }
}