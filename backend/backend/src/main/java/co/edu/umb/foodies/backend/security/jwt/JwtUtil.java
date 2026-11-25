package co.edu.umb.foodies.backend.security.jwt;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.JwtParser;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.SignatureAlgorithm;
import io.jsonwebtoken.UnsupportedJwtException;
import io.jsonwebtoken.security.Keys;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.nio.charset.StandardCharsets;
import java.security.Key;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Date;
import java.util.HexFormat;
import java.util.UUID;

@Component
public class JwtUtil {

    private final Key key;
    private final JwtParser parser;
    private final long expirationMs;

    public JwtUtil(@Value("${app.jwt.secret}") String secret,
                   @Value("${app.jwt.expiration-ms}") long expirationMs) {
        if (expirationMs < 1000) {
            throw new IllegalArgumentException("La vigencia del JWT debe ser al menos de un segundo");
        }
        this.key = Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8));
        this.parser = Jwts.parserBuilder().setSigningKey(key).build();
        this.expirationMs = expirationMs;
    }

    public IssuedToken issueToken(String userId, String email, String role) {
        Instant issuedAt = Instant.now();
        Instant expiresAt = issuedAt.plusMillis(expirationMs).truncatedTo(ChronoUnit.SECONDS);
        String token = Jwts.builder()
                .setId(UUID.randomUUID().toString())
                .setSubject(userId)
                .claim("userId", userId)
                .claim("email", email)
                .claim("role", role)
                .setIssuedAt(Date.from(issuedAt))
                .setExpiration(Date.from(expiresAt))
                .signWith(key, SignatureAlgorithm.HS256)
                .compact();
        return new IssuedToken(token, expiresAt);
    }

    public Claims parse(String token) {
        var jwt = parser.parseClaimsJws(token);
        if (!SignatureAlgorithm.HS256.getValue().equals(jwt.getHeader().getAlgorithm())) {
            throw new UnsupportedJwtException("Algoritmo de firma JWT no admitido");
        }
        return jwt.getBody();
    }

    public String sessionTokenKey(String token) {
        try {
            byte[] digest = MessageDigest.getInstance("SHA-256").digest(token.getBytes(StandardCharsets.UTF_8));
            return "v1:" + HexFormat.of().formatHex(digest);
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 no disponible", e);
        }
    }

    public static String bearerToken(String authorization) {
        if (authorization == null) {
            return null;
        }
        if (authorization.equalsIgnoreCase("Bearer")) {
            return "";
        }
        return authorization.regionMatches(true, 0, "Bearer ", 0, 7)
                ? authorization.substring(7).strip()
                : null;
    }

    public record IssuedToken(String token, Instant expiresAt) {}
}
