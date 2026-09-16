package com.nomadgames.session;

import java.util.List;

public record PrivateTable(List<String> boneIds, String hostSakaId, String joinerSakaId) {}
