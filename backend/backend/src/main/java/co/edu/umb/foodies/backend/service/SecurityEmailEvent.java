package co.edu.umb.foodies.backend.service;

public record SecurityEmailEvent(String recipient, String subject, String text) {}
