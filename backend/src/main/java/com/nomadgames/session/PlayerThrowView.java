package com.nomadgames.session;

import java.util.List;

public record PlayerThrowView(
        int schemaVersion,
        boolean yUp,
        boolean settled,
        String settleReason,
        int simMs,
        int pocketedCount,
        boolean sakaOut,
        int displayedScore,
        List<String> pocketedIds,
        List<KeyframeView> keyframes) {}
