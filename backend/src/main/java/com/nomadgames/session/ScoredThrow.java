package com.nomadgames.session;

import java.util.List;

public record ScoredThrow(
        PlayerThrowView playerThrow, int displayedScore, boolean sakaOut, List<String> pocketedIds) {}
