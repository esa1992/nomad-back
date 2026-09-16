package com.nomadgames.rating.internal;

import java.io.Serializable;
import java.util.Objects;
import java.util.UUID;

public class GlickoRatingId implements Serializable {

    private UUID playerId;
    private String game;
    private String seasonKey;

    public GlickoRatingId() {}

    public GlickoRatingId(UUID playerId, String game, String seasonKey) {
        this.playerId = playerId;
        this.game = game;
        this.seasonKey = seasonKey;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) {
            return true;
        }
        if (!(o instanceof GlickoRatingId that)) {
            return false;
        }
        return Objects.equals(playerId, that.playerId)
                && Objects.equals(game, that.game)
                && Objects.equals(seasonKey, that.seasonKey);
    }

    @Override
    public int hashCode() {
        return Objects.hash(playerId, game, seasonKey);
    }
}
