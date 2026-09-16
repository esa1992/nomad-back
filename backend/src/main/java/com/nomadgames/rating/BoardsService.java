package com.nomadgames.rating;

import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import java.util.UUID;

import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

/**
 * Bound-only skill boards Top-100 (LEAD-01…03 / D-105, D-106). Never orders by coins/gems.
 */
@Service
public class BoardsService {

    static final int TOP_N = 100;
    private static final Set<String> GAMES = Set.of("ALCHIKI", "STICK_PULL");
    private static final Set<String> SCOPES = Set.of("season", "all_time");

    private final JdbcClient jdbc;
    private final SeasonService seasons;

    public BoardsService(JdbcClient jdbc, SeasonService seasons) {
        this.jdbc = jdbc;
        this.seasons = seasons;
    }

    @Transactional
    public BoardsResponse list(String game, String scope) {
        String g = normalizeGame(game);
        String s = normalizeScope(scope);
        seasons.ensureCurrentSeason(g);
        List<BoardRow> rows = "season".equals(s) ? seasonRows(g) : allTimeRows(g);
        List<BoardEntry> entries = new ArrayList<>(rows.size());
        for (int i = 0; i < rows.size(); i++) {
            BoardRow row = rows.get(i);
            entries.add(new BoardEntry(
                    i + 1,
                    row.playerId(),
                    row.username(),
                    Math.round(row.rating()),
                    false));
        }
        return new BoardsResponse(g, s, entries);
    }

    private List<BoardRow> seasonRows(String game) {
        String seasonKey = seasons.currentSeasonKey();
        return jdbc.sql(
                        """
                        SELECT gr.player_id, c.username, gr.rating AS rating
                        FROM glicko_ratings gr
                        INNER JOIN players p ON p.id = gr.player_id AND p.guest = false
                        INNER JOIN credentials c ON c.player_id = gr.player_id AND c.username IS NOT NULL
                        WHERE gr.game = :game AND gr.season_key = :seasonKey
                        ORDER BY gr.rating DESC, gr.player_id ASC
                        LIMIT :limit
                        """)
                .param("game", game)
                .param("seasonKey", seasonKey)
                .param("limit", TOP_N)
                .query((rs, rowNum) -> new BoardRow(
                        (UUID) rs.getObject("player_id"),
                        rs.getString("username"),
                        rs.getDouble("rating")))
                .list();
    }

    private List<BoardRow> allTimeRows(String game) {
        return jdbc.sql(
                        """
                        SELECT player_id, username, rating FROM (
                          SELECT DISTINCT ON (gr.player_id)
                            gr.player_id,
                            c.username,
                            gr.all_time_peak AS rating
                          FROM glicko_ratings gr
                          INNER JOIN players p ON p.id = gr.player_id AND p.guest = false
                          INNER JOIN credentials c ON c.player_id = gr.player_id AND c.username IS NOT NULL
                          WHERE gr.game = :game
                          ORDER BY gr.player_id, gr.all_time_peak DESC
                        ) ranked
                        ORDER BY rating DESC, player_id ASC
                        LIMIT :limit
                        """)
                .param("game", game)
                .param("limit", TOP_N)
                .query((rs, rowNum) -> new BoardRow(
                        (UUID) rs.getObject("player_id"),
                        rs.getString("username"),
                        rs.getDouble("rating")))
                .list();
    }

    private static String normalizeGame(String game) {
        if (game == null || !GAMES.contains(game)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "invalid game");
        }
        return game;
    }

    private static String normalizeScope(String scope) {
        if (scope == null || !SCOPES.contains(scope)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "invalid scope");
        }
        return scope;
    }

    private record BoardRow(UUID playerId, String username, double rating) {}

    public record BoardsResponse(String game, String scope, List<BoardEntry> entries) {}

    public record BoardEntry(int rank, UUID playerId, String username, long rating, boolean guest) {}
}
