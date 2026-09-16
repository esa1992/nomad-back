package com.nomadgames.rating.internal;

import java.time.Instant;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.IdClass;
import jakarta.persistence.Table;

@Entity
@Table(name = "glicko_ratings")
@IdClass(GlickoRatingId.class)
public class GlickoRatingEntity {

    @Id
    @Column(name = "player_id", nullable = false)
    private UUID playerId;

    @Id
    @Column(nullable = false)
    private String game;

    @Id
    @Column(name = "season_key", nullable = false)
    private String seasonKey;

    @Column(nullable = false)
    private double rating = 1500;

    @Column(nullable = false)
    private double rd = 350;

    @Column(nullable = false)
    private double sigma = 0.06;

    @Column(nullable = false)
    private int matches;

    @Column(name = "all_time_rating", nullable = false)
    private double allTimeRating = 1500;

    @Column(name = "all_time_rd", nullable = false)
    private double allTimeRd = 350;

    @Column(name = "all_time_sigma", nullable = false)
    private double allTimeSigma = 0.06;

    @Column(name = "all_time_peak", nullable = false)
    private double allTimePeak = 1500;

    @Column(name = "all_time_matches", nullable = false)
    private int allTimeMatches;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt = Instant.now();

    protected GlickoRatingEntity() {}

    public GlickoRatingEntity(UUID playerId, String game, String seasonKey) {
        this.playerId = playerId;
        this.game = game;
        this.seasonKey = seasonKey;
        this.updatedAt = Instant.now();
    }

    public UUID getPlayerId() {
        return playerId;
    }

    public String getGame() {
        return game;
    }

    public String getSeasonKey() {
        return seasonKey;
    }

    public double getRating() {
        return rating;
    }

    public void setRating(double rating) {
        this.rating = rating;
    }

    public double getRd() {
        return rd;
    }

    public void setRd(double rd) {
        this.rd = rd;
    }

    public double getSigma() {
        return sigma;
    }

    public void setSigma(double sigma) {
        this.sigma = sigma;
    }

    public int getMatches() {
        return matches;
    }

    public void setMatches(int matches) {
        this.matches = matches;
    }

    public double getAllTimeRating() {
        return allTimeRating;
    }

    public void setAllTimeRating(double allTimeRating) {
        this.allTimeRating = allTimeRating;
    }

    public double getAllTimeRd() {
        return allTimeRd;
    }

    public void setAllTimeRd(double allTimeRd) {
        this.allTimeRd = allTimeRd;
    }

    public double getAllTimeSigma() {
        return allTimeSigma;
    }

    public void setAllTimeSigma(double allTimeSigma) {
        this.allTimeSigma = allTimeSigma;
    }

    public double getAllTimePeak() {
        return allTimePeak;
    }

    public void setAllTimePeak(double allTimePeak) {
        this.allTimePeak = allTimePeak;
    }

    public int getAllTimeMatches() {
        return allTimeMatches;
    }

    public void setAllTimeMatches(int allTimeMatches) {
        this.allTimeMatches = allTimeMatches;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }

    public void setUpdatedAt(Instant updatedAt) {
        this.updatedAt = updatedAt;
    }
}
