package com.nomadgames.profile;

import java.util.UUID;

import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

@RestController
public class ProfileController {

    private final ProfileService profile;

    public ProfileController(ProfileService profile) {
        this.profile = profile;
    }

    @GetMapping("/v1/profile")
    public ProfileService.ProfileView get(@AuthenticationPrincipal Jwt jwt) {
        return profile.getProfile(playerId(jwt));
    }

    @PutMapping("/v1/profile/avatar")
    public ProfileService.ProfileView putAvatar(
            @AuthenticationPrincipal Jwt jwt, @RequestBody AvatarRequest body) {
        if (body == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "body required");
        }
        return profile.setAvatar(playerId(jwt), body.avatarPreset());
    }

    private static UUID playerId(Jwt jwt) {
        return UUID.fromString(jwt.getSubject());
    }

    public record AvatarRequest(String avatarPreset) {}
}
