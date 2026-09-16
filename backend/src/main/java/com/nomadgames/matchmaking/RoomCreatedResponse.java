package com.nomadgames.matchmaking;

import java.time.Instant;
import java.util.UUID;

public record RoomCreatedResponse(UUID roomId, String code, String hostLabel, Instant idleExpiresAt) {}
