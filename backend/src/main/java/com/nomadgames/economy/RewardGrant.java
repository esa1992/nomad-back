package com.nomadgames.economy;

/** Coins/gems granted for one seat on one match (overlay + ledger). */
public record RewardGrant(int coins, int gems) {
    public static final RewardGrant NONE = new RewardGrant(0, 0);
}
