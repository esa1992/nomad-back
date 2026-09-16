package com.nomadgames.session;

import java.util.List;

public record BotThrowView(
        ThrowInputView input,
        int displayedScore,
        boolean sakaOut,
        int pocketedCount,
        List<String> pocketedIds,
        List<KeyframeView> keyframes) {}
