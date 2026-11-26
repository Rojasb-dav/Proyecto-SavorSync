package co.edu.umb.foodies.backend.controller;

import co.edu.umb.foodies.backend.service.CloudinaryAssetRegistry;
import co.edu.umb.foodies.backend.service.CloudinaryService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.web.server.ResponseStatusException;

import javax.imageio.ImageIO;
import java.awt.image.BufferedImage;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.security.Principal;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

class FileUploadP08Test {

    private CloudinaryService cloudinary;
    private CloudinaryAssetRegistry registry;
    private FileController controller;

    @BeforeEach
    void setUp() {
        cloudinary = mock(CloudinaryService.class);
        registry = mock(CloudinaryAssetRegistry.class);
        controller = new FileController(cloudinary, registry);
    }

    @Test
    void validPngIsUploadedByTheServerAndTrackedForItsOwner() throws IOException {
        byte[] png = pngImage();
        MockMultipartFile file = new MockMultipartFile("file", "meal.png", "image/png", png);
        MockHttpServletRequest request = authenticatedClientRequest();
        CloudinaryService.UploadResult uploaded =
                new CloudinaryService.UploadResult("https://cdn.example.test/meal.png", "savorsync/meal", "png");
        when(cloudinary.uploadFile(any(byte[].class), eq("png"))).thenReturn(uploaded);

        var response = controller.uploadFile(file, request);

        assertThat(response.getStatusCode().value()).isEqualTo(201);
        assertThat(response.getBody()).containsEntry("url", uploaded.secureUrl())
                .containsEntry("publicId", uploaded.publicId());
        verify(registry).recordUpload("client", "client-id", uploaded);
    }

    @Test
    void emptyAndCorruptFilesAreRejectedBeforeCallingCloudinary() {
        MockMultipartFile empty = new MockMultipartFile("file", "empty.png", "image/png", new byte[0]);
        MockMultipartFile corrupt = new MockMultipartFile("file", "bad.png", "image/png",
                new byte[]{1, 2, 3, 4, 5});

        assertBadRequest(empty, authenticatedClientRequest());
        assertBadRequest(corrupt, authenticatedClientRequest());
        verifyNoInteractions(cloudinary, registry);
    }

    @Test
    void declaredMimeMustMatchTheDecodedImage() throws IOException {
        MockMultipartFile spoofed = new MockMultipartFile(
                "file", "meal.jpg", "image/jpeg", pngImage());

        assertBadRequest(spoofed, authenticatedClientRequest());
        verifyNoInteractions(cloudinary, registry);
    }

    @Test
    void filesOverTenMegabytesAreRejectedBeforeImageDecoding() {
        byte[] oversized = new byte[10 * 1024 * 1024 + 1];
        MockMultipartFile file = new MockMultipartFile("file", "large.png", "image/png", oversized);

        assertThatThrownBy(() -> controller.uploadFile(file, authenticatedClientRequest()))
                .isInstanceOf(ResponseStatusException.class)
                .extracting(exception -> ((ResponseStatusException) exception).getStatusCode().value())
                .isEqualTo(413);
        verifyNoInteractions(cloudinary, registry);
    }

    @Test
    void uploadRequiresAuthenticatedIdentity() throws IOException {
        MockHttpServletRequest request = new MockHttpServletRequest();
        MockMultipartFile file = new MockMultipartFile("file", "meal.png", "image/png", pngImage());

        assertThatThrownBy(() -> controller.uploadFile(file, request))
                .isInstanceOf(ResponseStatusException.class)
                .extracting(exception -> ((ResponseStatusException) exception).getStatusCode().value())
                .isEqualTo(401);
        verifyNoInteractions(cloudinary, registry);
    }

    @Test
    void deletesNewUploadIfRegistryPersistenceFails() throws IOException {
        var uploaded = new CloudinaryService.UploadResult("https://cdn.example.test/meal.png", "test-id", "png");
        when(cloudinary.uploadFile(any(byte[].class), eq("png"))).thenReturn(uploaded);
        doThrow(new org.springframework.dao.DataIntegrityViolationException("synthetic failure"))
                .when(registry).recordUpload("client", "client-id", uploaded);
        var file = new MockMultipartFile("file", "meal.png", "image/png", pngImage());

        assertThatThrownBy(() -> controller.uploadFile(file, authenticatedClientRequest()))
                .isInstanceOf(ResponseStatusException.class).hasMessageContaining("503");
        verify(cloudinary).deleteUploadedAsset("test-id");
    }

    private void assertBadRequest(MockMultipartFile file, MockHttpServletRequest request) {
        assertThatThrownBy(() -> controller.uploadFile(file, request))
                .isInstanceOf(ResponseStatusException.class)
                .extracting(exception -> ((ResponseStatusException) exception).getStatusCode().value())
                .isEqualTo(400);
    }

    private static MockHttpServletRequest authenticatedClientRequest() {
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setUserPrincipal((Principal) () -> "client-id");
        request.addUserRole("FOODIE");
        return request;
    }

    private static byte[] pngImage() throws IOException {
        BufferedImage image = new BufferedImage(8, 8, BufferedImage.TYPE_INT_RGB);
        ByteArrayOutputStream bytes = new ByteArrayOutputStream();
        ImageIO.write(image, "png", bytes);
        return bytes.toByteArray();
    }
}
