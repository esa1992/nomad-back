package com.nomadgames.session;

import java.io.IOException;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.UUID;

import org.springframework.context.annotation.Lazy;
import org.springframework.http.HttpStatus;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.nomadgames.alchiki.proto.Dyn4jBurstSim;
import com.nomadgames.analytics.EventSink;
import com.nomadgames.economy.EconomyService;
import com.nomadgames.economy.MatchRewardCommand;
import com.nomadgames.economy.RewardGrant;
import com.nomadgames.games.stickpull.StickPullBot;
import com.nomadgames.games.stickpull.StickPullConstants;
import com.nomadgames.games.stickpull.StickPullPhase;
import com.nomadgames.games.stickpull.StickPullRuntime;
import com.nomadgames.games.stickpull.StickPullSim;
import com.nomadgames.identity.internal.PlayerEntity;
import com.nomadgames.identity.internal.PlayerRepository;
import com.nomadgames.profile.ProfileService;
import com.nomadgames.profile.ProfileService.SeatSettlement;
import com.nomadgames.rating.RatingService;
import com.nomadgames.session.internal.MatchEntity;
import com.nomadgames.session.internal.MatchRepository;
import com.nomadgames.session.internal.MatchSessionRegistry;
import com.nomadgames.session.internal.MatchSessionRegistry.LiveMatch;
import com.nomadgames.session.internal.MatchSessionRegistry.RematchWindow;
import com.nomadgames.session.internal.ReconnectPolicy;
import com.nomadgames.session.internal.WsTicketService;

import tools.jackson.databind.ObjectMapper;

@Service
public class MatchService {

    private static final Logger log = LoggerFactory.getLogger(MatchService.class);

    static final String MATCH_TABLE_ID = "alchiki-match-v1";
    static final Duration REMATCH_WINDOW = Duration.ofSeconds(10);

    private final MatchRepository matches;
    private final GameEngine engine;
    private final WsTicketService tickets;
    private final MatchSessionRegistry sessions;
    private final ObjectMapper mapper;
    private final EconomyService economy;
    private final ProfileService profile;
    private final RatingService rating;
    private final StickPullRuntime stickPull;
    private final EventSink events;
    private final PlayerRepository players;
    private final MatchService self;

    public MatchService(
            MatchRepository matches,
            GameEngine engine,
            WsTicketService tickets,
            MatchSessionRegistry sessions,
            ObjectMapper mapper,
            EconomyService economy,
            ProfileService profile,
            RatingService rating,
            StickPullRuntime stickPull,
            EventSink events,
            PlayerRepository players,
            @Lazy MatchService self) {
        this.matches = matches;
        this.engine = engine;
        this.tickets = tickets;
        this.sessions = sessions;
        this.mapper = mapper;
        this.economy = economy;
        this.profile = profile;
        this.rating = rating;
        this.stickPull = stickPull;
        this.events = events;
        this.players = players;
        this.self = self;
    }

    @Transactional
    public MatchCreatedResponse createMatch(UUID playerId, CreateMatchRequest request) {
        if (request == null || !"BOT".equals(request.mode())) {
            throw new IllegalArgumentException("game/mode");
        }
        String game = request.game();
        if ("STICK_PULL".equals(game)) {
            return createStickPullBotMatch(playerId, request.difficulty());
        }
        if (!"ALCHIKI".equals(game)) {
            throw new IllegalArgumentException("game/mode");
        }
        String difficulty = request.difficulty();
        List<String> boneIds = engine.start(difficulty);
        Instant now = Instant.now();
        MatchEntity match = new MatchEntity(
                UUID.randomUUID(),
                playerId,
                "ALCHIKI",
                "BOT",
                difficulty,
                MatchStatus.IN_PLAY.name(),
                boneIds,
                "PLAYER",
                now.plus(engine.turnClock()),
                now.plus(engine.matchLimit()),
                now.plus(engine.hardCap()),
                now);
        matches.save(match);
        events.emit(
                "MATCH_STARTED",
                playerId,
                match.getId(),
                Map.of("mode", "BOT", "game", "ALCHIKI", "difficulty", difficulty));
        return toCreated(match, boneIds, economy.getLoadout(playerId));
    }

    private MatchCreatedResponse createStickPullBotMatch(UUID playerId, String difficulty) {
        String diff = requireStickPullDifficulty(difficulty);
        Instant now = Instant.now();
        Duration live = Duration.ofSeconds(StickPullConstants.DEFAULT_CLOCK_SECONDS);
        Duration cushion = Duration.ofSeconds(8);
        MatchEntity match = new MatchEntity(
                UUID.randomUUID(),
                playerId,
                "STICK_PULL",
                "BOT",
                diff,
                MatchStatus.IN_PLAY.name(),
                List.of(),
                "LIVE",
                now.plus(live).plus(cushion),
                now.plus(live).plus(cushion),
                now.plus(live).plus(cushion),
                now);
        matches.save(match);
        StickPullSim sim = new StickPullSim(now, StickPullConstants.DEFAULT_CLOCK_SECONDS);
        UUID matchId = match.getId();
        stickPull.start(
                matchId,
                sim,
                diff,
                true,
                (session, label) -> broadcastJson(
                        matchId, Map.of("type", "Countdown", "value", label, "phase", "COUNTDOWN")),
                (session, result) -> {
                    broadcastJson(matchId, stickPull.tapResolvedPayload(result, 0));
                    broadcastJson(matchId, stickPull.stickStatePayload(session, Instant.now()));
                },
                session -> broadcastJson(matchId, stickPull.stickStatePayload(session, Instant.now())),
                session -> self.settleStickPullMatch(matchId));
        events.emit(
                "MATCH_STARTED",
                playerId,
                matchId,
                Map.of("mode", "BOT", "game", "STICK_PULL", "difficulty", diff));
        return toCreated(match, List.of(), economy.getLoadout(playerId));
    }

    /**
     * Seat-bound Stick Pull tap. Server re-timestamps with Instant.now() (D-91, T-06-01).
     */
    @Transactional
    public Map<String, Object> applyTap(UUID playerId, UUID matchId, int clientSeq) {
        MatchEntity match = requireSeat(playerId, matchId);
        if (!"STICK_PULL".equals(match.getGame())) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "not stick pull");
        }
        if (!MatchStatus.IN_PLAY.name().equals(match.getStatus())) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "match settled");
        }
        if (sessions.anyDropped(matchId)) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "opponent reconnecting");
        }
        if (stickPull.isClientPaused(matchId)) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "paused");
        }
        StickPullSim sim = stickPull.sim(matchId);
        if (sim == null) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "no live tug");
        }
        Instant now = Instant.now();
        StickPullSim.Side side = stickPullSide(playerId, match);
        StickPullSim.TapResult result;
        synchronized (sim) {
            result = sim.applyAcceptedTap(side, now);
        }
        if (sim.suspect()) {
            log.info("suspect=true matchId={} playerId={}", matchId, playerId);
        }
        Map<String, Object> resolved = stickPull.tapResolvedPayload(result, clientSeq);
        broadcastJson(matchId, resolved);
        // Skip StickState when clamp/pre-phase reject — marker unchanged (WR-04).
        if (result.accepted() || result.suspect()) {
            StickPullRuntime.LiveSession session = stickPull.session(matchId);
            if (session != null) {
                broadcastJson(matchId, stickPull.stickStatePayload(session, now));
            }
        }
        if (result.phase() == StickPullPhase.SETTLED) {
            self.settleStickPullMatch(matchId);
        }
        return resolved;
    }

    /**
     * Bot Stick Pull Pause/Resume — freezes tug clock and bot taps while the human menus.
     */
    public void setStickPullClientPaused(UUID playerId, UUID matchId, boolean paused) {
        MatchEntity match = requireSeat(playerId, matchId);
        if (!"STICK_PULL".equals(match.getGame()) || !"BOT".equals(match.getMode())) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "pause not available");
        }
        if (!MatchStatus.IN_PLAY.name().equals(match.getStatus())) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "match settled");
        }
        stickPull.setClientPaused(matchId, paused);
    }

    @Transactional
    public void settleStickPullMatch(UUID matchId) {
        MatchEntity match = matches.findById(matchId).orElse(null);
        if (match == null || !MatchStatus.IN_PLAY.name().equals(match.getStatus())) {
            stickPull.remove(matchId);
            return;
        }
        StickPullSim sim = stickPull.sim(matchId);
        String status = sim != null && sim.settleStatus() != null
                ? sim.settleStatus()
                : MatchStatus.DRAW.name();
        // Sim uses PLAYER/BOT seats; human PvP must settle HOST/JOINER (outcomeForSeat + rematch).
        if (isHumanPvP(match.getMode()) && status != null) {
            if (MatchStatus.PLAYER_WIN.name().equals(status)) {
                status = MatchStatus.HOST_WIN.name();
            } else if (MatchStatus.BOT_WIN.name().equals(status)) {
                status = MatchStatus.JOINER_WIN.name();
            }
        }
        match.setStatus(status != null ? status : MatchStatus.DRAW.name());
        matches.save(match);
        stickPull.remove(matchId);
        Map<UUID, RewardGrant> grants = afterTerminal(match);
        broadcastSettled(match.getId(), snapshot(match, null, grants), grants);
    }

    private static StickPullSim.Side stickPullSide(UUID playerId, MatchEntity match) {
        if (isHumanPvP(match.getMode())) {
            if (playerId.equals(match.getHostId())) {
                return StickPullSim.Side.NEAR;
            }
            if (playerId.equals(match.getJoinerId())) {
                return StickPullSim.Side.FAR;
            }
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "not a seat");
        }
        // BOT: human is near / player seat
        return StickPullSim.Side.NEAR;
    }

    /** Human two-seat PvP: private rooms, casual Quick Match, and Ranked. */
    public static boolean isHumanPvP(String mode) {
        return "PRIVATE".equals(mode) || "CASUAL".equals(mode) || "RANKED".equals(mode);
    }

    /** Rematch dual-accept stays PRIVATE|CASUAL only (D-99) — Ranked uses Find Ranked match later. */
    public static boolean allowsRematch(String mode) {
        return "PRIVATE".equals(mode) || "CASUAL".equals(mode);
    }

    /**
     * RANKED NORMAL table. Same seats/WS/reconnect as casual; no rematch window (D-97, D-99).
     */
    @Transactional
    public UUID createRankedMatch(UUID hostId, UUID joinerId, String game) {
        requireBoundSeat(hostId);
        requireBoundSeat(joinerId);
        return createHumanMatch(hostId, joinerId, "RANKED", game);
    }

    /** WR-04: Ranked seats must be bound in DB (fail-closed beyond JWT guest claim). */
    private void requireBoundSeat(UUID playerId) {
        PlayerEntity player = players
                .findById(playerId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.FORBIDDEN, "bound required"));
        if (player.isGuest()) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "bound required");
        }
    }

    /** Allowlist EASY|NORMAL|HARD for Stick Pull bot create (ASVS L1). */
    private static String requireStickPullDifficulty(String difficulty) {
        if (difficulty == null || difficulty.isBlank()) {
            return StickPullBot.Difficulty.EASY.name();
        }
        try {
            return StickPullBot.Difficulty.valueOf(difficulty.trim().toUpperCase(java.util.Locale.ROOT)).name();
        } catch (IllegalArgumentException ex) {
            throw new IllegalArgumentException("difficulty");
        }
    }

    @Transactional(readOnly = true)
    public boolean hasInPlayHumanSeat(UUID playerId) {
        return matches.existsInPlayHumanSeat(playerId);
    }

    /**
     * PRIVATE NORMAL table. Turn is JOINER (D-30). Client cannot pick seats or difficulty (D-31).
     * playerScore column = host; botScore column = joiner.
     */
    @Transactional
    public UUID createPrivateMatch(UUID hostId, UUID joinerId) {
        return createPrivateMatch(hostId, joinerId, "ALCHIKI");
    }

    @Transactional
    public UUID createPrivateMatch(UUID hostId, UUID joinerId, String game) {
        return createHumanMatch(hostId, joinerId, "PRIVATE", game);
    }

    /**
     * CASUAL NORMAL Quick Match table. Same seats/WS/reconnect as private (D-69, SESS-02).
     */
    @Transactional
    public UUID createCasualMatch(UUID hostId, UUID joinerId) {
        return createCasualMatch(hostId, joinerId, "ALCHIKI");
    }

    @Transactional
    public UUID createCasualMatch(UUID hostId, UUID joinerId, String game) {
        return createHumanMatch(hostId, joinerId, "CASUAL", game);
    }

    private UUID createHumanMatch(UUID hostId, UUID joinerId, String mode, String game) {
        if ("STICK_PULL".equals(game)) {
            return createStickPullHumanMatch(hostId, joinerId, mode);
        }
        PrivateTable table = engine.startPrivate();
        Instant now = Instant.now();
        MatchEntity match = new MatchEntity(
                UUID.randomUUID(),
                hostId,
                "ALCHIKI",
                mode,
                "NORMAL",
                MatchStatus.IN_PLAY.name(),
                table.boneIds(),
                "JOINER",
                now.plus(engine.turnClock()),
                now.plus(engine.matchLimit()),
                now.plus(engine.hardCap()),
                now,
                hostId,
                joinerId);
        String hostToken = ReconnectPolicy.mintToken();
        String joinerToken = ReconnectPolicy.mintToken();
        match.setHostReconnectTokenHash(ReconnectPolicy.hashToken(hostToken));
        match.setJoinerReconnectTokenHash(ReconnectPolicy.hashToken(joinerToken));
        matches.save(match);
        sessions.registerPrivate(match.getId(), hostToken, joinerToken);
        events.emit(
                "MATCH_STARTED",
                hostId,
                match.getId(),
                Map.of(
                        "mode",
                        mode,
                        "game",
                        "ALCHIKI",
                        "joinerId",
                        joinerId.toString()));
        return match.getId();
    }

    private UUID createStickPullHumanMatch(UUID hostId, UUID joinerId, String mode) {
        Instant now = Instant.now();
        Duration live = Duration.ofSeconds(StickPullConstants.DEFAULT_CLOCK_SECONDS);
        Duration cushion = Duration.ofSeconds(8);
        MatchEntity match = new MatchEntity(
                UUID.randomUUID(),
                hostId,
                "STICK_PULL",
                mode,
                "NORMAL",
                MatchStatus.IN_PLAY.name(),
                List.of(),
                "LIVE",
                now.plus(live).plus(cushion),
                now.plus(live).plus(cushion),
                now.plus(live).plus(cushion),
                now,
                hostId,
                joinerId);
        String hostToken = ReconnectPolicy.mintToken();
        String joinerToken = ReconnectPolicy.mintToken();
        match.setHostReconnectTokenHash(ReconnectPolicy.hashToken(hostToken));
        match.setJoinerReconnectTokenHash(ReconnectPolicy.hashToken(joinerToken));
        matches.save(match);
        sessions.registerPrivate(match.getId(), hostToken, joinerToken);
        boolean ranked = "RANKED".equals(mode);
        StickPullSim sim = new StickPullSim(now, StickPullConstants.DEFAULT_CLOCK_SECONDS, ranked);
        UUID matchId = match.getId();
        stickPull.start(
                matchId,
                sim,
                "NORMAL",
                false,
                (session, label) -> broadcastJson(
                        matchId, Map.of("type", "Countdown", "value", label, "phase", "COUNTDOWN")),
                (session, result) -> {
                    broadcastJson(matchId, stickPull.tapResolvedPayload(result, 0));
                    broadcastJson(matchId, stickPull.stickStatePayload(session, Instant.now()));
                },
                session -> broadcastJson(matchId, stickPull.stickStatePayload(session, Instant.now())),
                session -> self.settleStickPullMatch(matchId));
        events.emit(
                "MATCH_STARTED",
                hostId,
                matchId,
                Map.of(
                        "mode",
                        mode,
                        "game",
                        "STICK_PULL",
                        "joinerId",
                        joinerId.toString()));
        return matchId;
    }

    @Transactional
    public MatchSnapshot getMatch(UUID playerId, UUID matchId) {
        MatchEntity match = requireSeat(playerId, matchId);
        if (!sessions.anyDropped(matchId)) {
            tickClocks(match, Instant.now());
        }
        matches.save(match);
        Map<UUID, RewardGrant> grants = terminalGrants(match);
        return snapshot(match, playerId, grants);
    }

    @Transactional
    public LeaveResponse leaveMatch(UUID playerId, UUID matchId) {
        MatchEntity match = requireSeat(playerId, matchId);
        if (!MatchStatus.IN_PLAY.name().equals(match.getStatus())) {
            Map<UUID, RewardGrant> prior = terminalGrants(match);
            return new LeaveResponse(snapshot(match, playerId, prior));
        }
        if ("STICK_PULL".equals(match.getGame())) {
            StickPullSim sim = stickPull.sim(matchId);
            if (sim != null) {
                sim.forceSettle(isHumanPvP(match.getMode())
                        ? (playerId.equals(match.getHostId())
                                ? MatchStatus.JOINER_WIN.name()
                                : MatchStatus.HOST_WIN.name())
                        : MatchStatus.BOT_WIN.name());
            }
            stickPull.remove(matchId);
        }
        if (isHumanPvP(match.getMode())) {
            boolean hostLeft = playerId.equals(match.getHostId());
            match.setStatus(hostLeft ? MatchStatus.JOINER_WIN.name() : MatchStatus.HOST_WIN.name());
        } else {
            match.setStatus(MatchStatus.BOT_WIN.name());
        }
        sessions.clearDrops(matchId);
        matches.save(match);
        events.emit(
                "MATCH_ABANDONED",
                playerId,
                matchId,
                Map.of("mode", match.getMode(), "game", match.getGame(), "status", match.getStatus()));
        Map<UUID, RewardGrant> grants = afterTerminal(match);
        MatchSnapshot settled = snapshot(match, playerId, grants);
        broadcastSettled(match.getId(), snapshot(match, null, grants), grants);
        return new LeaveResponse(settled);
    }

    @Transactional
    public ThrowResponse applyThrow(UUID playerId, UUID matchId, String rawJson) {
        MatchEntity match = matches.findById(matchId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "match"));
        if (isHumanPvP(match.getMode())) {
            requireSeat(playerId, matchId);
            throw new ResponseStatusException(HttpStatus.CONFLICT, "use websocket");
        }
        match = requireOwner(playerId, matchId);
        if (!MatchStatus.IN_PLAY.name().equals(match.getStatus())) {
            return new ThrowResponse(
                    forfeitThrowView(), null, snapshot(match, playerId, terminalGrants(match)));
        }
        if (!"PLAYER".equals(match.getTurn())) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "not your turn");
        }
        Instant now = Instant.now();
        boolean expiredAtStart = engine.forfeitThrowIfExpired(now, match.getTurnDeadline());
        if (expiredAtStart || !hasValidImpulse(rawJson)) {
            BotThrowView bot = expiredAtStart ? forfeitExpiredPlayerTurn(match, now) : null;
            matches.save(match);
            Map<UUID, RewardGrant> grants = terminalGrants(match);
            if (isTerminalStatus(match.getStatus())) {
                broadcastSettled(match.getId(), snapshot(match, null, grants), grants);
            }
            return new ThrowResponse(forfeitThrowView(), bot, snapshot(match, playerId, grants));
        }
        Set<String> remaining = new LinkedHashSet<>(match.getBonesLeft());
        ScoredThrow scored = engine.applyThrow(rawJson, remaining, leftoverPoses(match));
        applyPocketedBones(match, scored);
        persistLeftoverPoses(match, scored.playerThrow().keyframes(), scored.sakaOut(), scored.pocketedIds());
        match.setPlayerScore(match.getPlayerScore() + scored.displayedScore());
        match.setPlayerTurns(match.getPlayerTurns() + 1);
        match.setTurnDeadline(now.plus(engine.turnClock()));
        BotThrowView bot = resolveAndContinue(match, now);
        matches.save(match);
        Map<UUID, RewardGrant> grants = terminalGrants(match);
        if (isTerminalStatus(match.getStatus())) {
            broadcastSettled(match.getId(), snapshot(match, null, grants), grants);
        }
        return new ThrowResponse(scored.playerThrow(), bot, snapshot(match, playerId, grants));
    }

    @Transactional(readOnly = true)
    public WsTicketResponse issueWsTicket(UUID playerId, UUID matchId) {
        MatchEntity match = requireSeat(playerId, matchId);
        boolean stickPullBot = "STICK_PULL".equals(match.getGame()) && "BOT".equals(match.getMode());
        if (!isHumanPvP(match.getMode()) && !stickPullBot) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "websocket is private");
        }
        WsTicketResponse issued = tickets.issue(playerId, matchId);
        String reconnect = sessions.plaintextToken(matchId, playerId, match.getHostId(), match.getJoinerId());
        return new WsTicketResponse(issued.ticket(), issued.expiresAt(), reconnect);
    }

    @Transactional
    public RematchAcceptResponse acceptRematch(UUID playerId, UUID matchId, boolean accept) {
        MatchEntity match = requirePrivateTerminal(playerId, matchId);
        Instant now = Instant.now();
        RematchWindow window = sessions.openRematch(
                matchId, match.getHostId(), match.getJoinerId(), now.plus(REMATCH_WINDOW));
        synchronized (window) {
            if (window.newMatchId != null) {
                return new RematchAcceptResponse(
                        true, window.newMatchId, remainingSeconds(window.deadline, now), "JOINER");
            }
            if (window.rejected || !now.isBefore(window.deadline)) {
                throw new ResponseStatusException(
                        window.rejected ? HttpStatus.CONFLICT : HttpStatus.GONE, "rematch expired");
            }
            if (!accept) {
                window.rejected = true;
                window.deadline = Instant.EPOCH;
                return new RematchAcceptResponse(false, null, 0, null);
            }
            if (playerId.equals(match.getHostId())) {
                window.acceptedHost = true;
            } else {
                window.acceptedJoiner = true;
            }
            if (window.acceptedHost && window.acceptedJoiner) {
                // CASUAL dual-accept mints another CASUAL table; PRIVATE stays createPrivateMatch (D-71).
                String rematchGame = match.getGame();
                UUID newId = "CASUAL".equals(match.getMode())
                        ? createCasualMatch(window.hostId, window.joinerId, rematchGame)
                        : createPrivateMatch(window.hostId, window.joinerId, rematchGame);
                window.newMatchId = newId;
                broadcastRematchReady(matchId, newId);
                return new RematchAcceptResponse(true, newId, remainingSeconds(window.deadline, now), "JOINER");
            }
            return new RematchAcceptResponse(true, null, remainingSeconds(window.deadline, now), null);
        }
    }

    @Transactional(readOnly = true)
    public RematchPollResponse getRematch(UUID playerId, UUID matchId) {
        MatchEntity match = requirePrivateTerminal(playerId, matchId);
        Instant now = Instant.now();
        RematchWindow window = sessions.openRematch(
                matchId, match.getHostId(), match.getJoinerId(), now.plus(REMATCH_WINDOW));
        synchronized (window) {
            boolean expired =
                    window.rejected || (window.newMatchId == null && !now.isBefore(window.deadline));
            return new RematchPollResponse(
                    window.acceptedHost,
                    window.acceptedJoiner,
                    remainingSeconds(window.deadline, now),
                    window.newMatchId,
                    expired);
        }
    }

    @Transactional
    public PrivateThrowResult applyPrivateThrow(UUID playerId, UUID matchId, String rawJson) {
        MatchEntity match = requireSeat(playerId, matchId);
        if (!isHumanPvP(match.getMode())) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "not a private match");
        }
        if (!MatchStatus.IN_PLAY.name().equals(match.getStatus())) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "match settled");
        }
        if (sessions.anyDropped(matchId)) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "opponent reconnecting");
        }
        boolean joinerTurn = "JOINER".equals(match.getTurn());
        boolean hostTurn = "HOST".equals(match.getTurn());
        if (joinerTurn && !playerId.equals(match.getJoinerId())) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "not your turn");
        }
        if (hostTurn && !playerId.equals(match.getHostId())) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "not your turn");
        }
        if (!hasValidImpulse(rawJson)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "invalid throw");
        }
        Instant now = Instant.now();
        String throwingSakaId = joinerTurn ? "saka-joiner" : "saka-host";
        List<String> parkedSakaIds = List.of(joinerTurn ? "saka-host" : "saka-joiner");
        Set<String> remaining = new LinkedHashSet<>(match.getBonesLeft());
        ScoredThrow scored =
                engine.applyThrow(rawJson, remaining, throwingSakaId, parkedSakaIds, leftoverPoses(match));
        applyPocketedBones(match, scored);
        persistLeftoverPoses(match, scored.playerThrow().keyframes(), scored.sakaOut(), scored.pocketedIds());
        if (joinerTurn) {
            match.setBotScore(match.getBotScore() + scored.displayedScore());
            match.setBotTurns(match.getBotTurns() + 1);
            match.setTurn("HOST");
            if (scored.displayedScore() > 0) {
                noteLastKnockOut(matchId, "JOINER");
            }
        } else {
            match.setPlayerScore(match.getPlayerScore() + scored.displayedScore());
            match.setPlayerTurns(match.getPlayerTurns() + 1);
            match.setTurn("JOINER");
            if (scored.displayedScore() > 0) {
                noteLastKnockOut(matchId, "HOST");
            }
        }
        match.setTurnDeadline(now.plus(engine.turnClock()));
        match.setStatus(resolveHumanAlchikiStatus(match, matchId, now));
        matches.save(match);
        sessions.recordThrow(matchId, scored.playerThrow());
        Map<UUID, RewardGrant> grants = terminalGrants(match);
        if (isTerminalStatus(match.getStatus())) {
            broadcastSettled(match.getId(), snapshot(match, null, grants), grants);
        }
        return new PrivateThrowResult(scored.playerThrow(), snapshot(match, playerId, grants));
    }

    public BotThrowView tickClocks(MatchEntity match, Instant now) {
        if (!MatchStatus.IN_PLAY.name().equals(match.getStatus())) {
            return null;
        }
        if (sessions.anyDropped(match.getId())) {
            return null;
        }
        if ("PLAYER".equals(match.getTurn()) && engine.forfeitThrowIfExpired(now, match.getTurnDeadline())) {
            return forfeitExpiredPlayerTurn(match, now);
        }
        return null;
    }

    @Transactional
    public void markDropped(UUID playerId, UUID matchId) {
        MatchEntity match = requireSeat(playerId, matchId);
        if (!isHumanPvP(match.getMode()) || !MatchStatus.IN_PLAY.name().equals(match.getStatus())) {
            return;
        }
        Instant now = Instant.now();
        LiveMatch live = sessions.live(matchId);
        if (live == null) {
            return;
        }
        boolean hostSeat = playerId.equals(match.getHostId());
        if (hostSeat && live.hostDropped() || !hostSeat && live.joinerDropped()) {
            return;
        }
        // D-102: next drop after Ranked pause budget → immediate rated forfeit (no bot-fill).
        int budgetSec = ReconnectPolicy.pauseBudgetSeconds(match.getMode(), match.getGame());
        if ("RANKED".equals(match.getMode()) && live.pauseUsedMs >= budgetSec * 1000L) {
            live.pauseBudgetGone = true;
            if (!live.anyDropped()) {
                live.frozen = ReconnectPolicy.freeze(
                        now, match.getTurnDeadline(), match.getMatchDeadline(), match.getHardCap());
                if ("STICK_PULL".equals(match.getGame())) {
                    StickPullSim tug = stickPull.sim(matchId);
                    if (tug != null) {
                        synchronized (tug) {
                            tug.pauseClock(now);
                        }
                    }
                }
            }
            settleExpiredDrop(match, hostSeat);
            return;
        }
        if (!live.anyDropped()) {
            live.frozen = ReconnectPolicy.freeze(
                    now, match.getTurnDeadline(), match.getMatchDeadline(), match.getHardCap());
            if ("STICK_PULL".equals(match.getGame())) {
                StickPullSim tug = stickPull.sim(matchId);
                if (tug != null) {
                    synchronized (tug) {
                        tug.pauseClock(now);
                    }
                }
            }
        }
        int grace = ReconnectPolicy.graceSeconds(match.getMode(), match.getGame());
        Instant deadline = ReconnectPolicy.graceDeadline(now, match.getMode(), match.getGame());
        if (hostSeat) {
            live.hostGraceDeadline = deadline;
        } else {
            live.joinerGraceDeadline = deadline;
        }
        if (live.pauseAccrueStartedAt == null) {
            live.pauseAccrueStartedAt = now;
        }
        broadcastJson(
                matchId,
                Map.of("type", "OpponentDropped", "secondsLeft", grace));
    }

    @Transactional
    public RejoinSnapshot rejoin(UUID playerId, UUID matchId, String token) {
        MatchEntity match = requireSeat(playerId, matchId);
        if (!isHumanPvP(match.getMode())) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "not a private match");
        }
        boolean hostSeat = playerId.equals(match.getHostId());
        byte[] stored = hostSeat ? match.getHostReconnectTokenHash() : match.getJoinerReconnectTokenHash();
        if (!ReconnectPolicy.tokenMatches(stored, token)) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "invalid reconnect token");
        }
        Instant now = Instant.now();
        LiveMatch live = sessions.live(matchId);
        if (!MatchStatus.IN_PLAY.name().equals(match.getStatus())) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "match settled");
        }
        Instant graceDeadline = live == null
                ? null
                : hostSeat ? live.hostGraceDeadline : live.joinerGraceDeadline;
        if (graceDeadline != null && !now.isBefore(graceDeadline)) {
            settleExpiredDrop(match, hostSeat);
            throw new ResponseStatusException(HttpStatus.GONE, "reconnect expired");
        }
        if (graceDeadline == null) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "seat not dropped");
        }
        String rotated = ReconnectPolicy.mintToken();
        if (hostSeat) {
            match.setHostReconnectTokenHash(ReconnectPolicy.hashToken(rotated));
            live.hostToken = rotated;
            live.hostGraceDeadline = null;
        } else {
            match.setJoinerReconnectTokenHash(ReconnectPolicy.hashToken(rotated));
            live.joinerToken = rotated;
            live.joinerGraceDeadline = null;
        }
        if (!live.anyDropped()) {
            accruePauseBudget(live, match, now);
        }
        if (!live.anyDropped() && live.frozen != null) {
            ReconnectPolicy.applyFreeze(match, live.frozen, now);
            live.frozen = null;
        }
        if (!live.anyDropped() && "STICK_PULL".equals(match.getGame())) {
            StickPullSim tug = stickPull.sim(matchId);
            if (tug != null) {
                synchronized (tug) {
                    tug.resumeClock(now);
                }
            }
        }
        matches.save(match);
        broadcastJson(matchId, Map.of("type", "OpponentRejoined"));
        List<BodyPoseView> poses = live.sakaPoses == null ? List.of() : live.sakaPoses;
        return new RejoinSnapshot(
                "RejoinSnapshot",
                snapshot(match, playerId, terminalGrants(match)),
                live.lastThrow,
                poses,
                rotated);
    }

    @Transactional
    public void clearSeatDrop(UUID playerId, UUID matchId) {
        MatchEntity match = requireSeat(playerId, matchId);
        LiveMatch live = sessions.live(matchId);
        if (live == null) {
            return;
        }
        Instant now = Instant.now();
        boolean hostSeat = playerId.equals(match.getHostId());
        if (hostSeat) {
            live.hostGraceDeadline = null;
        } else {
            live.joinerGraceDeadline = null;
        }
        if (!live.anyDropped()) {
            accruePauseBudget(live, match, now);
        }
        if (!live.anyDropped() && live.frozen != null) {
            ReconnectPolicy.applyFreeze(match, live.frozen, now);
            live.frozen = null;
            matches.save(match);
        }
        if (!live.anyDropped() && "STICK_PULL".equals(match.getGame())) {
            StickPullSim tug = stickPull.sim(matchId);
            if (tug != null) {
                synchronized (tug) {
                    tug.resumeClock(now);
                }
            }
        }
    }

    @Scheduled(fixedRate = 1000)
    @Transactional
    public void expireReconnectGraces() {
        Instant now = Instant.now();
        for (UUID matchId : sessions.liveMatchIds()) {
            LiveMatch live = sessions.live(matchId);
            if (live == null || !live.anyDropped()) {
                continue;
            }
            boolean hostExpired = live.hostGraceDeadline != null && !now.isBefore(live.hostGraceDeadline);
            boolean joinerExpired = live.joinerGraceDeadline != null && !now.isBefore(live.joinerGraceDeadline);
            if (!hostExpired && !joinerExpired) {
                continue;
            }
            MatchEntity match = matches.findById(matchId).orElse(null);
            if (match == null || !isHumanPvP(match.getMode())
                    || !MatchStatus.IN_PLAY.name().equals(match.getStatus())) {
                sessions.clearDrops(matchId);
                continue;
            }
            settleExpiredDrop(match, joinerExpired ? false : true);
        }
    }

    private void settleExpiredDrop(MatchEntity match, boolean droppedHost) {
        // Remaining human wins. Never fill a private/ranked seat with a bot (D-42, D-103).
        LiveMatch live = sessions.live(match.getId());
        if (live != null) {
            accruePauseBudget(live, match, Instant.now());
        }
        match.setStatus(ReconnectPolicy.remainingWinStatus(droppedHost));
        matches.save(match);
        sessions.clearDrops(match.getId());
        if ("STICK_PULL".equals(match.getGame())) {
            StickPullSim sim = stickPull.sim(match.getId());
            if (sim != null) {
                sim.forceSettle(ReconnectPolicy.remainingWinStatus(droppedHost));
            }
            stickPull.remove(match.getId());
        }
        Map<UUID, RewardGrant> grants = afterTerminal(match);
        broadcastSettled(match.getId(), snapshot(match, null, grants), grants);
    }

    /** Accrue grace wall-time into pauseUsedMs; flip pauseBudgetGone when Ranked budget hit (D-102). */
    private static void accruePauseBudget(LiveMatch live, MatchEntity match, Instant now) {
        if (live.pauseAccrueStartedAt != null) {
            long delta = Duration.between(live.pauseAccrueStartedAt, now).toMillis();
            if (delta > 0) {
                live.pauseUsedMs += delta;
            }
            live.pauseAccrueStartedAt = null;
        }
        if (!"RANKED".equals(match.getMode())) {
            return;
        }
        long budgetMs = ReconnectPolicy.pauseBudgetSeconds(match.getMode(), match.getGame()) * 1000L;
        if (live.pauseUsedMs >= budgetMs) {
            live.pauseBudgetGone = true;
        }
    }

    private void broadcastJson(UUID matchId, Map<String, ?> frame) {
        List<WebSocketSession> open = sessions.sessionsFor(matchId);
        if (open.isEmpty()) {
            return;
        }
        try {
            TextMessage message = new TextMessage(mapper.writeValueAsString(frame));
            for (WebSocketSession session : open) {
                if (session.isOpen()) {
                    session.sendMessage(message);
                }
            }
        } catch (IOException ignored) {
            // Remaining sockets may already be closing.
        }
    }

    public BotThrowView forfeitExpiredPlayerTurn(MatchEntity match, Instant now) {
        if (!MatchStatus.IN_PLAY.name().equals(match.getStatus())) {
            return null;
        }
        if (!engine.forfeitThrowIfExpired(now, match.getTurnDeadline())) {
            return null;
        }
        match.setPlayerTurns(match.getPlayerTurns() + 1);
        BotThrowView bot = resolveAndContinue(match, now);
        if (MatchStatus.IN_PLAY.name().equals(match.getStatus()) && "PLAYER".equals(match.getTurn())) {
            match.setTurnDeadline(now.plus(engine.turnClock()));
        }
        return bot;
    }

    /**
     * After a player throw or forfeit that leaves IN_PLAY, run the bot half via GameEngine.
     */
    protected BotThrowView afterPlayerHalfIfInPlay(MatchEntity match, Instant now) {
        if (!MatchStatus.IN_PLAY.name().equals(match.getStatus())) {
            return null;
        }
        Set<String> remainingBoneIds = new LinkedHashSet<>(match.getBonesLeft());
        int seed = Objects.hash(match.getId(), match.getBotTurns());
        BotThrowView bot = engine.nextBotThrow(
                match.getDifficulty(), seed, MATCH_TABLE_ID, remainingBoneIds, leftoverPoses(match));
        applyPocketedBones(match, bot.sakaOut(), bot.pocketedIds());
        persistLeftoverPoses(match, bot.keyframes(), bot.sakaOut(), bot.pocketedIds());
        match.setBotScore(match.getBotScore() + bot.displayedScore());
        match.setBotTurns(match.getBotTurns() + 1);
        match.setTurnDeadline(now.plus(engine.turnClock()));
        match.setStatus(engine.resolve(scoreClock(match), now).name());
        return bot;
    }

    private BotThrowView resolveAndContinue(MatchEntity match, Instant now) {
        match.setStatus(engine.resolve(scoreClock(match), now).name());
        if (MatchStatus.IN_PLAY.name().equals(match.getStatus())) {
            return afterPlayerHalfIfInPlay(match, now);
        }
        return null;
    }

    private static ScoreClock scoreClock(MatchEntity match) {
        return new ScoreClock(
                match.getPlayerScore(),
                match.getBotScore(),
                match.getPlayerTurns(),
                match.getBotTurns(),
                match.getMatchDeadline(),
                match.getHardCap(),
                false,
                match.getBonesLeft() == null ? 0 : match.getBonesLeft().size());
    }

    private static ScoreClock privateScoreClock(MatchEntity match) {
        return new ScoreClock(
                match.getPlayerScore(),
                match.getBotScore(),
                match.getPlayerTurns(),
                match.getBotTurns(),
                match.getMatchDeadline(),
                match.getHardCap(),
                true,
                match.getBonesLeft() == null ? 0 : match.getBonesLeft().size());
    }

    /**
     * Valid knock-outs leave the table. Saka-out foul zeroes the throw and restores
     * any sohi that left the circle (they stay in bonesLeft).
     */
    private static void applyPocketedBones(MatchEntity match, ScoredThrow scored) {
        applyPocketedBones(match, scored.sakaOut(), scored.pocketedIds());
    }

    private static void applyPocketedBones(
            MatchEntity match, boolean sakaOut, List<String> pocketedIds) {
        if (sakaOut || pocketedIds == null || pocketedIds.isEmpty()) {
            return;
        }
        List<String> bonesLeft = new ArrayList<>(match.getBonesLeft());
        bonesLeft.removeAll(pocketedIds);
        match.setBonesLeft(bonesLeft);
    }

    private static List<BodyPoseView> leftoverPoses(MatchEntity match) {
        List<BodyPoseView> stored = match.getBonePoses();
        if (stored == null || stored.isEmpty()) {
            return List.of();
        }
        Set<String> remaining = new LinkedHashSet<>(match.getBonesLeft());
        List<BodyPoseView> poses = new ArrayList<>();
        for (BodyPoseView pose : stored) {
            if (pose != null && remaining.contains(pose.id())) {
                poses.add(pose);
            }
        }
        return poses;
    }

    /**
     * Keep in-circle rest poses for the next throw. Saka-out foul puts knocked sohi
     * back on the seed line; pocketed sohi on a legal throw are omitted.
     */
    private static void persistLeftoverPoses(
            MatchEntity match, List<KeyframeView> keyframes, boolean sakaOut, List<String> pocketedIds) {
        Map<String, BodyPoseView> next = new LinkedHashMap<>();
        Set<String> remaining = new LinkedHashSet<>(match.getBonesLeft());
        for (BodyPoseView pose : leftoverPoses(match)) {
            if (remaining.contains(pose.id())) {
                next.put(pose.id(), pose);
            }
        }
        if (keyframes != null && !keyframes.isEmpty()) {
            List<BodyPoseView> last = keyframes.get(keyframes.size() - 1).bodies();
            if (last != null) {
                for (BodyPoseView pose : last) {
                    if (pose == null || pose.id() == null || pose.id().startsWith("saka")) {
                        continue;
                    }
                    if (remaining.contains(pose.id())) {
                        next.put(pose.id(), pose);
                    }
                }
            }
        }
        if (sakaOut && pocketedIds != null) {
            for (String id : pocketedIds) {
                if (remaining.contains(id)) {
                    var seed = Dyn4jBurstSim.seedBonePose(id);
                    next.put(id, new BodyPoseView(seed.id, seed.x, seed.y, seed.angle));
                }
            }
        }
        match.setBonePoses(new ArrayList<>(next.values()));
    }

    /** Rematch eligibility for finished PRIVATE|CASUAL only (D-99). Seat-bound via requireSeat (T-05-04). */
    private MatchEntity requirePrivateTerminal(UUID playerId, UUID matchId) {
        MatchEntity match = requireSeat(playerId, matchId);
        if (!allowsRematch(match.getMode())) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "not private");
        }
        if (!isTerminalPrivate(match.getStatus())) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "not settled");
        }
        return match;
    }

    private static boolean isTerminalPrivate(String status) {
        return MatchStatus.HOST_WIN.name().equals(status)
                || MatchStatus.JOINER_WIN.name().equals(status)
                || MatchStatus.DRAW.name().equals(status);
    }

    private static int remainingSeconds(Instant deadline, Instant now) {
        long seconds = Duration.between(now, deadline).getSeconds();
        if (seconds < 0) {
            return 0;
        }
        if (seconds > 10) {
            return 10;
        }
        return (int) seconds;
    }

    private void broadcastRematchReady(UUID finishedMatchId, UUID newMatchId) {
        List<WebSocketSession> open = sessions.sessionsFor(finishedMatchId);
        if (open.isEmpty()) {
            return;
        }
        Map<String, Object> frame = new LinkedHashMap<>();
        frame.put("type", "RematchReady");
        frame.put("matchId", newMatchId.toString());
        frame.put("turn", "JOINER");
        try {
            TextMessage message = new TextMessage(mapper.writeValueAsString(frame));
            for (WebSocketSession session : open) {
                if (session.isOpen()) {
                    session.sendMessage(message);
                }
            }
        } catch (IOException ignored) {
            // Finished-match sockets may already be closing.
        }
    }

    private void broadcastSettled(UUID matchId, MatchSnapshot snapshot, Map<UUID, RewardGrant> grants) {
        List<WebSocketSession> open = sessions.sessionsFor(matchId);
        if (open.isEmpty()) {
            return;
        }
        try {
            Map<String, Object> frame = new LinkedHashMap<>();
            frame.put("type", "MatchSettled");
            frame.put("match", snapshot);
            frame.put("grants", grantsPayload(grants));
            TextMessage message = new TextMessage(mapper.writeValueAsString(frame));
            for (WebSocketSession session : open) {
                if (session.isOpen()) {
                    session.sendMessage(message);
                }
            }
        } catch (IOException ignored) {
            // Remaining sockets may already be closing after consented leave.
        }
    }

    private static Map<String, Map<String, Integer>> grantsPayload(Map<UUID, RewardGrant> grants) {
        Map<String, Map<String, Integer>> out = new LinkedHashMap<>();
        for (Map.Entry<UUID, RewardGrant> entry : grants.entrySet()) {
            RewardGrant g = entry.getValue() == null ? RewardGrant.NONE : entry.getValue();
            out.put(entry.getKey().toString(), Map.of("coins", g.coins(), "gems", g.gems()));
        }
        return out;
    }

    /**
     * Sync COINS/GEMS + profile XP/W/L/soft Elo for every paid human seat inside the settle TX
     * (D-45, D-75). Idempotent on retry.
     */
    private Map<UUID, RewardGrant> afterTerminal(MatchEntity match) {
        Map<UUID, RewardGrant> grants = new LinkedHashMap<>();
        boolean humanMatch = isHumanPvP(match.getMode());
        if (humanMatch) {
            if (match.getHostId() != null) {
                grants.put(match.getHostId(), grantSeat(match, match.getHostId(), true));
            }
            if (match.getJoinerId() != null) {
                grants.put(match.getJoinerId(), grantSeat(match, match.getJoinerId(), true));
            }
        } else if (match.getPlayerId() != null) {
            grants.put(match.getPlayerId(), grantSeat(match, match.getPlayerId(), false));
        }
        recordProfileSettlements(match);
        UUID actor = match.getHostId() != null ? match.getHostId() : match.getPlayerId();
        events.emit(
                "MATCH_FINISHED",
                actor,
                match.getId(),
                Map.of("mode", match.getMode(), "game", match.getGame(), "status", match.getStatus()));
        return grants;
    }

    private void recordProfileSettlements(MatchEntity match) {
        List<SeatSettlement> seats = new ArrayList<>();
        if (isHumanPvP(match.getMode())) {
            if (match.getHostId() != null) {
                seats.add(new SeatSettlement(match.getHostId(), outcomeForSeat(match, match.getHostId())));
            }
            if (match.getJoinerId() != null) {
                seats.add(new SeatSettlement(match.getJoinerId(), outcomeForSeat(match, match.getJoinerId())));
            }
        } else if (match.getPlayerId() != null) {
            seats.add(new SeatSettlement(match.getPlayerId(), outcomeForSeat(match, match.getPlayerId())));
        }
        if (!seats.isEmpty()) {
            // XP/W/L always; SoftElo only inside ProfileService when CASUAL (D-104).
            profile.recordSettlement(match.getId(), match.getMode(), match.getGame(), seats);
            if ("RANKED".equals(match.getMode())) {
                rating.recordRankedSettlement(match.getId(), match.getGame(), seats);
            }
        }
    }

    /**
     * Ranked Alchiki: last successful knock-out wins; if none → DRAW (Glicko 0.5/0.5).
     * Casual/Private keep raw score draw.
     */
    private String resolveHumanAlchikiStatus(MatchEntity match, UUID matchId, Instant now) {
        String status = engine.resolve(privateScoreClock(match), now).name();
        if (!"RANKED".equals(match.getMode()) || !MatchStatus.DRAW.name().equals(status)) {
            return status;
        }
        LiveMatch live = sessions.live(matchId);
        if (live == null || live.lastKnockOutSeat == null) {
            return MatchStatus.DRAW.name();
        }
        if ("HOST".equals(live.lastKnockOutSeat)) {
            return MatchStatus.HOST_WIN.name();
        }
        if ("JOINER".equals(live.lastKnockOutSeat)) {
            return MatchStatus.JOINER_WIN.name();
        }
        return MatchStatus.DRAW.name();
    }

    private void noteLastKnockOut(UUID matchId, String seat) {
        LiveMatch live = sessions.live(matchId);
        if (live != null) {
            live.lastKnockOutSeat = seat;
        }
    }

    private Map<UUID, RewardGrant> terminalGrants(MatchEntity match) {
        if (!isTerminalStatus(match.getStatus())) {
            return Map.of();
        }
        return afterTerminal(match);
    }

    private RewardGrant grantSeat(MatchEntity match, UUID playerId, boolean humanMatch) {
        String outcome = outcomeForSeat(match, playerId);
        return economy.grantMatchRewards(new MatchRewardCommand(
                match.getId(), playerId, outcome, match.getDifficulty(), humanMatch));
    }

    private static String outcomeForSeat(MatchEntity match, UUID seat) {
        String status = match.getStatus();
        if (MatchStatus.DRAW.name().equals(status)) {
            return "DRAW";
        }
        if (isHumanPvP(match.getMode())) {
            if (MatchStatus.HOST_WIN.name().equals(status)) {
                return seat.equals(match.getHostId()) ? "WIN" : "LOSS";
            }
            if (MatchStatus.JOINER_WIN.name().equals(status)) {
                return seat.equals(match.getJoinerId()) ? "WIN" : "LOSS";
            }
            return "LOSS";
        }
        if (MatchStatus.PLAYER_WIN.name().equals(status)) {
            return "WIN";
        }
        if (MatchStatus.BOT_WIN.name().equals(status)) {
            return "LOSS";
        }
        return "DRAW";
    }

    private static boolean isTerminalStatus(String status) {
        return MatchStatus.PLAYER_WIN.name().equals(status)
                || MatchStatus.BOT_WIN.name().equals(status)
                || MatchStatus.DRAW.name().equals(status)
                || MatchStatus.HOST_WIN.name().equals(status)
                || MatchStatus.JOINER_WIN.name().equals(status);
    }

    private MatchEntity requireOwner(UUID playerId, UUID matchId) {
        MatchEntity match = matches.findById(matchId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "match"));
        if (!match.getPlayerId().equals(playerId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "not owner");
        }
        return match;
    }

    /** PRIVATE: host or joiner. BOT: owner player_id. Third guest is 403 (T-03-15). */
    private MatchEntity requireSeat(UUID playerId, UUID matchId) {
        MatchEntity match = matches.findById(matchId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "match"));
        if (isHumanPvP(match.getMode())) {
            if (!playerId.equals(match.getHostId()) && !playerId.equals(match.getJoinerId())) {
                throw new ResponseStatusException(HttpStatus.FORBIDDEN, "not a seat");
            }
            return match;
        }
        if (!match.getPlayerId().equals(playerId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "not owner");
        }
        return match;
    }

    private static boolean hasValidImpulse(String rawJson) {
        if (rawJson == null || rawJson.isBlank()) {
            return false;
        }
        return rawJson.contains("\"aimAngleRad\"") && rawJson.contains("\"holdMs\"");
    }

    private static PlayerThrowView forfeitThrowView() {
        return new PlayerThrowView(1, true, true, "forfeit", 0, 0, false, 0, List.of(), List.of());
    }

    private MatchCreatedResponse toCreated(MatchEntity match, List<String> boneIds, Map<String, String> localLoadout) {
        return new MatchCreatedResponse(
                match.getId(),
                match.getStatus(),
                match.getGame(),
                match.getDifficulty(),
                List.copyOf(boneIds),
                match.getPlayerScore(),
                match.getBotScore(),
                match.getTurn(),
                match.getTurnDeadline().toEpochMilli(),
                match.getMatchDeadline().toEpochMilli(),
                match.getHardCap().toEpochMilli(),
                localLoadout == null ? Map.of() : Map.copyOf(localLoadout));
    }

    private MatchSnapshot snapshot(MatchEntity match, UUID viewerId, Map<UUID, RewardGrant> grants) {
        RewardGrant grant = RewardGrant.NONE;
        if (viewerId != null && grants != null) {
            grant = grants.getOrDefault(viewerId, RewardGrant.NONE);
        }
        Map<String, String> hostLoadout = Map.of();
        Map<String, String> joinerLoadout = Map.of();
        Map<String, String> localLoadout = Map.of();
        if (isHumanPvP(match.getMode())) {
            if (match.getHostId() != null) {
                hostLoadout = economy.getLoadout(match.getHostId());
            }
            if (match.getJoinerId() != null) {
                joinerLoadout = economy.getLoadout(match.getJoinerId());
            }
            if (viewerId != null) {
                if (viewerId.equals(match.getHostId())) {
                    localLoadout = hostLoadout;
                } else if (viewerId.equals(match.getJoinerId())) {
                    localLoadout = joinerLoadout;
                }
            }
        } else if (match.getPlayerId() != null) {
            localLoadout = economy.getLoadout(match.getPlayerId());
        }
        // Ranked has no bot difficulty — omit from projection (RankedQueueIT).
        String difficultyOut = "RANKED".equals(match.getMode()) ? null : match.getDifficulty();
        return new MatchSnapshot(
                match.getStatus(),
                match.getPlayerScore(),
                match.getBotScore(),
                match.getTurn(),
                List.copyOf(match.getBonesLeft()),
                match.getPlayerTurns(),
                match.getBotTurns(),
                match.getTurnDeadline().toEpochMilli(),
                match.getMatchDeadline().toEpochMilli(),
                match.getHardCap().toEpochMilli(),
                match.getMode(),
                difficultyOut,
                match.getHostId(),
                match.getJoinerId(),
                match.getHostId() == null ? null : seatLabel(match.getHostId()),
                match.getJoinerId() == null ? null : seatLabel(match.getJoinerId()),
                remainingGraceSeconds(match, viewerId),
                pauseBudgetGoneFlag(match),
                grant.coins(),
                grant.gems(),
                localLoadout,
                hostLoadout,
                joinerLoadout);
    }

    private Boolean pauseBudgetGoneFlag(MatchEntity match) {
        LiveMatch live = sessions.live(match.getId());
        if (live == null || !live.pauseBudgetGone) {
            return null;
        }
        return Boolean.TRUE;
    }

    private Integer remainingGraceSeconds(MatchEntity match, UUID viewerId) {
        if (viewerId == null) {
            return null;
        }
        LiveMatch live = sessions.live(match.getId());
        if (live == null) {
            return null;
        }
        Instant deadline = null;
        if (viewerId.equals(match.getHostId())) {
            deadline = live.hostGraceDeadline;
        } else if (viewerId.equals(match.getJoinerId())) {
            deadline = live.joinerGraceDeadline;
        }
        if (deadline == null) {
            return null;
        }
        long millis = Duration.between(Instant.now(), deadline).toMillis();
        if (millis <= 0) {
            return 0;
        }
        int seconds = (int) Math.ceil(millis / 1000.0);
        return Math.min(seconds, ReconnectPolicy.graceSeconds(match.getMode(), match.getGame()));
    }

    static String seatLabel(UUID playerId) {
        String hex = playerId.toString().replace("-", "");
        return "Guest-" + hex.substring(hex.length() - 4);
    }
}
