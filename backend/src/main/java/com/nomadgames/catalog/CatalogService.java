package com.nomadgames.catalog;

import java.util.List;

import org.springframework.stereotype.Service;

@Service
public class CatalogService {

    public CatalogResponse list() {
        return new CatalogResponse(List.of(
                new CatalogTileView("alchiki", CatalogTileStatus.PLAYABLE),
                new CatalogTileView("stick_pull", CatalogTileStatus.PLAYABLE),
                new CatalogTileView("more_games", CatalogTileStatus.COMING_SOON)));
    }
}

enum CatalogTileStatus {
    PLAYABLE,
    COMING_SOON
}

record CatalogTileView(String id, CatalogTileStatus status) {
}

record CatalogResponse(List<CatalogTileView> tiles) {
}
