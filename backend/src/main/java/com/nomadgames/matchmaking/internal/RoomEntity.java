package com.nomadgames.matchmaking.internal;

import java.time.Instant;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.Version;

@Entity
@Table(name = "rooms")
public class RoomEntity {

    @Id
    private UUID id;

    @Column(nullable = false, unique = true, length = 6)
    private String code;

    @Column(name = "host_id", nullable = false)
    private UUID hostId;

    @Column(name = "joiner_id")
    private UUID joinerId;

    @Column(name = "host_ready", nullable = false)
    private boolean hostReady;

    @Column(name = "joiner_ready", nullable = false)
    private boolean joinerReady;

    @Column(nullable = false)
    private String status;

    @Column(name = "match_id")
    private UUID matchId;

    @Column(name = "idle_expires_at", nullable = false)
    private Instant idleExpiresAt;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(nullable = false)
    private String game = "ALCHIKI";

    @Version
    @Column(nullable = false)
    private long version;

    protected RoomEntity() {}

    public RoomEntity(
            UUID id,
            String code,
            UUID hostId,
            String status,
            Instant idleExpiresAt,
            Instant createdAt) {
        this(id, code, hostId, status, idleExpiresAt, createdAt, "ALCHIKI");
    }

    public RoomEntity(
            UUID id,
            String code,
            UUID hostId,
            String status,
            Instant idleExpiresAt,
            Instant createdAt,
            String game) {
        this.id = id;
        this.code = code;
        this.hostId = hostId;
        this.status = status;
        this.idleExpiresAt = idleExpiresAt;
        this.createdAt = createdAt;
        this.game = game;
    }

    public UUID getId() {
        return id;
    }

    public String getCode() {
        return code;
    }

    public UUID getHostId() {
        return hostId;
    }

    public UUID getJoinerId() {
        return joinerId;
    }

    public void setJoinerId(UUID joinerId) {
        this.joinerId = joinerId;
    }

    public void setHostReady(boolean hostReady) {
        this.hostReady = hostReady;
    }

    public void setJoinerReady(boolean joinerReady) {
        this.joinerReady = joinerReady;
    }

    public boolean isHostReady() {
        return hostReady;
    }

    public boolean isJoinerReady() {
        return joinerReady;
    }

    public String getStatus() {
        return status;
    }

    public void setStatus(String status) {
        this.status = status;
    }

    public UUID getMatchId() {
        return matchId;
    }

    public void setMatchId(UUID matchId) {
        this.matchId = matchId;
    }

    public Instant getIdleExpiresAt() {
        return idleExpiresAt;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public String getGame() {
        return game;
    }
}
