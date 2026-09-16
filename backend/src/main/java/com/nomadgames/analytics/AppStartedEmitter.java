package com.nomadgames.analytics;

import java.util.Map;

import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Component;

/**
 * APP_STARTED call site (ANLT-01): JVM application ready — not per guest mint (avoids flood).
 */
@Component
public class AppStartedEmitter {

    private final EventSink events;

    public AppStartedEmitter(EventSink events) {
        this.events = events;
    }

    @EventListener(ApplicationReadyEvent.class)
    public void onReady() {
        events.emit("APP_STARTED", null, null, Map.of("source", "ApplicationReadyEvent"));
    }
}
