package com.nomadgames.rating;

import java.time.Instant;
import java.time.ZoneOffset;
import java.time.ZonedDateTime;
import java.util.List;
import java.util.UUID;

import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.nomadgames.rating.internal.GlickoRatingEntity;
import com.nomadgames.rating.internal.GlickoRatingRepository;

/**
 * Quarterly soft season keys + ensure-on-read reset (D-105).
 * Formula: r' = round(1500 + 0.5*(r-1500)); RD' = min(350, RD + 0.5*(350-RD)); σ unchanged.
 */
@Service
public class SeasonService {

    private final GlickoRatingRepository ratings;
    private final JdbcClient jdbc;

    public SeasonService(GlickoRatingRepository ratings, JdbcClient jdbc) {
        this.ratings = ratings;
        this.jdbc = jdbc;
    }

    public String currentSeasonKey() {
        return currentSeasonKey(Instant.now());
    }

    public static String currentSeasonKey(Instant now) {
        ZonedDateTime z = now.atZone(ZoneOffset.UTC);
        int quarter = (z.getMonthValue() - 1) / 3 + 1;
        return z.getYear() + "-Q" + quarter;
    }

    /**
     * Ensure every player+game with prior-season rows has a soft-reset row for the current quarter.
     */
    @Transactional
    public void ensureCurrentSeason(String game) {
        String seasonKey = currentSeasonKey();
        String statsGame = game == null || game.isBlank() ? "ALCHIKI" : game;
        List<UUID> stale = jdbc.sql(
                        """
                        SELECT DISTINCT gr.player_id
                        FROM glicko_ratings gr
                        WHERE gr.game = :game
                          AND NOT EXISTS (
                            SELECT 1 FROM glicko_ratings cur
                            WHERE cur.player_id = gr.player_id
                              AND cur.game = gr.game
                              AND cur.season_key = :seasonKey
                          )
                        """)
                .param("game", statsGame)
                .param("seasonKey", seasonKey)
                .query((rs, rowNum) -> (UUID) rs.getObject("player_id"))
                .list();
        for (UUID playerId : stale) {
            ensurePlayerSeason(playerId, statsGame, seasonKey);
        }
    }

    /**
     * Load current-season row or soft-reset from the latest prior season (defaults if none).
     */
    @Transactional
    public GlickoRatingEntity loadOrCreateSeasonRow(UUID playerId, String game, String seasonKey) {
        return ratings.findByPlayerIdAndGameAndSeasonKey(playerId, game, seasonKey)
                .orElseGet(() -> ensurePlayerSeason(playerId, game, seasonKey));
    }

    private GlickoRatingEntity ensurePlayerSeason(UUID playerId, String game, String seasonKey) {
        return ratings.findByPlayerIdAndGameAndSeasonKey(playerId, game, seasonKey)
                .orElseGet(() -> {
                    GlickoRatingEntity created = softResetFromPrior(playerId, game, seasonKey);
                    return ratings.save(created);
                });
    }

    private GlickoRatingEntity softResetFromPrior(UUID playerId, String game, String seasonKey) {
        GlickoRatingEntity prior = jdbc.sql(
                        """
                        SELECT player_id, game, season_key, rating, rd, sigma, matches,
                               all_time_rating, all_time_rd, all_time_sigma,
                               all_time_peak, all_time_matches, updated_at
                        FROM glicko_ratings
                        WHERE player_id = :playerId AND game = :game AND season_key <> :seasonKey
                        ORDER BY updated_at DESC
                        LIMIT 1
                        """)
                .param("playerId", playerId)
                .param("game", game)
                .param("seasonKey", seasonKey)
                .query((rs, rowNum) -> {
                    GlickoRatingEntity row = new GlickoRatingEntity(
                            (UUID) rs.getObject("player_id"),
                            rs.getString("game"),
                            rs.getString("season_key"));
                    row.setRating(rs.getDouble("rating"));
                    row.setRd(rs.getDouble("rd"));
                    row.setSigma(rs.getDouble("sigma"));
                    row.setMatches(rs.getInt("matches"));
                    row.setAllTimeRating(rs.getDouble("all_time_rating"));
                    row.setAllTimeRd(rs.getDouble("all_time_rd"));
                    row.setAllTimeSigma(rs.getDouble("all_time_sigma"));
                    row.setAllTimePeak(rs.getDouble("all_time_peak"));
                    row.setAllTimeMatches(rs.getInt("all_time_matches"));
                    row.setUpdatedAt(rs.getTimestamp("updated_at").toInstant());
                    return row;
                })
                .optional()
                .orElse(null);

        GlickoRatingEntity next = new GlickoRatingEntity(playerId, game, seasonKey);
        if (prior == null) {
            return next;
        }
        next.setRating(softResetRating(prior.getRating()));
        next.setRd(softResetRd(prior.getRd()));
        next.setSigma(prior.getSigma());
        next.setMatches(0);
        next.setAllTimeRating(prior.getAllTimeRating());
        next.setAllTimeRd(prior.getAllTimeRd());
        next.setAllTimeSigma(prior.getAllTimeSigma());
        next.setAllTimePeak(prior.getAllTimePeak());
        next.setAllTimeMatches(prior.getAllTimeMatches());
        next.setUpdatedAt(Instant.now());
        return next;
    }

    static double softResetRating(double rating) {
        return Math.round(1500.0 + 0.5 * (rating - 1500.0));
    }

    static double softResetRd(double rd) {
        return Math.min(350.0, rd + 0.5 * (350.0 - rd));
    }
}
