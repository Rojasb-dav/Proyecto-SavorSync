package co.edu.umb.foodies.backend.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Profile;
import org.springframework.mail.MailException;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.stereotype.Component;

@Component
@Profile("test")
class SmtpTestSecurityEmailProvider implements SecurityEmailProvider {
    private final JavaMailSender sender;
    private final String from;

    SmtpTestSecurityEmailProvider(JavaMailSender sender, @Value("${spring.mail.username:}") String from) {
        this.sender = sender;
        this.from = from;
    }

    @Override
    public Delivery send(SecurityEmailEvent event) {
        var message = new SimpleMailMessage();
        message.setFrom(from);
        message.setTo(event.recipient());
        message.setSubject(event.subject());
        message.setText(event.text());
        try {
            sender.send(message);
            return Delivery.ACCEPTED;
        } catch (MailException failure) {
            return Delivery.UNAVAILABLE;
        }
    }
}
