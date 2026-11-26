package co.edu.umb.foodies.backend.service;

import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

@Component
@RequiredArgsConstructor
public class SecurityEmailDispatcher {
    private static final Logger log = LoggerFactory.getLogger(SecurityEmailDispatcher.class);
    private final SecurityEmailProvider provider;

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void sendAfterCommit(SecurityEmailEvent event) {
        var result = provider.send(event);
        if (result != SecurityEmailProvider.Delivery.ACCEPTED) {
            log.warn("Security email was not accepted by provider: {}", result);
        }
    }
}
