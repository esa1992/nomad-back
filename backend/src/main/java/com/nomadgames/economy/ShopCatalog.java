package com.nomadgames.economy;

import java.util.List;

/** Flat shop catalog projection (client groups by slot). */
public record ShopCatalog(List<ShopSkuView> skus) {

    public record ShopSkuView(
            String id,
            String slot,
            String nameKey,
            int priceCoins,
            int priceGems,
            boolean owned,
            boolean equipped,
            boolean free) {}
}
