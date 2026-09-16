package com.nomadgames.session;

import java.util.List;

public record RejoinSnapshot(
        String type,
        MatchSnapshot match,
        PlayerThrowView playerThrow,
        List<BodyPoseView> sakaPoses,
        String reconnectToken) {}
