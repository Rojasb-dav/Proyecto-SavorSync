package co.edu.umb.foodies.backend.service;

import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.mail.MailException;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

@Component
@RequiredArgsConstructor
public class SecurityEmailDispatcher {

    private static final Logger log = LoggerFactory.getLogger(SecurityEmailDispatcher.class);
    private final JavaMailSender mailSender;

    @Value("${spring.mail.username:}")
    private String sender;

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void sendAfterCommit(SecurityEmailEvent event) {
        if (sender == null || sender.isBlank()) {
            log.warn("Security email was not sent because SMTP is not configured.");
            return;
        }
        SimpleMailMessage message = new SimpleMailMessage();
        message.setFrom(sender);
        message.setTo(event.recipient());
        message.setSubject(event.subject());
        message.setText(event.text());
        try {
            mailSender.send(message);
        } catch (MailException exception) {
            log.warn("Security email delivery failed; type={}", event.subject());
        }
    }
}