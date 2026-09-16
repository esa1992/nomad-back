package com.nomadgames.profile;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import com.nomadgames.economy.EconomyService;
import com.nomadgames.profile.internal.ProfileJdbc;
import com.nomadgames.profile.internal.ProfileJdbc.GameStatsRow;
import com.nomadgames.profile.internal.ProfileJdbc.PlayerProfileRow;

@Service
public class ProfileService {

    static final Set<String> AVATAR_PRESETS = Set.of(
            "avatar_01",
            "avatar_02",
            "avatar_03",
            "avatar_04",
            "avatar_05",
            "avatar_06",
            "avatar_07",
            "avatar_08");

    private static final String GAME_ALCHIKI = "ALCHIKI";
    private static final String GAME_STICK_PULL = "STICK_PULL";

    private final ProfileJdbc jdbc;
    private final EconomyService economy;

    public ProfileService(ProfileJdbc jdbc, EconomyService economy) {
        this.jdbc = jdbc;
        this.economy = economy;
    }

    @Transactional
    public void ensureDefaults(UUID playerId) {
        jdbc.ensureGameStatsRow(playerId, GAME_ALCHIKI);
        jdbc.ensureGameStatsRow(playerId, GAME_STICK_PULL);
    }

    @Transactional
    public ProfileView getProfile(UUID playerId) {
        ensureDefaults(playerId);
        PlayerProfileRow row = jdbc.findPlayer(playerId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "player"));
        Map<String, GameStatsView> games = gamesMap(jdbc.listGameStats(playerId));
        GameStatsView alchiki = games.getOrDefault(camelGame(GAME_ALCHIKI), emptyStats(true));
        int matches = alchiki.matches();
        int wins = alchiki.wins();
        int losses = alchiki.losses();
        double winRate = matches == 0 ? 0.0 : (double) wins / (double) matches;
        Map<String, String> cosmetics = economy.getLoadout(playerId);
        return new ProfileView(
                "Guest",
                guestSubtitle(playerId),
                row.avatarPreset(),
                row.level(),
                row.xp(),
                xpToNext(row.xp(), row.level()),
                matches,
                wins,
                losses,
                winRate,
                row.softRating(),
                row.bestRating(),
                cosmetics,
                games);
    }

    @Transactional
    public ProfileView setAvatar(UUID playerId, String avatarPreset) {
        if (avatarPreset == null || !AVATAR_PRESETS.contains(avatarPreset)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "avatar_preset");
        }
        ensureDefaults(playerId);
        jdbc.setAvatarPreset(playerId, avatarPreset);
        return getProfile(playerId);
    }

    /**
     * Sync XP/W/L/soft Elo inside the caller's settle TX (D-75). Idempotent on (matchId, playerId).
     * Elo only when mode is CASUAL and both seats are present.
     */
    @Transactional
    public void recordSettlement(UUID matchId, String mode, String game, List<SeatSettlement> seats) {
        if (matchId == null || seats == null || seats.isEmpty()) {
            return;
        }
        String statsGame = game == null || game.isBlank() ? GAME_ALCHIKI : game;
        boolean casual = "CASUAL".equals(mode);

        boolean allClaimed = true;
        int claimedCount = 0;
        for (SeatSettlement seat : seats) {
            if (seat == null || seat.playerId() == null) {
                allClaimed = false;
                continue;
            }
            ensureDefaults(seat.playerId());
            // Lock first so a missing player row cannot orphan an idempotency claim.
            PlayerProfileRow locked = jdbc.lockPlayer(seat.playerId()).orElse(null);
            if (locked == null) {
                allClaimed = false;
                continue;
            }
            if (!jdbc.claimSettlement(matchId, seat.playerId())) {
                allClaimed = false;
                continue;
            }
            claimedCount++;
            int xpGain = xpForOutcome(seat.outcome());
            int newXp = locked.xp() + xpGain;
            int newLevel = levelForXp(newXp);
            jdbc.updateXpLevel(seat.playerId(), newXp, newLevel);
            jdbc.incrementGameStats(seat.playerId(), statsGame, normalizeOutcome(seat.outcome()));
        }

        if (casual && seats.size() == 2 && allClaimed && claimedCount == 2) {
            applyCasualElo(seats.get(0), seats.get(1));
        }
    }

    private void applyCasualElo(SeatSettlement a, SeatSettlement b) {
        // Ratings already claimed via settlement rows; still lock and update soft MMR.
        PlayerProfileRow rowA = jdbc.lockPlayer(a.playerId()).orElse(null);
        PlayerProfileRow rowB = jdbc.lockPlayer(b.playerId()).orElse(null);
        if (rowA == null || rowB == null) {
            return;
        }
        int nextA = SoftElo.nextRating(rowA.softRating(), rowB.softRating(), scoreForOutcome(a.outcome()));
        int nextB = SoftElo.nextRating(rowB.softRating(), rowA.softRating(), scoreForOutcome(b.outcome()));
        jdbc.updateRatings(a.playerId(), nextA, Math.max(rowA.bestRating(), nextA));
        jdbc.updateRatings(b.playerId(), nextB, Math.max(rowB.bestRating(), nextB));
    }

    static String guestSubtitle(UUID playerId) {
        String hex = playerId.toString().replace("-", "");
        return "Guest-" + hex.substring(hex.length() - 4);
    }

    /** Level 1 at 0 XP; cumulative threshold to enter level n+1 is 100*n*(n+1)/2. */
    static int levelForXp(int xp) {
        int level = 1;
        while (thresholdForLevel(level + 1) <= xp) {
            level++;
        }
        return level;
    }

    /** XP required to reach the given level (level 1 → 0). */
    static int thresholdForLevel(int level) {
        if (level <= 1) {
            return 0;
        }
        int n = level - 1;
        return 100 * n * (n + 1) / 2;
    }

    static int xpToNext(int xp, int level) {
        return Math.max(0, thresholdForLevel(level + 1) - xp);
    }

    static int xpForOutcome(String outcome) {
        return switch (normalizeOutcome(outcome)) {
            case "WIN" -> 12;
            case "DRAW" -> 6;
            default -> 4;
        };
    }

    static double scoreForOutcome(String outcome) {
        return switch (normalizeOutcome(outcome)) {
            case "WIN" -> 1.0;
            case "DRAW" -> 0.5;
            default -> 0.0;
        };
    }

    static String normalizeOutcome(String outcome) {
        if ("WIN".equals(outcome) || "DRAW".equals(outcome) || "LOSS".equals(outcome)) {
            return outcome;
        }
        return "LOSS";
    }

    private Map<String, GameStatsView> gamesMap(List<GameStatsRow> rows) {
        Map<String, GameStatsView> games = new LinkedHashMap<>();
        games.put(camelGame(GAME_ALCHIKI), emptyStats(true));
        games.put(camelGame(GAME_STICK_PULL), emptyStats(true));
        for (GameStatsRow row : rows) {
            boolean none = row.matches() == 0;
            games.put(
                    camelGame(row.game()),
                    new GameStatsView(row.matches(), row.wins(), row.losses(), row.draws(), none));
        }
        return Map.copyOf(games);
    }

    private static GameStatsView emptyStats(boolean noMatchesYet) {
        return new GameStatsView(0, 0, 0, 0, noMatchesYet);
    }

    private static String camelGame(String game) {
        if (GAME_STICK_PULL.equals(game)) {
            return "stickPull";
        }
        if (GAME_ALCHIKI.equals(game)) {
            return "alchiki";
        }
        return game.toLowerCase();
    }

    public record SeatSettlement(UUID playerId, String outcome) {}

    public record GameStatsView(int matches, int wins, int losses, int draws, boolean noMatchesYet) {}

    public record ProfileView(
            String displayName,
            String subtitle,
            String avatarPreset,
            int level,
            int xp,
            int xpToNext,
            int matches,
            int wins,
            int losses,
            double winRate,
            int rating,
            int bestRating,
            Map<String, String> cosmetics,
            Map<String, GameStatsView> games) {}
}
