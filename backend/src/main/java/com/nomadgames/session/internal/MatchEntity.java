package com.nomadgames.session.internal;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import com.nomadgames.session.BodyPoseView;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(name = "matches")
public class MatchEntity {

    @Id
    private UUID id;

    @Column(name = "player_id", nullable = false)
    private UUID playerId;

    @Column(nullable = false)
    private String game;

    @Column(nullable = false)
    private String mode;

    @Column(nullable = false)
    private String difficulty;

    @Column(nullable = false)
    private String status;

    @Column(name = "player_score", nullable = false)
    private int playerScore;

    @Column(name = "bot_score", nullable = false)
    private int botScore;

    @Column(name = "player_turns", nullable = false)
    private int playerTurns;

    @Column(name = "bot_turns", nullable = false)
    private int botTurns;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "bones_left", nullable = false)
    private List<String> bonesLeft = new ArrayList<>();

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "bone_poses", nullable = false)
    private List<BodyPoseView> bonePoses = new ArrayList<>();

    @Column(nullable = false)
    private String turn;

    @Column(name = "turn_deadline", nullable = false)
    private Instant turnDeadline;

    @Column(name = "match_deadline", nullable = false)
    private Instant matchDeadline;

    @Column(name = "hard_cap", nullable = false)
    private Instant hardCap;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "host_id")
    private UUID hostId;

    @Column(name = "joiner_id")
    private UUID joinerId;

    @Column(name = "host_reconnect_token_hash")
    private byte[] hostReconnectTokenHash;

    @Column(name = "joiner_reconnect_token_hash")
    private byte[] joinerReconnectTokenHash;

    protected MatchEntity() {}

    public MatchEntity(
            UUID id,
            UUID playerId,
            String game,
            String mode,
            String difficulty,
            String status,
            List<String> bonesLeft,
            String turn,
            Instant turnDeadline,
            Instant matchDeadline,
            Instant hardCap,
            Instant createdAt) {
        this.id = id;
        this.playerId = playerId;
        this.game = game;
        this.mode = mode;
        this.difficulty = difficulty;
        this.status = status;
        this.bonesLeft = new ArrayList<>(bonesLeft);
        this.bonePoses = new ArrayList<>();
        this.turn = turn;
        this.turnDeadline = turnDeadline;
        this.matchDeadline = matchDeadline;
        this.hardCap = hardCap;
        this.createdAt = createdAt;
    }

    public MatchEntity(
            UUID id,
            UUID playerId,
            String game,
            String mode,
            String difficulty,
            String status,
            List<String> bonesLeft,
            String turn,
            Instant turnDeadline,
            Instant matchDeadline,
            Instant hardCap,
            Instant createdAt,
            UUID hostId,
            UUID joinerId) {
        this(
                id,
                playerId,
                game,
                mode,
                difficulty,
                status,
                bonesLeft,
                turn,
                turnDeadline,
                matchDeadline,
                hardCap,
                createdAt);
        this.hostId = hostId;
        this.joinerId = joinerId;
    }

    public UUID getId() {
        return id;
    }

    public UUID getPlayerId() {
        return playerId;
    }

    public String getGame() {
        return game;
    }

    public String getDifficulty() {
        return difficulty;
    }

    public String getMode() {
        return mode;
    }

    public UUID getHostId() {
        return hostId;
    }

    public UUID getJoinerId() {
        return joinerId;
    }

    public String getStatus() {
        return status;
    }

    public int getPlayerScore() {
        return playerScore;
    }

    public int getBotScore() {
        return botScore;
    }

    public List<String> getBonesLeft() {
        return bonesLeft;
    }

    public List<BodyPoseView> getBonePoses() {
        return bonePoses == null ? List.of() : bonePoses;
    }

    public void setBonePoses(List<BodyPoseView> bonePoses) {
        this.bonePoses = bonePoses == null ? new ArrayList<>() : new ArrayList<>(bonePoses);
    }

    public String getTurn() {
        return turn;
    }

    public Instant getTurnDeadline() {
        return turnDeadline;
    }

    public Instant getMatchDeadline() {
        return matchDeadline;
    }

    public Instant getHardCap() {
        return hardCap;
    }

    public void setPlayerScore(int playerScore) {
        this.playerScore = playerScore;
    }

    public void setPlayerTurns(int playerTurns) {
        this.playerTurns = playerTurns;
    }

    public int getPlayerTurns() {
        return playerTurns;
    }

    public void setBonesLeft(List<String> bonesLeft) {
        this.bonesLeft = new ArrayList<>(bonesLeft);
    }

    public int getBotTurns() {
        return botTurns;
    }

    public void setBotTurns(int botTurns) {
        this.botTurns = botTurns;
    }

    public void setBotScore(int botScore) {
        this.botScore = botScore;
    }

    public void setStatus(String status) {
        this.status = status;
    }

    public void setTurn(String turn) {
        this.turn = turn;
    }

    public void setTurnDeadline(Instant turnDeadline) {
        this.turnDeadline = turnDeadline;
    }

    public void setMatchDeadline(Instant matchDeadline) {
        this.matchDeadline = matchDeadline;
    }

    public void setHardCap(Instant hardCap) {
        this.hardCap = hardCap;
    }

    public byte[] getHostReconnectTokenHash() {
        return hostReconnectTokenHash;
    }

    public void setHostReconnectTokenHash(byte[] hostReconnectTokenHash) {
        this.hostReconnectTokenHash = hostReconnectTokenHash;
    }

    public byte[] getJoinerReconnectTokenHash() {
        return joinerReconnectTokenHash;
    }

    public void setJoinerReconnectTokenHash(byte[] joinerReconnectTokenHash) {
        this.joinerReconnectTokenHash = joinerReconnectTokenHash;
    }
}
