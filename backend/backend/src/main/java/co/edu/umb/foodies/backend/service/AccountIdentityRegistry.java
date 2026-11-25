package co.edu.umb.foodies.backend.service;

import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.http.HttpStatus;

import java.util.List;
import java.util.Locale;

@Service
public class AccountIdentityRegistry {

    private final JdbcTemplate jdbc;

    public AccountIdentityRegistry(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @Transactional
    public void register(String identityType, String identityId, String email, String username) {
        register(identityType, identityId, email, username,
                "client".equals(identityType) ? "foodie" : "employee");
    }

    @Transactional
    public void register(
            String identityType,
            String identityId,
            String email,
            String username,
            String requestedRole) {
        try {
            jdbc.update("""
                    INSERT INTO account_identity_registry
                      (identity_type, identity_id, email_normalized, username_normalized, requested_role)
                    VALUES (?, ?, ?, ?, ?)
                    """,
                    identityType,
                    identityId,
                    normalize(email),
                    normalize(username),
                    requestedRole);
        } catch (DataIntegrityViolationException duplicate) {
            throw new ResponseStatusException(HttpStatus.CONFLICT,
                    "El correo o nombre de usuario ya está registrado.");
        }
    }

    @Transactional
    public void updateUsername(String identityType, String identityId, String username) {
        try {
            int updated = jdbc.update("""
                    UPDATE account_identity_registry
                    SET username_normalized = ?
                    WHERE identity_type = ? AND identity_id = ?
                    """, normalize(username), identityType, identityId);
            if (updated != 1) {
                throw new IllegalStateException("No existe el registro de identidad asociado a la cuenta.");
            }
        } catch (DataIntegrityViolationException duplicate) {
            throw new ResponseStatusException(HttpStatus.CONFLICT,
                    "El nombre de usuario ya está registrado.");
        }
    }

    @Transactional(propagation = org.springframework.transaction.annotation.Propagation.MANDATORY)
    public void lockForChallenge(String identityType, String identityId) {
        jdbc.queryForObject("""
                SELECT identity_id FROM account_identity_registry
                WHERE identity_type = ? AND identity_id = ?
                FOR UPDATE
                """, String.class, identityType, identityId);
    }

    @Transactional(readOnly = true)
    public String requestedRole(String identityType, String identityId) {
        List<String> roles = jdbc.query("""
                SELECT requested_role
                FROM account_identity_registry
                WHERE identity_type = ? AND identity_id = ?
                """,
                (result, rowNumber) -> result.getString(1),
                identityType,
                identityId);
        return roles.stream().findFirst().orElse(null);
    }

    @Transactional
    public void delete(String identityType, String identityId) {
        jdbc.update("""
                DELETE FROM account_identity_registry
                WHERE identity_type = ? AND identity_id = ?
                """, identityType, identityId);
    }

    private static String normalize(String value) {
        return value == null ? "" : value.trim().toLowerCase(Locale.ROOT);
    }
}