package com.nomadgames.session;

import java.util.List;

public record ScoredThrow(PlayerThrowView playerThrow, int displayedScore, List<String> pocketedIds) {}
