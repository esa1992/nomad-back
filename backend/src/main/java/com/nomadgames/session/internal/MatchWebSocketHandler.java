package com.nomadgames.session.internal;

import java.io.IOException;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.UUID;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.web.socket.CloseStatus;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;
import org.springframework.web.socket.handler.ConcurrentWebSocketSessionDecorator;
import org.springframework.web.socket.handler.TextWebSocketHandler;

import com.nomadgames.session.MatchService;
import com.nomadgames.session.PrivateThrowResult;

import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;

@Component
public class MatchWebSocketHandler extends TextWebSocketHandler {

    private static final String ATTR_SAFE = "safeSession";
    private static final int SEND_TIME_LIMIT_MS = 10_000;
    private static final int BUFFER_SIZE_LIMIT = 512 * 1024;

    private final MatchService matches;
    private final MatchSessionRegistry registry;
    private final ObjectMapper mapper;
    private final TapRateLimiter tapRateLimiter;

    public MatchWebSocketHandler(
            MatchService matches,
            MatchSessionRegistry registry,
            ObjectMapper mapper,
            TapRateLimiter tapRateLimiter) {
        this.matches = matches;
        this.registry = registry;
        this.mapper = mapper;
        this.tapRateLimiter = tapRateLimiter;
    }

    @Override
    public void afterConnectionEstablished(WebSocketSession session) {
        UUID matchId = (UUID) session.getAttributes().get(WsTicketInterceptor.ATTR_MATCH_ID);
        UUID playerId = (UUID) session.getAttributes().get(WsTicketInterceptor.ATTR_PLAYER_ID);
        WebSocketSession safe = new ConcurrentWebSocketSessionDecorator(session, SEND_TIME_LIMIT_MS, BUFFER_SIZE_LIMIT);
        session.getAttributes().put(ATTR_SAFE, safe);
        registry.add(matchId, safe);
        if (playerId != null && matchId != null) {
            try {
                matches.clearSeatDrop(playerId, matchId);
            } catch (ResponseStatusException ignored) {
                // Missing match or not a seat.
            }
            try {
                matches.pushStickPullSync(matchId);
            } catch (RuntimeException ignored) {
                // Non-stick or no live session.
            }
        }
    }

    @Override
    protected void handleTextMessage(WebSocketSession session, TextMessage message) throws Exception {
        UUID playerId = (UUID) session.getAttributes().get(WsTicketInterceptor.ATTR_PLAYER_ID);
        UUID matchId = (UUID) session.getAttributes().get(WsTicketInterceptor.ATTR_MATCH_ID);
        JsonNode root;
        try {
            root = mapper.readTree(message.getPayload());
        } catch (RuntimeException ex) {
            sendError(session, "bad_json", "invalid json");
            return;
        }
        String type = root.path("type").asText("");
        if ("Ping".equals(type)) {
            sendJson(session, Map.of("type", "Pong"));
            return;
        }
        if ("TapInput".equals(type)) {
            if (!tapRateLimiter.tryAcquire(matchId, playerId)) {
                return; // silent drop — above ~15 msg/s per seat
            }
            try {
                int clientSeq = root.path("clientSeq").asInt(0);
                matches.applyTap(playerId, matchId, clientSeq);
            } catch (ResponseStatusException ex) {
                sendError(session, codeFor(ex), ex.getReason() == null ? "error" : ex.getReason());
            } catch (IllegalArgumentException ex) {
                sendError(session, "invalid_tap", "invalid tap");
            }
            return;
        }
        if ("Pause".equals(type) || "Resume".equals(type)) {
            try {
                matches.setStickPullClientPaused(playerId, matchId, "Pause".equals(type));
            } catch (ResponseStatusException ex) {
                sendError(session, codeFor(ex), ex.getReason() == null ? "error" : ex.getReason());
            }
            return;
        }
        if (!"ThrowInput".equals(type)) {
            sendError(session, "unknown_type", "unknown type");
            return;
        }
        try {
            PrivateThrowResult result = matches.applyPrivateThrow(playerId, matchId, message.getPayload());
            Map<String, Object> resolved = new LinkedHashMap<>();
            resolved.put("type", "ThrowResolved");
            resolved.put("playerThrow", result.playerThrow());
            resolved.put("match", result.match());
            if (root.has("aimAngleRad") || root.has("holdMs")) {
                Map<String, Object> input = new LinkedHashMap<>();
                input.put("schemaVersion", root.path("schemaVersion").asInt(1));
                input.put("yUp", root.path("yUp").asBoolean(true));
                input.put("aimAngleRad", root.path("aimAngleRad").asDouble());
                input.put("holdMs", root.path("holdMs").asInt());
                input.put("seed", root.path("seed").asInt());
                input.put("tableId", root.path("tableId").asText(""));
                resolved.put("input", input);
            }
            broadcast(matchId, resolved);
            if (!"IN_PLAY".equals(result.match().status())) {
                broadcast(matchId, Map.of("type", "MatchSettled", "match", result.match()));
            }
        } catch (ResponseStatusException ex) {
            sendError(session, codeFor(ex), ex.getReason() == null ? "error" : ex.getReason());
        } catch (IllegalArgumentException ex) {
            sendError(session, "invalid_throw", "invalid throw");
        }
    }

    @Override
    public void afterConnectionClosed(WebSocketSession session, CloseStatus status) {
        UUID playerId = (UUID) session.getAttributes().get(WsTicketInterceptor.ATTR_PLAYER_ID);
        UUID matchId = (UUID) session.getAttributes().get(WsTicketInterceptor.ATTR_MATCH_ID);
        registry.remove(session);
        Object safe = session.getAttributes().get(ATTR_SAFE);
        if (safe instanceof WebSocketSession wrapped) {
            registry.remove(wrapped);
        }
        if (status.getCode() == 4000 && playerId != null && matchId != null) {
            try {
                matches.leaveMatch(playerId, matchId);
            } catch (ResponseStatusException ignored) {
                // Already terminal, missing match, or not a seat.
            }
        } else if (playerId != null && matchId != null && !registry.hasOpenSeat(matchId, playerId)) {
            try {
                matches.markDropped(playerId, matchId);
            } catch (ResponseStatusException ignored) {
                // Missing match or not a seat.
            }
        }
    }

    private void broadcast(UUID matchId, Map<String, ?> frame) throws IOException {
        String json = mapper.writeValueAsString(frame);
        TextMessage message = new TextMessage(json);
        for (WebSocketSession open : registry.sessionsFor(matchId)) {
            if (open.isOpen()) {
                open.sendMessage(message);
            }
        }
    }

    private void sendError(WebSocketSession session, String code, String message) throws IOException {
        Map<String, Object> error = new LinkedHashMap<>();
        error.put("type", "Error");
        error.put("code", code);
        error.put("message", message);
        sendJson(session, error);
    }

    private void sendJson(WebSocketSession session, Map<String, ?> frame) throws IOException {
        WebSocketSession safe = safe(session);
        if (safe.isOpen()) {
            safe.sendMessage(new TextMessage(mapper.writeValueAsString(frame)));
        }
    }

    private static WebSocketSession safe(WebSocketSession session) {
        Object stored = session.getAttributes().get(ATTR_SAFE);
        if (stored instanceof WebSocketSession wrapped) {
            return wrapped;
        }
        return session;
    }

    private static String codeFor(ResponseStatusException ex) {
        if (ex.getStatusCode() == HttpStatus.CONFLICT) {
            return "not_your_turn";
        }
        return "error";
    }
}
