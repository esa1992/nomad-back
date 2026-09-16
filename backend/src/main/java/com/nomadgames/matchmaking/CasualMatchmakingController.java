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

import jakarta.servlet.http.HttpServletRequest;

@RestController
@RequestMapping("/v1/matchmaking/casual")
public class CasualMatchmakingController {

    private final CasualQueueService queue;

    public CasualMatchmakingController(CasualQueueService queue) {
        this.queue = queue;
    }

    @PostMapping
    public CasualQueueResponse enqueue(
            @AuthenticationPrincipal Jwt jwt,
            @RequestBody(required = false) EnqueueCasualRequest body,
            HttpServletRequest request) {
        String game = body == null ? null : body.game();
        return queue.enqueue(playerId(jwt), clientIp(request), game);
    }

    @GetMapping
    public CasualQueueResponse status(@AuthenticationPrincipal Jwt jwt) {
        return queue.status(playerId(jwt));
    }

    @DeleteMapping
    public CasualQueueResponse dequeue(@AuthenticationPrincipal Jwt jwt) {
        return queue.dequeue(playerId(jwt));
    }

    @ExceptionHandler(IllegalArgumentException.class)
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    public void badRequest() {}

    private static UUID playerId(Jwt jwt) {
        return UUID.fromString(jwt.getSubject());
    }

    private static String clientIp(HttpServletRequest request) {
        // Do not trust client-supplied X-Forwarded-For; use the peer address.
        // Behind a known proxy, enable Spring forward-headers / trusted proxies instead.
        return request.getRemoteAddr();
    }
}
