package co.edu.umb.foodies.backend.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.sun.net.httpserver.HttpServer;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.springframework.boot.test.system.CapturedOutput;
import org.springframework.boot.test.system.OutputCaptureExtension;
import org.junit.jupiter.api.extension.ExtendWith;

import java.net.InetSocketAddress;
import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicReference;

import static co.edu.umb.foodies.backend.service.SecurityEmailProvider.Delivery;
import static org.assertj.core.api.Assertions.assertThat;

@ExtendWith(OutputCaptureExtension.class)
class BrevoSecurityEmailProviderTest {
    @ParameterizedTest
    @CsvSource({"201,ACCEPTED", "400,REJECTED", "401,INVALID_CONFIGURATION", "403,INVALID_CONFIGURATION",
                "429,RATE_LIMITED", "503,UNAVAILABLE"})
    void sendsTransactionalPayloadAndClassifiesProviderStatus(int status, Delivery expected) throws Exception {
        var body = new AtomicReference<String>();
        var key = new AtomicReference<String>();
        var calls = new AtomicInteger();
        var server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        server.createContext("/v3/smtp/email", exchange -> {
            try (exchange) {
                calls.incrementAndGet();
                key.set(exchange.getRequestHeaders().getFirst("api-key"));
                body.set(new String(exchange.getRequestBody().readAllBytes(), StandardCharsets.UTF_8));
                exchange.sendResponseHeaders(status, -1);
            }
        });
        server.start();
        try {
            var provider = provider(server, "synthetic-mail-key", Duration.ofSeconds(3));
            assertThat(provider.send(new SecurityEmailEvent("recipient@example.test", "SavorSync",
                    "Código de recuperación: 123456"))).isEqualTo(expected);
            assertThat(key.get()).isEqualTo("synthetic-mail-key");
            assertThat(new ObjectMapper().readTree(body.get()).path("textContent").asText()).endsWith("123456");
            assertThat(calls.get()).isEqualTo(1);
        } finally {
            server.stop(0);
        }
    }

    @Test
    void timesOutWithoutLoggingPayloadOrKey(CapturedOutput output) throws Exception {
        var server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        server.createContext("/v3/smtp/email", exchange -> {
            try (exchange) {
                try {
                    Thread.sleep(500);
                    exchange.sendResponseHeaders(201, -1);
                } catch (InterruptedException ignored) {
                    Thread.currentThread().interrupt();
                }
            }
        });
        server.start();
        try {
            var event = new SecurityEmailEvent("private@example.test", "SavorSync", "Código: 654321");
            var provider = provider(server, "synthetic-key", Duration.ofMillis(100));
            new SecurityEmailDispatcher(provider).sendAfterCommit(event);
            assertThat(output.getAll()).contains("UNAVAILABLE")
                    .doesNotContain("654321", "synthetic-key", "private@example.test");
            assertThat(provider(server, "", Duration.ofSeconds(1)).send(event))
                    .isEqualTo(Delivery.INVALID_CONFIGURATION);
        } finally {
            server.stop(0);
        }
    }

    private static BrevoSecurityEmailProvider provider(HttpServer server, String key, Duration timeout) {
        return new BrevoSecurityEmailProvider(new ObjectMapper(), key, "sender@example.test", "SavorSync",
                URI.create("http://127.0.0.1:" + server.getAddress().getPort() + "/v3/smtp/email"), timeout);
    }
}
