package com.nomadgames.identity;

public record TokenPair(String accessToken, String refreshToken, boolean guest) {}
