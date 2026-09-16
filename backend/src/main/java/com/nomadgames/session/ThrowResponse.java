package com.nomadgames.session;

public record ThrowResponse(PlayerThrowView playerThrow, BotThrowView botThrow, MatchSnapshot match) {}
