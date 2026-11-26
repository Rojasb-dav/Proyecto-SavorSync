package co.edu.umb.foodies.backend.controller;

import org.springframework.dao.DataAccessException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import javax.sql.DataSource;
import java.util.Map;

@RestController
public class HealthController {
    private final JdbcTemplate healthJdbc;

    public HealthController(DataSource dataSource) {
        this.healthJdbc = new JdbcTemplate(dataSource);
        this.healthJdbc.setQueryTimeout(2);
    }

    @GetMapping("/actuator/health")
    public ResponseEntity<Map<String, String>> health() {
        try {
            healthJdbc.queryForObject("SELECT 1", Integer.class);
            return ResponseEntity.ok(Map.of("status", "UP"));
        } catch (DataAccessException unavailable) {
            return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE)
                    .body(Map.of("status", "DOWN"));
        }
    }
}
