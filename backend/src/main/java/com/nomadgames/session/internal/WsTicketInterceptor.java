package com.nomadgames.session.internal;

import java.net.URI;
import java.net.URLDecoder;
import java.nio.charset.StandardCharsets;
import java.util.Map;
import java.util.UUID;

import org.springframework.http.HttpStatus;
import org.springframework.http.server.ServerHttpRequest;
import org.springframework.http.server.ServerHttpResponse;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.web.socket.WebSocketHandler;
import org.springframework.web.socket.server.HandshakeInterceptor;

@Component
public class WsTicketInterceptor implements HandshakeInterceptor {

    static final String ATTR_PLAYER_ID = "playerId";
    static final String ATTR_MATCH_ID = "matchId";

    private final WsTicketService tickets;

    public WsTicketInterceptor(WsTicketService tickets) {
        this.tickets = tickets;
    }

    @Override
    public boolean beforeHandshake(
            ServerHttpRequest request,
            ServerHttpResponse response,
            WebSocketHandler wsHandler,
            Map<String, Object> attributes) {
        UUID matchId = parseMatchId(request.getURI());
        if (matchId == null) {
            response.setStatusCode(HttpStatus.BAD_REQUEST);
            return false;
        }
        try {
            WsTicketService.Bound bound = tickets.consume(queryParam(request.getURI(), "ticket"), matchId);
            attributes.put(ATTR_PLAYER_ID, bound.playerId());
            attributes.put(ATTR_MATCH_ID, bound.matchId());
            return true;
        } catch (ResponseStatusException ex) {
            response.setStatusCode(ex.getStatusCode());
            return false;
        }
    }

    @Override
    public void afterHandshake(
            ServerHttpRequest request,
            ServerHttpResponse response,
            WebSocketHandler wsHandler,
            Exception exception) {
        // ticket already consumed; seat stays on unexpected close (03-09)
    }

    static UUID parseMatchId(URI uri) {
        String path = uri.getPath();
        String marker = "/v1/matches/";
        int at = path.indexOf(marker);
        if (at < 0) {
            return null;
        }
        String rest = path.substring(at + marker.length());
        int slash = rest.indexOf('/');
        if (slash < 0 || !rest.substring(slash).startsWith("/ws")) {
            return null;
        }
        try {
            return UUID.fromString(rest.substring(0, slash));
        } catch (IllegalArgumentException ex) {
            return null;
        }
    }

    static String queryParam(URI uri, String name) {
        String query = uri.getRawQuery();
        if (query == null || query.isBlank()) {
            return null;
        }
        for (String part : query.split("&")) {
            int eq = part.indexOf('=');
            if (eq <= 0) {
                continue;
            }
            String key = URLDecoder.decode(part.substring(0, eq), StandardCharsets.UTF_8);
            if (name.equals(key)) {
                return URLDecoder.decode(part.substring(eq + 1), StandardCharsets.UTF_8);
            }
        }
        return null;
    }
}
