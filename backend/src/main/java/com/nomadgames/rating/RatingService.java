package com.nomadgames.rating;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.nomadgames.profile.ProfileService.SeatSettlement;
import com.nomadgames.rating.internal.Glicko2;
import com.nomadgames.rating.internal.Glicko2.Rating;
import com.nomadgames.rating.internal.GlickoRatingEntity;
import com.nomadgames.rating.internal.GlickoRatingRepository;
import com.nomadgames.rating.internal.GlickoSettlementEntity;
import com.nomadgames.rating.internal.GlickoSettlementRepository;

/**
 * Ranked-only Glicko settle (D-104). SoftElo stays in ProfileService for CASUAL.
 * Cosmetics are never consulted. all_time_peak updates on higher settle (D-105).
 */
@Service
public class RatingService {

    private final GlickoRatingRepository ratings;
    private final GlickoSettlementRepository settlements;
    private final SeasonService seasons;

    public RatingService(
            GlickoRatingRepository ratings,
            GlickoSettlementRepository settlements,
            SeasonService seasons) {
        this.ratings = ratings;
        this.settlements = settlements;
        this.seasons = seasons;
    }

    /**
     * Idempotent Glicko update for a Ranked match. Expects exactly two seats with WIN/LOSS/DRAW.
     */
    @Transactional
    public void recordRankedSettlement(UUID matchId, String game, List<SeatSettlement> seats) {
        if (matchId == null || seats == null || seats.size() != 2) {
            return;
        }
        SeatSettlement a = seats.get(0);
        SeatSettlement b = seats.get(1);
        if (a == null || b == null || a.playerId() == null || b.playerId() == null) {
            return;
        }
        if (settlements.existsByMatchIdAndPlayerId(matchId, a.playerId())
                || settlements.existsByMatchIdAndPlayerId(matchId, b.playerId())) {
            return;
        }
        settlements.save(new GlickoSettlementEntity(matchId, a.playerId()));
        settlements.save(new GlickoSettlementEntity(matchId, b.playerId()));

        String statsGame = game == null || game.isBlank() ? "ALCHIKI" : game;
        String seasonKey = seasons.currentSeasonKey();
        GlickoRatingEntity rowA = seasons.loadOrCreateSeasonRow(a.playerId(), statsGame, seasonKey);
        GlickoRatingEntity rowB = seasons.loadOrCreateSeasonRow(b.playerId(), statsGame, seasonKey);

        Rating beforeA = new Rating(rowA.getRating(), rowA.getRd(), rowA.getSigma());
        Rating beforeB = new Rating(rowB.getRating(), rowB.getRd(), rowB.getSigma());
        Rating afterA = Glicko2.update(beforeA, beforeB, scoreForOutcome(a.outcome()));
        Rating afterB = Glicko2.update(beforeB, beforeA, scoreForOutcome(b.outcome()));

        Rating beforeAllA = new Rating(rowA.getAllTimeRating(), rowA.getAllTimeRd(), rowA.getAllTimeSigma());
        Rating beforeAllB = new Rating(rowB.getAllTimeRating(), rowB.getAllTimeRd(), rowB.getAllTimeSigma());
        Rating afterAllA = Glicko2.update(beforeAllA, beforeAllB, scoreForOutcome(a.outcome()));
        Rating afterAllB = Glicko2.update(beforeAllB, beforeAllA, scoreForOutcome(b.outcome()));

        applyUpdate(rowA, afterA, afterAllA);
        applyUpdate(rowB, afterB, afterAllB);
        ratings.save(rowA);
        ratings.save(rowB);
    }

    private static void applyUpdate(GlickoRatingEntity row, Rating seasonNext, Rating allTimeNext) {
        row.setRating(seasonNext.r());
        row.setRd(seasonNext.rd());
        row.setSigma(seasonNext.sigma());
        row.setMatches(row.getMatches() + 1);
        row.setAllTimeRating(allTimeNext.r());
        row.setAllTimeRd(allTimeNext.rd());
        row.setAllTimeSigma(allTimeNext.sigma());
        row.setAllTimePeak(Math.max(row.getAllTimePeak(), allTimeNext.r()));
        row.setAllTimeMatches(row.getAllTimeMatches() + 1);
        row.setUpdatedAt(Instant.now());
    }

    /** @deprecated prefer {@link SeasonService#currentSeasonKey()} — kept for call-site clarity in tests. */
    static String currentSeasonKey(Instant now) {
        return SeasonService.currentSeasonKey(now);
    }

    static double scoreForOutcome(String outcome) {
        if ("WIN".equals(outcome)) {
            return 1.0;
        }
        if ("DRAW".equals(outcome)) {
            return 0.5;
        }
        return 0.0;
    }
}
