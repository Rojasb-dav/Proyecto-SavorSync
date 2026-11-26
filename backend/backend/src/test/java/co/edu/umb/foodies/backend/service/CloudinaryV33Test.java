package co.edu.umb.foodies.backend.service;

import com.cloudinary.Cloudinary;
import com.cloudinary.Uploader;
import com.cloudinary.Util;
import com.sun.net.httpserver.HttpServer;
import org.junit.jupiter.api.Test;
import org.springframework.web.server.ResponseStatusException;

import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.util.Map;
import java.util.concurrent.atomic.AtomicReference;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

class CloudinaryV33Test {
    @Test
    void sdkSerializesAuthorizedFolderAndSafeUploadOptions() throws Exception {
        Cloudinary cloudinary = mock(Cloudinary.class);
        Uploader uploader = mock(Uploader.class);
        when(cloudinary.uploader()).thenReturn(uploader);
        byte[] png = {1, 2};
        when(uploader.upload(eq(png), anyMap())).thenAnswer(call -> {
            Map<String, Object> wire = Util.buildUploadParams(call.getArgument(1));
            assertThat(wire).containsEntry("asset_folder", "foodies")
                    .containsEntry("overwrite", false).containsEntry("allowed_formats", "jpg,png");
            assertThat(wire.get("public_id")).asString().matches("[a-f0-9-]{36}");
            assertThat(wire.get("upload_preset")).isNull();
            return Map.of("public_id", "test-id", "secure_url", "https://images.example.test/image.png");
        });
        assertThat(new CloudinaryService(cloudinary, "foodies").uploadFile(png, "png").publicId())
                .isEqualTo("test-id");
    }

    @Test
    void cloudinaryHttpClientUsesSpringLoggingBridgeAgainstLocalServer() throws Exception {
        var server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        var upload = new AtomicReference<String>();
        server.createContext("/v1_1/fixture/image/upload", exchange -> {
            try (exchange) {
                upload.set(new String(exchange.getRequestBody().readAllBytes(), StandardCharsets.UTF_8));
                byte[] response = """
                        {"public_id":"local-upload","secure_url":"https://images.example.test/local.png"}
                        """.getBytes(StandardCharsets.UTF_8);
                exchange.getResponseHeaders().set("Content-Type", "application/json");
                exchange.sendResponseHeaders(200, response.length);
                exchange.getResponseBody().write(response);
            }
        });
        server.start();
        try {
            var cloudinary = new Cloudinary(Map.of("cloud_name", "fixture", "api_key", "test-only",
                    "api_secret", "test-only", "upload_prefix", "http://127.0.0.1:" + server.getAddress().getPort()));
            assertThat(cloudinary.cloudinaryApiUrl("upload", Map.of()))
                    .startsWith("http://127.0.0.1:");
            assertThat(new CloudinaryService(cloudinary, "foodies")
                    .uploadFile(new byte[] {1, 2}, "png").publicId()).isEqualTo("local-upload");
            assertThat(upload.get()).contains("name=\"asset_folder\"", "foodies", "name=\"file\"");
            assertThat(org.apache.commons.logging.LogFactory.class.getProtectionDomain()
                    .getCodeSource().getLocation().toExternalForm()).contains("spring-jcl");
        } finally {
            server.stop(0);
        }
    }

    @Test
    void hidesProviderAuthorizationFailure() throws Exception {
        Cloudinary cloudinary = mock(Cloudinary.class);
        Uploader uploader = mock(Uploader.class);
        when(cloudinary.uploader()).thenReturn(uploader);
        when(uploader.upload(any(byte[].class), anyMap()))
                .thenThrow(new IllegalStateException("provider secret details"));
        assertThatThrownBy(() -> new CloudinaryService(cloudinary, "foodies").uploadFile(new byte[] {1}, "png"))
                .isInstanceOf(ResponseStatusException.class).hasMessageNotContaining("secret details");
    }
}
