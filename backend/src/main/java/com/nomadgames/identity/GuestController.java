package com.nomadgames.identity;

import java.util.UUID;

import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

import com.nomadgames.identity.internal.GuestMintRateLimiter;
import com.nomadgames.identity.internal.LoginRateLimiter;

import jakarta.servlet.http.HttpServletRequest;

@RestController
public class GuestController {

    private final GuestService guests;
    private final BindService bindService;
    private final AuthService authService;
    private final TokenService tokens;
    private final GuestMintRateLimiter rateLimiter;
    private final LoginRateLimiter loginRateLimiter;

    public GuestController(
            GuestService guests,
            BindService bindService,
            AuthService authService,
            TokenService tokens,
            GuestMintRateLimiter rateLimiter,
            LoginRateLimiter loginRateLimiter) {
        this.guests = guests;
        this.bindService = bindService;
        this.authService = authService;
        this.tokens = tokens;
        this.rateLimiter = rateLimiter;
        this.loginRateLimiter = loginRateLimiter;
    }

    @PostMapping("/v1/identity/guest")
    @ResponseStatus(HttpStatus.CREATED)
    public GuestSessionResponse createGuest(HttpServletRequest request) {
        rateLimiter.check(clientIp(request));
        return guests.createGuest();
    }

    @PostMapping("/v1/identity/refresh")
    public TokenPair refresh(@RequestBody RefreshRequest body) {
        return tokens.rotate(body == null ? null : body.refreshToken());
    }

    /** AUTH-02: bind requires authenticated guest JWT (not permitAll). */
    @PostMapping("/v1/identity/bind")
    public GuestSessionResponse bind(@AuthenticationPrincipal Jwt jwt, @RequestBody BindRequest body) {
        if (body == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "body required");
        }
        return bindService.bind(playerId(jwt), body.username(), body.password());
    }

    /** AUTH-03: username/password login is permitAll (rate-limited). Adopt requires guest possession. */
    @PostMapping("/v1/identity/login")
    public GuestSessionResponse login(@RequestBody LoginRequest body, HttpServletRequest request) {
        loginRateLimiter.check(clientIp(request));
        if (body == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "body required");
        }
        return authService.login(
                body.username(),
                body.password(),
                body.guestPlayerId(),
                body.adopt(),
                bearerToken(request),
                body.guestRefreshToken());
    }

    /** AUTH-04: revoke refresh for caller; return freshly minted guest session. */
    @PostMapping("/v1/identity/logout")
    public GuestSessionResponse logout(@AuthenticationPrincipal Jwt jwt) {
        return authService.logout(playerId(jwt));
    }

    private static UUID playerId(Jwt jwt) {
        return UUID.fromString(jwt.getSubject());
    }

    private static String bearerToken(HttpServletRequest request) {
        String header = request.getHeader("Authorization");
        if (header == null || header.isBlank()) {
            return null;
        }
        if (header.regionMatches(true, 0, "Bearer ", 0, 7)) {
            String token = header.substring(7).trim();
            return token.isEmpty() ? null : token;
        }
        return null;
    }

    private static String clientIp(HttpServletRequest request) {
        // ASVS L1: do not trust client-supplied X-Forwarded-For unless a trusted proxy is configured
        // (server.forward-headers-strategy). Use the socket remote address for login rate limiting.
        return request.getRemoteAddr();
    }
}
