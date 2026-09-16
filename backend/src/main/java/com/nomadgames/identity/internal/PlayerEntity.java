package com.nomadgames.identity.internal;

import java.time.Instant;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(name = "players")
public class PlayerEntity {

    @Id
    private UUID id;

    @Column(nullable = false)
    private boolean guest;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    protected PlayerEntity() {
    }

    public PlayerEntity(UUID id, boolean guest, Instant createdAt) {
        this.id = id;
        this.guest = guest;
        this.createdAt = createdAt;
    }

    public UUID getId() {
        return id;
    }

    public boolean isGuest() {
        return guest;
    }

    public void setGuest(boolean guest) {
        this.guest = guest;
    }
}
