package com.nomadgames.alchiki.proto;

import java.util.List;

/**
 * Authority output. pocketedCount is written only here from dyn4j rest poses (D-10).
 */
public final class ThrowResolved {
    public static final int SCHEMA_VERSION = 1;
    public static final int KEYFRAME_CAP = 40;

    public final int schemaVersion;
    public final boolean yUp;
    public final ThrowInput input;
    public final TableConstants table;
    public final boolean settled;
    public final String settleReason;
    public final int simMs;
    public final int pocketedCount;
    public final boolean sakaOut;
    public final List<String> pocketedIds;
    public final List<Keyframe> keyframes;

    public ThrowResolved(
            ThrowInput input,
            TableConstants table,
            boolean settled,
            String settleReason,
            int simMs,
            int pocketedCount,
            boolean sakaOut,
            List<String> pocketedIds,
            List<Keyframe> keyframes) {
        if (input == null || table == null) {
            throw new IllegalArgumentException("input/table");
        }
        if (!"sleep".equals(settleReason) && !"timeout".equals(settleReason)) {
            throw new IllegalArgumentException("settleReason");
        }
        if (simMs < 0 || pocketedCount < 0) {
            throw new IllegalArgumentException("simMs/pocketedCount");
        }
        if (keyframes == null || keyframes.size() > KEYFRAME_CAP) {
            throw new IllegalArgumentException("keyframes cap is 40");
        }
        this.schemaVersion = SCHEMA_VERSION;
        this.yUp = true;
        this.input = input;
        this.table = table;
        this.settled = settled;
        this.settleReason = settleReason;
        this.simMs = simMs;
        this.pocketedCount = pocketedCount;
        this.sakaOut = sakaOut;
        this.pocketedIds = List.copyOf(pocketedIds);
        this.keyframes = List.copyOf(keyframes);
    }

    /** HUD scored value: saka leaving the circle scores 0 (D-08). */
    public int displayedScore() {
        return sakaOut ? 0 : pocketedCount;
    }

    public String toJson() {
        StringBuilder out = new StringBuilder();
        appendJson(out);
        return out.toString();
    }

    public void appendJson(StringBuilder out) {
        out.append("{\n");
        out.append("  \"schemaVersion\": ").append(schemaVersion).append(",\n");
        out.append("  \"yUp\": true,\n");
        out.append("  \"input\":\n");
        input.appendJson(out, "  ");
        out.append(",\n");
        out.append("  \"table\":\n");
        table.appendJson(out, "  ");
        out.append(",\n");
        out.append("  \"settled\": ").append(settled).append(",\n");
        out.append("  \"settleReason\": \"").append(settleReason).append("\",\n");
        out.append("  \"simMs\": ").append(simMs).append(",\n");
        out.append("  \"pocketedCount\": ").append(pocketedCount).append(",\n");
        out.append("  \"sakaOut\": ").append(sakaOut).append(",\n");
        out.append("  \"pocketedIds\": [");
        for (int i = 0; i < pocketedIds.size(); i++) {
            if (i > 0) {
                out.append(", ");
            }
            out.append('"');
            JsonSupport.escape(out, pocketedIds.get(i));
            out.append('"');
        }
        out.append("],\n");
        out.append("  \"keyframes\": [\n");
        for (int i = 0; i < keyframes.size(); i++) {
            keyframes.get(i).appendJson(out, "    ");
            if (i + 1 < keyframes.size()) {
                out.append(',');
            }
            out.append('\n');
        }
        out.append("  ]\n");
        out.append("}\n");
    }
}
