package com.nomadgames.matchmaking;

import java.util.UUID;

import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

import jakarta.servlet.http.HttpServletRequest;

@RestController
@RequestMapping("/v1/matchmaking/ranked")
public class RankedMatchmakingController {

    private final RankedQueueService queue;

    public RankedMatchmakingController(RankedQueueService queue) {
        this.queue = queue;
    }

    @PostMapping
    public CasualQueueResponse enqueue(
            @AuthenticationPrincipal Jwt jwt,
            @RequestBody(required = false) EnqueueCasualRequest body,
            HttpServletRequest request) {
        requireBound(jwt);
        String game = body == null ? null : body.game();
        return queue.enqueue(playerId(jwt), clientIp(request), game);
    }

    @GetMapping
    public CasualQueueResponse status(@AuthenticationPrincipal Jwt jwt) {
        requireBound(jwt);
        return queue.status(playerId(jwt));
    }

    @DeleteMapping
    public CasualQueueResponse dequeue(@AuthenticationPrincipal Jwt jwt) {
        requireBound(jwt);
        return queue.dequeue(playerId(jwt));
    }

    @ExceptionHandler(IllegalArgumentException.class)
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    public void badRequest() {}

    /** D-97 / T-07-12: guests cannot enqueue Ranked. */
    private static void requireBound(Jwt jwt) {
        Boolean guest = jwt.getClaim("guest");
        if (guest == null || guest) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "bound required");
        }
    }

    private static UUID playerId(Jwt jwt) {
        return UUID.fromString(jwt.getSubject());
    }

    private static String clientIp(HttpServletRequest request) {
        return request.getRemoteAddr();
    }
}
