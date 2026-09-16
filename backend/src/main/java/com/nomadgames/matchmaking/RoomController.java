package com.nomadgames.matchmaking;

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

import jakarta.servlet.http.HttpServletRequest;

@RestController
@RequestMapping("/v1/rooms")
public class RoomController {

    private final RoomService rooms;

    public RoomController(RoomService rooms) {
        this.rooms = rooms;
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public RoomCreatedResponse create(
            @AuthenticationPrincipal Jwt jwt, @RequestBody(required = false) CreateRoomRequest body) {
        String game = body == null ? null : body.game();
        return rooms.create(playerId(jwt), game);
    }

    /** POST /v1/rooms/join */
    @PostMapping("/join")
    public RoomLobbyResponse join(
            @AuthenticationPrincipal Jwt jwt,
            @RequestBody(required = false) JoinRoomRequest body,
            HttpServletRequest request) {
        String code = body == null ? null : body.code();
        return rooms.join(playerId(jwt), code, clientIp(request));
    }

    @GetMapping("/{id}")
    public RoomLobbyResponse get(@AuthenticationPrincipal Jwt jwt, @PathVariable("id") UUID roomId) {
        return rooms.get(playerId(jwt), roomId);
    }

    @PostMapping("/{id}/ready")
    public RoomLobbyResponse ready(@AuthenticationPrincipal Jwt jwt, @PathVariable("id") UUID roomId) {
        return rooms.ready(playerId(jwt), roomId);
    }

    @PostMapping("/{id}/leave")
    public RoomLobbyResponse leave(@AuthenticationPrincipal Jwt jwt, @PathVariable("id") UUID roomId) {
        return rooms.leave(playerId(jwt), roomId);
    }

    @ExceptionHandler(IllegalArgumentException.class)
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    public void badRequest() {}

    private static UUID playerId(Jwt jwt) {
        return UUID.fromString(jwt.getSubject());
    }

    private static String clientIp(HttpServletRequest request) {
        String forwarded = request.getHeader("X-Forwarded-For");
        if (forwarded != null && !forwarded.isBlank()) {
            return forwarded.split(",")[0].trim();
        }
        return request.getRemoteAddr();
    }
}
