package co.edu.umb.foodies.backend.service;

import com.cloudinary.Cloudinary;
import com.cloudinary.Uploader;
import com.cloudinary.Util;
import org.junit.jupiter.api.Test;
import org.springframework.web.server.ResponseStatusException;

import java.util.Map;

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
