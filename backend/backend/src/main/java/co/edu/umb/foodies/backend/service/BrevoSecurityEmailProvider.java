package co.edu.umb.foodies.backend.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;

import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.List;
import java.util.Map;

@Component
@Profile("!test")
public class BrevoSecurityEmailProvider implements SecurityEmailProvider {
    private static final URI ENDPOINT = URI.create("https://api.brevo.com/v3/smtp/email");
    private final ObjectMapper json;
    private final String apiKey;
    private final String senderEmail;
    private final String senderName;
    private final URI endpoint;
    private final Duration timeout;
    private final HttpClient client;

    @org.springframework.beans.factory.annotation.Autowired
    public BrevoSecurityEmailProvider(ObjectMapper json, @Value("${BREVO_API_KEY:}") String apiKey,
            @Value("${BREVO_SENDER_EMAIL:}") String senderEmail,
            @Value("${BREVO_SENDER_NAME:SavorSync}") String senderName) {
        this(json, apiKey, senderEmail, senderName, ENDPOINT, Duration.ofSeconds(8));
    }

    BrevoSecurityEmailProvider(ObjectMapper json, String apiKey, String senderEmail, String senderName,
                              URI endpoint, Duration timeout) {
        this.json = json;
        this.apiKey = apiKey;
        this.senderEmail = senderEmail;
        this.senderName = senderName;
        this.endpoint = endpoint;
        this.timeout = timeout;
        this.client = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(3))
                .followRedirects(HttpClient.Redirect.NEVER).build();
    }

    @Override
    public Delivery send(SecurityEmailEvent event) {
        if (apiKey.isBlank() || senderEmail.isBlank() || senderName.isBlank()) {
            return Delivery.INVALID_CONFIGURATION;
        }
        try {
            var payload = Map.of("sender", Map.of("email", senderEmail, "name", senderName),
                    "to", List.of(Map.of("email", event.recipient())),
                    "subject", event.subject(), "textContent", event.text());
            var request = HttpRequest.newBuilder(endpoint).timeout(timeout)
                    .header("api-key", apiKey).header("Content-Type", "application/json")
                    .POST(HttpRequest.BodyPublishers.ofString(json.writeValueAsString(payload))).build();
            int status = client.send(request, HttpResponse.BodyHandlers.discarding()).statusCode();
            return switch (status) {
                case 201, 202 -> Delivery.ACCEPTED;
                case 401, 403 -> Delivery.INVALID_CONFIGURATION;
                case 429 -> Delivery.RATE_LIMITED;
                default -> status >= 500 ? Delivery.UNAVAILABLE : Delivery.REJECTED;
            };
        } catch (InterruptedException interrupted) {
            Thread.currentThread().interrupt();
            return Delivery.UNAVAILABLE;
        } catch (IOException | IllegalArgumentException failure) {
            return Delivery.UNAVAILABLE;
        }
    }
}
