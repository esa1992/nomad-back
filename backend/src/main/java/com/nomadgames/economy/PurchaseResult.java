package com.nomadgames.economy;

/** Soft purchase outcome: refreshed wallet + owned flag (ECON-02 / ECON-05). */
public record PurchaseResult(String skuId, boolean owned, int coins, int gems) {}
