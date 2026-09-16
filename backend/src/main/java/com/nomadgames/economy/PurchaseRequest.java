package com.nomadgames.economy;

/** Soft-currency buy body. Extra client fields (coins/balance/coinsDelta) are ignored (ECON-04). */
public record PurchaseRequest(String skuId, String idempotencyKey) {}
