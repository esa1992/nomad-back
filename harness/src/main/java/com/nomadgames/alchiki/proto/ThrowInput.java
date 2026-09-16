package com.nomadgames.alchiki.proto;

/**
 * Shared ThrowInput DTO. Keys match the PROTO-01 client contract (D-05, D-09, D-10).
 * Parse clamps holdMs 150–1100, rejects non-finite aim, requires schemaVersion 1.
 * Unknown keys including score-like fields are ignored.
 */
public final class ThrowInput {
    public static final int SCHEMA_VERSION = 1;
    public static final int HOLD_MS_MIN = 150;
    public static final int HOLD_MS_MAX = 1100;

    public final int schemaVersion;
    public final boolean yUp;
    public final double aimAngleRad;
    public final int holdMs;
    public final int seed;
    public final String tableId;

    public ThrowInput(
            int schemaVersion,
            boolean yUp,
            double aimAngleRad,
            int holdMs,
            int seed,
            String tableId) {
        if (schemaVersion != SCHEMA_VERSION) {
            throw new IllegalArgumentException("schemaVersion must be 1");
        }
        if (!yUp) {
            throw new IllegalArgumentException("yUp must be true");
        }
        JsonSupport.requireFinite("aimAngleRad", aimAngleRad);
        this.schemaVersion = schemaVersion;
        this.yUp = true;
        this.aimAngleRad = aimAngleRad;
        this.holdMs = clampHoldMs(holdMs);
        this.seed = seed;
        this.tableId = tableId == null ? "" : tableId;
    }

    /**
     * Hand-written JSON object parse. Unknown keys (including score-like fields)
     * are ignored. Does not {@code eval} the payload.
     */
    public static ThrowInput parse(String json) {
        if (json == null) {
            throw new IllegalArgumentException("json");
        }
        int schemaVersion = readInt(json, "schemaVersion", 0);
        if (schemaVersion != SCHEMA_VERSION) {
            throw new IllegalArgumentException("schemaVersion must be 1");
        }
        boolean yUp = readBoolean(json, "yUp", false);
        if (!yUp) {
            throw new IllegalArgumentException("yUp must be true");
        }
        Double aim = readDoubleOrNull(json, "aimAngleRad");
        if (aim == null || !Double.isFinite(aim)) {
            throw new IllegalArgumentException("aimAngleRad must be finite");
        }
        int holdMs = clampHoldMs(readInt(json, "holdMs", 0));
        return new ThrowInput(
                schemaVersion,
                true,
                aim,
                holdMs,
                readInt(json, "seed", 0),
                readString(json, "tableId", ""));
    }

    public static int clampHoldMs(int holdMs) {
        return Math.max(HOLD_MS_MIN, Math.min(HOLD_MS_MAX, holdMs));
    }

    public static double impulseFromHoldMs(int holdMs) {
        int clamped = clampHoldMs(holdMs);
        double t = (clamped - HOLD_MS_MIN) / (double) (HOLD_MS_MAX - HOLD_MS_MIN);
        return TableConstants.impulseMinNs
                + t * (TableConstants.impulseMaxNs - TableConstants.impulseMinNs);
    }

    public void appendJson(StringBuilder out, String indent) {
        String inner = indent + "  ";
        out.append(indent).append("{\n");
        out.append(inner).append("\"schemaVersion\": ").append(schemaVersion).append(",\n");
        out.append(inner).append("\"yUp\": true,\n");
        out.append(inner).append("\"aimAngleRad\": ").append(JsonSupport.number(aimAngleRad)).append(",\n");
        out.append(inner).append("\"holdMs\": ").append(holdMs).append(",\n");
        out.append(inner).append("\"seed\": ").append(seed).append(",\n");
        out.append(inner).append("\"tableId\": \"");
        JsonSupport.escape(out, tableId);
        out.append("\"\n");
        out.append(indent).append('}');
    }

    private static int readInt(String json, String key, int fallback) {
        String raw = readRawValue(json, key);
        if (raw == null) {
            return fallback;
        }
        try {
            double value = Double.parseDouble(raw);
            JsonSupport.requireFinite(key, value);
            return (int) value;
        } catch (NumberFormatException ex) {
            return fallback;
        }
    }

    private static Double readDoubleOrNull(String json, String key) {
        String raw = readRawValue(json, key);
        if (raw == null) {
            return null;
        }
        try {
            return Double.parseDouble(raw);
        } catch (NumberFormatException ex) {
            return null;
        }
    }

    private static boolean readBoolean(String json, String key, boolean fallback) {
        String raw = readRawValue(json, key);
        if (raw == null) {
            return fallback;
        }
        if ("true".equals(raw)) {
            return true;
        }
        if ("false".equals(raw)) {
            return false;
        }
        return fallback;
    }

    private static String readString(String json, String key, String fallback) {
        int valueAt = findValueStart(json, key);
        if (valueAt < 0 || json.charAt(valueAt) != '"') {
            return fallback;
        }
        StringBuilder out = new StringBuilder();
        for (int i = valueAt + 1; i < json.length(); i++) {
            char c = json.charAt(i);
            if (c == '\\' && i + 1 < json.length()) {
                out.append(json.charAt(i + 1));
                i++;
                continue;
            }
            if (c == '"') {
                return out.toString();
            }
            out.append(c);
        }
        return fallback;
    }

    private static String readRawValue(String json, String key) {
        int valueAt = findValueStart(json, key);
        if (valueAt < 0 || json.charAt(valueAt) == '"') {
            return null;
        }
        int end = valueAt;
        while (end < json.length()) {
            char c = json.charAt(end);
            if (c == ',' || c == '}' || Character.isWhitespace(c)) {
                break;
            }
            end++;
        }
        return json.substring(valueAt, end);
    }

    private static int findValueStart(String json, String key) {
        String needle = "\"" + key + "\"";
        int from = 0;
        while (from < json.length()) {
            int at = json.indexOf(needle, from);
            if (at < 0) {
                return -1;
            }
            int after = skipWs(json, at + needle.length());
            if (after < json.length() && json.charAt(after) == ':') {
                return skipWs(json, after + 1);
            }
            from = at + 1;
        }
        return -1;
    }

    private static int skipWs(String json, int i) {
        while (i < json.length() && Character.isWhitespace(json.charAt(i))) {
            i++;
        }
        return i;
    }
}
