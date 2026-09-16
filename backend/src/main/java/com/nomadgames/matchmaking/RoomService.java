package com.nomadgames.matchmaking;

import java.security.SecureRandom;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Locale;
import java.util.UUID;

import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;
import org.springframework.web.server.ResponseStatusException;

import com.nomadgames.matchmaking.internal.JoinRateLimiter;
import com.nomadgames.matchmaking.internal.RoomEntity;
import com.nomadgames.matchmaking.internal.RoomRepository;
import com.nomadgames.session.MatchService;

@Service
public class RoomService {

    static final String CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    static final int CODE_LENGTH = 5;
    static final int MAX_CODE_ATTEMPTS = 8;
    static final Duration IDLE_TTL = Duration.ofMinutes(10);
    static final String STATUS_LOBBY = "LOBBY";
    static final String STATUS_STARTED = "STARTED";
    static final String STATUS_CLOSED = "CLOSED";

    private final RoomRepository rooms;
    private final TransactionTemplate transactions;
    private final JoinRateLimiter joinRateLimiter;
    private final MatchService matches;
    private final SecureRandom random = new SecureRandom();

    public RoomService(
            RoomRepository rooms,
            PlatformTransactionManager transactionManager,
            JoinRateLimiter joinRateLimiter,
            MatchService matches) {
        this.rooms = rooms;
        this.transactions = new TransactionTemplate(transactionManager);
        this.joinRateLimiter = joinRateLimiter;
        this.matches = matches;
    }

    public RoomCreatedResponse create(UUID playerId, String game) {
        String normalizedGame = GameDiscriminator.normalize(game);
        Instant now = Instant.now();
        Instant idleExpiresAt = now.plus(IDLE_TTL);
        DataIntegrityViolationException lastCollision = null;
        for (int attempt = 0; attempt < MAX_CODE_ATTEMPTS; attempt++) {
            String code = randomCode();
            if (rooms.findByCode(code).isPresent()) {
                continue;
            }
            try {
                RoomEntity saved = transactions.execute(status -> {
                    RoomEntity room = new RoomEntity(
                            UUID.randomUUID(),
                            code,
                            playerId,
                            STATUS_LOBBY,
                            idleExpiresAt,
                            now,
                            normalizedGame);
                    return rooms.saveAndFlush(room);
                });
                return toCreated(saved);
            } catch (DataIntegrityViolationException collision) {
                lastCollision = collision;
            }
        }
        if (lastCollision != null) {
            throw lastCollision;
        }
        throw new IllegalStateException("room code collision");
    }

    public RoomLobbyResponse join(UUID playerId, String code, String ip) {
        joinRateLimiter.check(ip, playerId);
        String normalized = normalizeCode(code);
        return transactions.execute(status -> {
            RoomEntity room = rooms.findByCodeForUpdate(normalized)
                    .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "no such room"));
            if (STATUS_CLOSED.equals(room.getStatus())) {
                throw new ResponseStatusException(HttpStatus.GONE, "host left");
            }
            if (STATUS_STARTED.equals(room.getStatus())) {
                throw new ResponseStatusException(HttpStatus.CONFLICT, "already started");
            }
            if (playerId.equals(room.getHostId())) {
                throw new IllegalArgumentException("code");
            }
            UUID joiner = room.getJoinerId();
            if (joiner != null) {
                if (joiner.equals(playerId)) {
                    return toLobby(room, playerId);
                }
                throw new ResponseStatusException(HttpStatus.CONFLICT, "already started");
            }
            room.setJoinerId(playerId);
            return toLobby(rooms.save(room), playerId);
        });
    }

    public RoomLobbyResponse get(UUID playerId, UUID roomId) {
        RoomEntity room = rooms.findById(roomId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "room"));
        if (!playerId.equals(room.getHostId()) && !playerId.equals(room.getJoinerId())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "not a seat");
        }
        return toLobby(room, playerId);
    }

    public RoomLobbyResponse ready(UUID playerId, UUID roomId) {
        RoomLobbyResponse afterFlag = transactions.execute(status -> applyReady(playerId, roomId));
        if (afterFlag.matchId() != null || !STATUS_LOBBY.equals(afterFlag.status())) {
            return afterFlag;
        }
        return transactions.execute(status -> {
            RoomEntity room = requireSeat(playerId, roomId);
            if (STATUS_CLOSED.equals(room.getStatus())) {
                throw new ResponseStatusException(HttpStatus.GONE, "host left");
            }
            if (STATUS_STARTED.equals(room.getStatus())) {
                return toLobby(room, playerId);
            }
            kickoffIfBothReady(room);
            return toLobby(rooms.save(room), playerId);
        });
    }

    public RoomLobbyResponse leave(UUID playerId, UUID roomId) {
        return transactions.execute(status -> {
            RoomEntity room = requireSeat(playerId, roomId);
            if (STATUS_LOBBY.equals(room.getStatus())) {
                if (playerId.equals(room.getHostId())) {
                    room.setStatus(STATUS_CLOSED);
                } else {
                    room.setJoinerId(null);
                    room.setJoinerReady(false);
                }
                rooms.save(room);
            }
            return toLobby(room, playerId);
        });
    }

    @Scheduled(fixedRate = 1000)
    public void closeExpiredLobbies() {
        Instant now = Instant.now();
        List<UUID> expiredIds = transactions.execute(status ->
                rooms.findByStatusAndIdleExpiresAtBefore(STATUS_LOBBY, now).stream()
                        .map(RoomEntity::getId)
                        .toList());
        if (expiredIds == null) {
            return;
        }
        for (UUID id : expiredIds) {
            transactions.execute(status -> {
                rooms.findByIdForUpdate(id).ifPresent(room -> {
                    if (STATUS_LOBBY.equals(room.getStatus()) && !room.getIdleExpiresAt().isAfter(now)) {
                        room.setStatus(STATUS_CLOSED);
                        rooms.save(room);
                    }
                });
                return null;
            });
        }
    }

    private RoomLobbyResponse applyReady(UUID playerId, UUID roomId) {
        RoomEntity room = requireSeat(playerId, roomId);
        if (STATUS_CLOSED.equals(room.getStatus())) {
            throw new ResponseStatusException(HttpStatus.GONE, "host left");
        }
        if (STATUS_STARTED.equals(room.getStatus())) {
            return toLobby(room, playerId);
        }
        if (playerId.equals(room.getHostId())) {
            room.setHostReady(true);
        } else {
            room.setJoinerReady(true);
        }
        kickoffIfBothReady(room);
        return toLobby(rooms.save(room), playerId);
    }

    private void kickoffIfBothReady(RoomEntity room) {
        if (room.isHostReady()
                && room.isJoinerReady()
                && room.getJoinerId() != null
                && room.getMatchId() == null) {
            UUID matchId = matches.createPrivateMatch(
                    room.getHostId(), room.getJoinerId(), room.getGame());
            room.setMatchId(matchId);
            room.setStatus(STATUS_STARTED);
        }
    }

    private RoomEntity requireSeat(UUID playerId, UUID roomId) {
        RoomEntity room = rooms.findByIdForUpdate(roomId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "room"));
        if (!playerId.equals(room.getHostId()) && !playerId.equals(room.getJoinerId())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "not a seat");
        }
        return room;
    }

    private String randomCode() {
        StringBuilder code = new StringBuilder(CODE_LENGTH);
        for (int i = 0; i < CODE_LENGTH; i++) {
            code.append(CODE_ALPHABET.charAt(random.nextInt(CODE_ALPHABET.length())));
        }
        return code.toString();
    }

    static String normalizeCode(String code) {
        if (code == null) {
            throw new IllegalArgumentException("code");
        }
        String normalized = code.trim().toUpperCase(Locale.ROOT);
        if (normalized.length() < 4 || normalized.length() > 6) {
            throw new IllegalArgumentException("code");
        }
        return normalized;
    }

    static String hostLabel(UUID playerId) {
        String hex = playerId.toString().replace("-", "");
        return "Guest-" + hex.substring(hex.length() - 4);
    }

    private static RoomCreatedResponse toCreated(RoomEntity room) {
        return new RoomCreatedResponse(
                room.getId(), room.getCode(), hostLabel(room.getHostId()), room.getIdleExpiresAt());
    }

    private static RoomLobbyResponse toLobby(RoomEntity room, UUID caller) {
        boolean host = caller.equals(room.getHostId());
        String joinerLabel = room.getJoinerId() == null ? null : hostLabel(room.getJoinerId());
        boolean bothReady = room.isHostReady()
                && room.isJoinerReady()
                && room.getJoinerId() != null
                && room.getMatchId() != null;
        return new RoomLobbyResponse(
                room.getId(),
                host ? room.getCode() : null,
                hostLabel(room.getHostId()),
                joinerLabel,
                room.isHostReady(),
                room.isJoinerReady(),
                room.getStatus(),
                room.getIdleExpiresAt(),
                room.getMatchId(),
                bothReady,
                room.getGame());
    }
}
