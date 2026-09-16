package com.nomadgames.session;

public record ThrowInputView(
        int schemaVersion,
        boolean yUp,
        double aimAngleRad,
        int holdMs,
        int seed,
        String tableId) {}
