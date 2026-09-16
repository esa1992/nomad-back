package com.nomadgames.matchmaking;

import java.time.Instant;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentLinkedQueue;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import com.nomadgames.analytics.EventSink;
import com.nomadgames.matchmaking.internal.JoinRateLimiter;
import com.nomadgames.session.MatchService;

@Service
public class CasualQueueService {

    private final ConcurrentHashMap<String, ConcurrentLinkedQueue<UUID>> fifos = new ConcurrentHashMap<>();
    private final ConcurrentHashMap<UUID, Ticket> tickets = new ConcurrentHashMap<>();
    private final Object monitor = new Object();

    private final MatchService matches;
    private final JoinRateLimiter joinRateLimiter;
    private final EventSink events;

    public CasualQueueService(MatchService matches, JoinRateLimiter joinRateLimiter, EventSink events) {
        this.matches = matches;
        this.joinRateLimiter = joinRateLimiter;
        this.events = events;
    }

    public CasualQueueResponse enqueue(UUID playerId, String ip, String game) {
        String normalizedGame = GameDiscriminator.normalize(game);
        joinRateLimiter.check(ip, playerId);
        if (matches.hasInPlayHumanSeat(playerId)) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "already in play");
        }
        synchronized (monitor) {
            Ticket existing = tickets.get(playerId);
            if (existing != null) {
                if ("SEARCHING".equals(existing.status())) {
                    return toResponse(existing);
                }
                if ("MATCHED".equals(existing.status())
                        && existing.matchId() != null
                        && matches.hasInPlayHumanSeat(playerId)) {
                    return toResponse(existing);
                }
                // Stale MATCHED (match left IN_PLAY) — allow re-queue
                removeFromFifo(existing.game(), playerId);
                tickets.remove(playerId);
            }
            UUID peerId = pollWaitingPeer(playerId, normalizedGame);
            if (peerId != null) {
                Ticket peerTicket = tickets.get(peerId);
                try {
                    UUID matchId = matches.createCasualMatch(peerId, playerId, normalizedGame);
                    Ticket matchedPeer = new Ticket(
                            peerTicket.ticketId(), "MATCHED", matchId, peerTicket.enqueuedAt(), normalizedGame);
                    Ticket matchedSelf = new Ticket(
                            UUID.randomUUID(), "MATCHED", matchId, Instant.now(), normalizedGame);
                    tickets.put(peerId, matchedPeer);
                    tickets.put(playerId, matchedSelf);
                    events.emit(
                            "MATCH_FOUND",
                            playerId,
                            matchId,
                            Map.of("mode", "CASUAL", "game", normalizedGame, "peerId", peerId.toString()));
                    events.emit(
                            "MATCH_FOUND",
                            peerId,
                            matchId,
                            Map.of("mode", "CASUAL", "game", normalizedGame, "peerId", playerId.toString()));
                    return toResponse(matchedSelf);
                } catch (RuntimeException createFailed) {
                    requeueSearching(peerId, peerTicket, normalizedGame);
                    Ticket searching = new Ticket(
                            UUID.randomUUID(), "SEARCHING", null, Instant.now(), normalizedGame);
                    tickets.put(playerId, searching);
                    fifoFor(normalizedGame).offer(playerId);
                    events.emit(
                            "MATCHMAKING_STARTED",
                            playerId,
                            null,
                            Map.of("mode", "CASUAL", "game", normalizedGame));
                    return toResponse(searching);
                }
            }
            Ticket searching = new Ticket(UUID.randomUUID(), "SEARCHING", null, Instant.now(), normalizedGame);
            tickets.put(playerId, searching);
            fifoFor(normalizedGame).offer(playerId);
            events.emit(
                    "MATCHMAKING_STARTED", playerId, null, Map.of("mode", "CASUAL", "game", normalizedGame));
            return toResponse(searching);
        }
    }

    public CasualQueueResponse status(UUID playerId) {
        Ticket ticket = tickets.get(playerId);
        if (ticket == null) {
            return CasualQueueResponse.idle();
        }
        return toResponse(ticket);
    }

    public CasualQueueResponse dequeue(UUID playerId) {
        synchronized (monitor) {
            Ticket ticket = tickets.remove(playerId);
            if (ticket != null) {
                removeFromFifo(ticket.game(), playerId);
            }
            return CasualQueueResponse.idle();
        }
    }

    /** Clears in-process FIFO — ITs call this so leftover SEARCHING peers do not leak. */
    public void reset() {
        synchronized (monitor) {
            fifos.clear();
            tickets.clear();
        }
    }

    private ConcurrentLinkedQueue<UUID> fifoFor(String game) {
        return fifos.computeIfAbsent(game, ignored -> new ConcurrentLinkedQueue<>());
    }

    private void removeFromFifo(String game, UUID playerId) {
        fifoFor(game).remove(playerId);
    }

    private UUID pollWaitingPeer(UUID playerId, String game) {
        ConcurrentLinkedQueue<UUID> fifo = fifoFor(game);
        UUID peerId;
        while ((peerId = fifo.poll()) != null) {
            if (peerId.equals(playerId)) {
                continue;
            }
            Ticket peerTicket = tickets.get(peerId);
            if (peerTicket != null
                    && "SEARCHING".equals(peerTicket.status())
                    && game.equals(peerTicket.game())) {
                return peerId;
            }
        }
        return null;
    }

    private void requeueSearching(UUID peerId, Ticket peerTicket, String game) {
        Ticket searching = new Ticket(peerTicket.ticketId(), "SEARCHING", null, peerTicket.enqueuedAt(), game);
        tickets.put(peerId, searching);
        fifoFor(game).offer(peerId);
    }

    private static CasualQueueResponse toResponse(Ticket ticket) {
        String mode = "MATCHED".equals(ticket.status()) ? "CASUAL" : null;
        return new CasualQueueResponse(ticket.status(), ticket.matchId(), mode, ticket.ticketId(), ticket.game());
    }

    private record Ticket(UUID ticketId, String status, UUID matchId, Instant enqueuedAt, String game) {}
}
