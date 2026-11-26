package co.edu.umb.foodies.backend.service;

public interface SecurityEmailProvider {
    Delivery send(SecurityEmailEvent event);

    enum Delivery {
        ACCEPTED, INVALID_CONFIGURATION, REJECTED, RATE_LIMITED, UNAVAILABLE
    }
}
