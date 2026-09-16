package com.nomadgames.session.internal;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

import org.junit.jupiter.api.Test;
import org.springframework.web.socket.WebSocketSession;

class MatchSessionRegistryTest {

    @Test
    void oneDecoratorPerPlayerId_hasOpenSeatAfterStaleRemove() throws Exception {
        UUID matchId = UUID.fromString("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa");
        UUID playerId = UUID.fromString("bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb");
        WebSocketSession first = session("first", playerId);
        WebSocketSession second = session("second", playerId);
        MatchSessionRegistry registry = new MatchSessionRegistry();
        registry.add(matchId, first);
        registry.add(matchId, second);
        assertEquals(1, registry.sessionsFor(matchId).size());
        registry.remove(first);
        boolean open;
        try {
            open = (boolean) MatchSessionRegistry.class
                    .getMethod("hasOpenSeat", UUID.class, UUID.class)
                    .invoke(registry, matchId, playerId);
        } catch (ReflectiveOperationException ex) {
            throw new AssertionError("hasOpenSeat(matchId, playerId) is required", ex);
        }
        assertTrue(open);
    }

    private static WebSocketSession session(String id, UUID playerId) {
        WebSocketSession socket = mock(WebSocketSession.class);
        when(socket.getId()).thenReturn(id);
        Map<String, Object> attrs = new ConcurrentHashMap<>();
        attrs.put(WsTicketInterceptor.ATTR_PLAYER_ID, playerId);
        when(socket.getAttributes()).thenReturn(attrs);
        return socket;
    }
}
