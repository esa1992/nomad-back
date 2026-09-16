package com.nomadgames.economy;

/** Equip intent. Slot/skuId validated server-side against inventory (D-55, T-04-18). */
public record EquipRequest(String slot, String skuId) {}
