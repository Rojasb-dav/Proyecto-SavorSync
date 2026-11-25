package co.edu.umb.foodies.backend.service;

import co.edu.umb.foodies.backend.model.User;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.mail.MailException;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.security.GeneralSecurityException;
import java.security.MessageDigest;
import java.time.Instant;
import java.util.Arrays;
import java.util.Base64;
import java.util.LinkedHashMap;
import java.util.Map;

@Service
public class EmailVerificationService {

    private static final long VALID_SECONDS = 15 * 60;
    private static final long RESEND_SECONDS = 60;
    private static final int MAX_SENDERS = 4096;

    private final JavaMailSender mail;
    private final SecretKeySpec key;
    private final String sender;
    private final Map<String, Long> lastSent = new LinkedHashMap<>();

    public EmailVerificationService(JavaMailSender mail,
                                    @Value("${app.jwt.secret}") String secret,
                                    @Value("${spring.mail.username}") String sender) {
        this.mail = mail;
        this.key = new SecretKeySpec(secret.getBytes(StandardCharsets.UTF_8), "HmacSHA256");
        this.sender = sender;
    }

    public void send(User user) {
        long now = Instant.now().getEpochSecond();
        reserveSend(user.getEmail(), now);

        SimpleMailMessage message = new SimpleMailMessage();
        message.setFrom(sender);
        message.setTo(user.getEmail());
        message.setSubject("Verifica tu correo en SavorSync");
        message.setText("Copia este código en tu perfil de SavorSync:\n\n"
                + codeFor(user, now + VALID_SECONDS)
                + "\n\nEl código vence en 15 minutos.");
        try {
            mail.send(message);
        } catch (MailException e) {
            throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE,
                    "No se pudo enviar el código. Intenta nuevamente.");
        }
    }

    public void requireProof(User user, String code) {
        long now = Instant.now().getEpochSecond();
        if (code != null && code.matches("[0-9]{10}\\.[A-Za-z0-9_-]{22}")) {
            long expires = Long.parseLong(code.substring(0, 10));
            if (expires > now && expires <= now + VALID_SECONDS
                    && MessageDigest.isEqual(bytes(code), bytes(codeFor(user, expires)))) {
                return;
            }
        }
        throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Código de verificación inválido o vencido");
    }

    private synchronized void reserveSend(String email, long now) {
        lastSent.values().removeIf(sent -> sent + RESEND_SECONDS <= now);
        if (lastSent.containsKey(email) || lastSent.size() >= MAX_SENDERS) {
            throw new ResponseStatusException(HttpStatus.TOO_MANY_REQUESTS, "Espera un minuto antes de solicitar otro código");
        }
        lastSent.put(email, now);
    }

    private String codeFor(User user, long expires) {
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(key);
            byte[] signature = mac.doFinal(bytes("savorsync/email-verification/v1\0"
                    + user.getId() + "\0" + user.getEmail() + "\0" + expires));
            return expires + "." + Base64.getUrlEncoder().withoutPadding()
                    .encodeToString(Arrays.copyOf(signature, 16));
        } catch (GeneralSecurityException e) {
            throw new IllegalStateException("No se pudo firmar la verificación de correo", e);
        }
    }

    private static byte[] bytes(String value) {
        return value.getBytes(StandardCharsets.UTF_8);
    }
}
