package com.nomadgames.economy.internal;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Component;

@Component
public class WalletLedgerJdbc {

    private final JdbcClient jdbc;

    public WalletLedgerJdbc(JdbcClient jdbc) {
        this.jdbc = jdbc;
    }

    public void ensureWalletRows(UUID playerId) {
        insertWalletIfAbsent(playerId, "COINS");
        insertWalletIfAbsent(playerId, "GEMS");
    }

    private void insertWalletIfAbsent(UUID playerId, String currency) {
        jdbc.sql(
                        """
                        INSERT INTO wallets (player_id, currency, balance)
                        VALUES (:playerId, :currency, 0)
                        ON CONFLICT (player_id, currency) DO NOTHING
                        """)
                .param("playerId", playerId)
                .param("currency", currency)
                .update();
    }

    public long balance(UUID playerId, String currency) {
        Optional<Long> found = jdbc.sql(
                        """
                        SELECT balance FROM wallets
                        WHERE player_id = :playerId AND currency = :currency
                        """)
                .param("playerId", playerId)
                .param("currency", currency)
                .query(Long.class)
                .optional();
        return found.orElse(0L);
    }

    /** Row-lock wallet balance before soft-purchase debit (D-59 / T-04-12). */
    public long lockBalance(UUID playerId, String currency) {
        Optional<Long> found = jdbc.sql(
                        """
                        SELECT balance FROM wallets
                        WHERE player_id = :playerId AND currency = :currency
                        FOR UPDATE
                        """)
                .param("playerId", playerId)
                .param("currency", currency)
                .query(Long.class)
                .optional();
        return found.orElse(0L);
    }

    public List<WalletBalanceRow> balances(UUID playerId) {
        return jdbc.sql(
                        """
                        SELECT currency, balance FROM wallets
                        WHERE player_id = :playerId
                        """)
                .param("playerId", playerId)
                .query((rs, rowNum) -> new WalletBalanceRow(rs.getString("currency"), rs.getLong("balance")))
                .list();
    }

    /**
     * Append ledger row and credit wallet. Locks the wallet row (FOR UPDATE) then applies a
     * relative balance update so concurrent soft debit / match grant cannot lose updates
     * (CR-02 / D-58). Returns empty if idempotency_key already exists (ON CONFLICT DO NOTHING).
     */
    public Optional<Long> creditIfAbsent(
            UUID playerId, String currency, long delta, String reason, String idempotencyKey, UUID ledgerId) {
        long current = lockBalance(playerId, currency);
        long after = current + delta;
        if (after < 0) {
            throw new IllegalStateException("wallet underflow");
        }
        int inserted = jdbc.sql(
                        """
                        INSERT INTO wallet_ledger
                            (id, player_id, currency, delta, balance_after, reason, idempotency_key, created_at)
                        VALUES
                            (:id, :playerId, :currency, :delta, :balanceAfter, :reason, :idempotencyKey, NOW())
                        ON CONFLICT (idempotency_key) DO NOTHING
                        """)
                .param("id", ledgerId)
                .param("playerId", playerId)
                .param("currency", currency)
                .param("delta", delta)
                .param("balanceAfter", after)
                .param("reason", reason)
                .param("idempotencyKey", idempotencyKey)
                .update();
        if (inserted == 0) {
            return Optional.empty();
        }
        jdbc.sql(
                        """
                        UPDATE wallets SET balance = balance + :delta
                        WHERE player_id = :playerId AND currency = :currency
                        """)
                .param("delta", delta)
                .param("playerId", playerId)
                .param("currency", currency)
                .update();
        return Optional.of(after);
    }

    public Optional<LedgerRow> findByIdempotencyKey(String idempotencyKey) {
        return jdbc.sql(
                        """
                        SELECT currency, delta, balance_after FROM wallet_ledger
                        WHERE idempotency_key = :key
                        """)
                .param("key", idempotencyKey)
                .query((rs, rowNum) -> new LedgerRow(
                        rs.getString("currency"), rs.getLong("delta"), rs.getLong("balance_after")))
                .optional();
    }

    public record WalletBalanceRow(String currency, long balance) {}

    public record LedgerRow(String currency, long delta, long balanceAfter) {}
}
