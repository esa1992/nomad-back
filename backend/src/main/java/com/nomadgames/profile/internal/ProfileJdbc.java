package com.nomadgames.profile.internal;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Component;

@Component
public class ProfileJdbc {

    private final JdbcClient jdbc;

    public ProfileJdbc(JdbcClient jdbc) {
        this.jdbc = jdbc;
    }

    public void ensureGameStatsRow(UUID playerId, String game) {
        jdbc.sql(
                        """
                        INSERT INTO player_game_stats (player_id, game, matches, wins, losses, draws)
                        VALUES (:playerId, :game, 0, 0, 0, 0)
                        ON CONFLICT (player_id, game) DO NOTHING
                        """)
                .param("playerId", playerId)
                .param("game", game)
                .update();
    }

    public Optional<PlayerProfileRow> findPlayer(UUID playerId) {
        return jdbc.sql(
                        """
                        SELECT avatar_preset, xp, level, soft_rating, best_rating
                        FROM players WHERE id = :playerId
                        """)
                .param("playerId", playerId)
                .query((rs, rowNum) -> new PlayerProfileRow(
                        rs.getString("avatar_preset"),
                        rs.getInt("xp"),
                        rs.getInt("level"),
                        rs.getInt("soft_rating"),
                        rs.getInt("best_rating")))
                .optional();
    }

    /** Lock profile columns for settle (FOR UPDATE). */
    public Optional<PlayerProfileRow> lockPlayer(UUID playerId) {
        return jdbc.sql(
                        """
                        SELECT avatar_preset, xp, level, soft_rating, best_rating
                        FROM players WHERE id = :playerId
                        FOR UPDATE
                        """)
                .param("playerId", playerId)
                .query((rs, rowNum) -> new PlayerProfileRow(
                        rs.getString("avatar_preset"),
                        rs.getInt("xp"),
                        rs.getInt("level"),
                        rs.getInt("soft_rating"),
                        rs.getInt("best_rating")))
                .optional();
    }

    public List<GameStatsRow> listGameStats(UUID playerId) {
        return jdbc.sql(
                        """
                        SELECT game, matches, wins, losses, draws
                        FROM player_game_stats
                        WHERE player_id = :playerId
                        """)
                .param("playerId", playerId)
                .query((rs, rowNum) -> new GameStatsRow(
                        rs.getString("game"),
                        rs.getInt("matches"),
                        rs.getInt("wins"),
                        rs.getInt("losses"),
                        rs.getInt("draws")))
                .list();
    }

    /** Returns true if this is the first settle for (match, player). */
    public boolean claimSettlement(UUID matchId, UUID playerId) {
        int inserted = jdbc.sql(
                        """
                        INSERT INTO profile_settlements (match_id, player_id)
                        VALUES (:matchId, :playerId)
                        ON CONFLICT (match_id, player_id) DO NOTHING
                        """)
                .param("matchId", matchId)
                .param("playerId", playerId)
                .update();
        return inserted > 0;
    }

    public void updateXpLevel(UUID playerId, int xp, int level) {
        jdbc.sql(
                        """
                        UPDATE players SET xp = :xp, level = :level
                        WHERE id = :playerId
                        """)
                .param("xp", xp)
                .param("level", level)
                .param("playerId", playerId)
                .update();
    }

    public void updateRatings(UUID playerId, int softRating, int bestRating) {
        jdbc.sql(
                        """
                        UPDATE players SET soft_rating = :softRating, best_rating = :bestRating
                        WHERE id = :playerId
                        """)
                .param("softRating", softRating)
                .param("bestRating", bestRating)
                .param("playerId", playerId)
                .update();
    }

    public void setAvatarPreset(UUID playerId, String avatarPreset) {
        jdbc.sql(
                        """
                        UPDATE players SET avatar_preset = :avatar
                        WHERE id = :playerId
                        """)
                .param("avatar", avatarPreset)
                .param("playerId", playerId)
                .update();
    }

    public void incrementGameStats(UUID playerId, String game, String outcome) {
        int winInc = "WIN".equals(outcome) ? 1 : 0;
        int lossInc = "LOSS".equals(outcome) ? 1 : 0;
        int drawInc = "DRAW".equals(outcome) ? 1 : 0;
        jdbc.sql(
                        """
                        UPDATE player_game_stats
                        SET matches = matches + 1,
                            wins = wins + :winInc,
                            losses = losses + :lossInc,
                            draws = draws + :drawInc
                        WHERE player_id = :playerId AND game = :game
                        """)
                .param("winInc", winInc)
                .param("lossInc", lossInc)
                .param("drawInc", drawInc)
                .param("playerId", playerId)
                .param("game", game)
                .update();
    }

    public record PlayerProfileRow(String avatarPreset, int xp, int level, int softRating, int bestRating) {}

    public record GameStatsRow(String game, int matches, int wins, int losses, int draws) {}
}
