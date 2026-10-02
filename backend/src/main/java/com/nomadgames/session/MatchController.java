package com.nomadgames.session;

import java.util.UUID;

import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/v1/matches")
public class MatchController {

    private final MatchService matches;

    public MatchController(MatchService matches) {
        this.matches = matches;
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public MatchCreatedResponse create(@AuthenticationPrincipal Jwt jwt, @RequestBody CreateMatchRequest request) {
        return matches.createMatch(playerId(jwt), request);
    }

    @GetMapping("/{id}")
    public MatchSnapshot get(@AuthenticationPrincipal Jwt jwt, @PathVariable("id") UUID matchId) {
        return matches.getMatch(playerId(jwt), matchId);
    }

    @PostMapping("/{id}/throws")
    public ThrowResponse applyThrow(
            @AuthenticationPrincipal Jwt jwt, @PathVariable("id") UUID matchId, @RequestBody(required = false) String body) {
        return matches.applyThrow(playerId(jwt), matchId, body);
    }

    @PostMapping("/{id}/bot-turn")
    public ThrowResponse continueBot(@AuthenticationPrincipal Jwt jwt, @PathVariable("id") UUID matchId) {
        return matches.continueBot(playerId(jwt), matchId);
    }

    @PostMapping("/{id}/leave")
    public LeaveResponse leave(@AuthenticationPrincipal Jwt jwt, @PathVariable("id") UUID matchId) {
        return matches.leaveMatch(playerId(jwt), matchId);
    }

    @PostMapping("/{id}/ws-ticket")
    public WsTicketResponse wsTicket(@AuthenticationPrincipal Jwt jwt, @PathVariable("id") UUID matchId) {
        return matches.issueWsTicket(playerId(jwt), matchId);
    }

    @PostMapping("/{id}/rematch")
    public RematchAcceptResponse rematch(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable("id") UUID matchId,
            @RequestBody(required = false) RematchRequest body) {
        boolean accept = body == null || body.accept() == null || Boolean.TRUE.equals(body.accept());
        return matches.acceptRematch(playerId(jwt), matchId, accept);
    }

    @GetMapping("/{id}/rematch")
    public RematchPollResponse getRematch(@AuthenticationPrincipal Jwt jwt, @PathVariable("id") UUID matchId) {
        return matches.getRematch(playerId(jwt), matchId);
    }

    @PostMapping("/{id}/rejoin")
    public RejoinSnapshot rejoin(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable("id") UUID matchId,
            @RequestBody(required = false) RejoinRequest body) {
        String token = body == null ? null : body.token();
        return matches.rejoin(playerId(jwt), matchId, token);
    }

    @ExceptionHandler(IllegalArgumentException.class)
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    public void badRequest() {}

    private static UUID playerId(Jwt jwt) {
        return UUID.fromString(jwt.getSubject());
    }
}
