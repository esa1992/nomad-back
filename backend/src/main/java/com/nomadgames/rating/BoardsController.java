package com.nomadgames.rating;

import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

/**
 * GET /v1/boards — bound-only skill boards (LEAD-01…03 / T-07-21).
 */
@RestController
public class BoardsController {

    private final BoardsService boards;

    public BoardsController(BoardsService boards) {
        this.boards = boards;
    }

    @GetMapping("/v1/boards")
    public BoardsService.BoardsResponse boards(
            @AuthenticationPrincipal Jwt jwt,
            @RequestParam String game,
            @RequestParam String scope) {
        requireBound(jwt);
        return boards.list(game, scope);
    }

    /** Guests cannot read boards (D-96 / T-07-21). */
    private static void requireBound(Jwt jwt) {
        Boolean guest = jwt.getClaim("guest");
        if (guest == null || guest) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "bound required");
        }
    }
}
