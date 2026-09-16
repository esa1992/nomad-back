package com.nomadgames.session.internal;

import java.time.Instant;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CopyOnWriteArrayList;

import org.springframework.stereotype.Component;
import org.springframework.web.socket.WebSocketSession;

import com.nomadgames.session.BodyPoseView;
import com.nomadgames.session.KeyframeView;
import com.nomadgames.session.PlayerThrowView;
import com.nomadgames.session.internal.ReconnectPolicy.FrozenClocks;

@Component
public class MatchSessionRegistry {

    private final ConcurrentHashMap<UUID, CopyOnWriteArrayList<WebSocketSession>> sessions = new ConcurrentHashMap<>();
    private final ConcurrentHashMap<UUID, RematchWindow> rematchWindows = new ConcurrentHashMap<>();
    private final ConcurrentHashMap<UUID, LiveMatch> liveMatches = new ConcurrentHashMap<>();

    public void add(UUID matchId, WebSocketSession session) {
        Object playerAttr = session.getAttributes().get(WsTicketInterceptor.ATTR_PLAYER_ID);
        sessions.compute(matchId, (id, list) -> {
            CopyOnWriteArrayList<WebSocketSession> next =
                    list == null ? new CopyOnWriteArrayList<>() : list;
            if (playerAttr instanceof UUID playerId) {
                next.removeIf(existing ->
                        playerId.equals(existing.getAttributes().get(WsTicketInterceptor.ATTR_PLAYER_ID)));
            }
            next.add(session);
            return next;
        });
    }

    public void remove(WebSocketSession session) {
        String id = session.getId();
        sessions.values().forEach(list -> list.removeIf(open -> open.getId().equals(id)));
        sessions.entrySet().removeIf(entry -> entry.getValue().isEmpty());
    }

    public List<WebSocketSession> sessionsFor(UUID matchId) {
        CopyOnWriteArrayList<WebSocketSession> found = sessions.get(matchId);
        return found == null ? List.of() : List.copyOf(found);
    }

    public boolean hasOpenSeat(UUID matchId, UUID playerId) {
        if (matchId == null || playerId == null) {
            return false;
        }
        CopyOnWriteArrayList<WebSocketSession> found = sessions.get(matchId);
        if (found == null) {
            return false;
        }
        for (WebSocketSession open : found) {
            if (playerId.equals(open.getAttributes().get(WsTicketInterceptor.ATTR_PLAYER_ID))) {
                return true;
            }
        }
        return false;
    }

    public RematchWindow openRematch(UUID finishedMatchId, UUID hostId, UUID joinerId, Instant deadline) {
        return rematchWindows.computeIfAbsent(
                finishedMatchId, id -> new RematchWindow(hostId, joinerId, deadline));
    }

    public RematchWindow rematchWindow(UUID finishedMatchId) {
        return rematchWindows.get(finishedMatchId);
    }

    public void registerPrivate(UUID matchId, String hostToken, String joinerToken) {
        LiveMatch live = new LiveMatch();
        live.hostToken = hostToken;
        live.joinerToken = joinerToken;
        liveMatches.put(matchId, live);
    }

    public LiveMatch live(UUID matchId) {
        return liveMatches.get(matchId);
    }

    public String plaintextToken(UUID matchId, UUID playerId, UUID hostId, UUID joinerId) {
        LiveMatch live = liveMatches.get(matchId);
        if (live == null) {
            return null;
        }
        if (playerId.equals(hostId)) {
            return live.hostToken;
        }
        if (playerId.equals(joinerId)) {
            return live.joinerToken;
        }
        return null;
    }

    public boolean anyDropped(UUID matchId) {
        LiveMatch live = liveMatches.get(matchId);
        return live != null && live.anyDropped();
    }

    public Set<UUID> liveMatchIds() {
        return Set.copyOf(liveMatches.keySet());
    }

    public void recordThrow(UUID matchId, PlayerThrowView view) {
        LiveMatch live = liveMatches.computeIfAbsent(matchId, id -> new LiveMatch());
        live.lastThrow = view;
        if (view != null && view.keyframes() != null && !view.keyframes().isEmpty()) {
            KeyframeView last = view.keyframes().get(view.keyframes().size() - 1);
            if (last.bodies() != null) {
                live.sakaPoses = last.bodies().stream()
                        .filter(body -> body.id() != null && body.id().startsWith("saka"))
                        .toList();
            }
        }
    }

    public void clearDrops(UUID matchId) {
        LiveMatch live = liveMatches.get(matchId);
        if (live == null) {
            return;
        }
        live.hostGraceDeadline = null;
        live.joinerGraceDeadline = null;
        live.frozen = null;
    }

    public static final class LiveMatch {
        public String hostToken;
        public String joinerToken;
        public FrozenClocks frozen;
        public Instant hostGraceDeadline;
        public Instant joinerGraceDeadline;
        public PlayerThrowView lastThrow;
        public List<BodyPoseView> sakaPoses = List.of();
        /** Ranked Alchiki: last seat that scored a knock-out ("HOST"|"JOINER"). */
        public String lastKnockOutSeat;
        /** Aggregate ms spent in reconnect grace this match (D-102). */
        public long pauseUsedMs;
        /** When current grace started accruing into {@link #pauseUsedMs}. */
        public Instant pauseAccrueStartedAt;
        /** True once Ranked pause budget is exhausted — next drop is immediate forfeit. */
        public boolean pauseBudgetGone;

        public boolean anyDropped() {
            return hostGraceDeadline != null || joinerGraceDeadline != null;
        }

        public boolean hostDropped() {
            return hostGraceDeadline != null;
        }

        public boolean joinerDropped() {
            return joinerGraceDeadline != null;
        }
    }

    /**
     * Heap rematch dual-accept state. {@code MatchService} mutates and reads fields only
     * inside {@code synchronized(this)} so concurrent Again? cannot mint two PRIVATE rows.
     */
    public static final class RematchWindow {
        public final UUID hostId;
        public final UUID joinerId;
        public Instant deadline;
        public boolean acceptedHost;
        public boolean acceptedJoiner;
        public boolean rejected;
        public UUID newMatchId;

        RematchWindow(UUID hostId, UUID joinerId, Instant deadline) {
            this.hostId = hostId;
            this.joinerId = joinerId;
            this.deadline = deadline;
        }
    }
}
