package com.nomadgames.alchiki.proto;

import java.util.ArrayList;
import java.util.List;

/** One 20 Hz sample: tMs plus body poses (id, x, y, angle). */
public final class Keyframe {
    public final int tMs;
    public final List<BodyPose> bodies;

    public Keyframe(int tMs, List<BodyPose> bodies) {
        if (tMs < 0) {
            throw new IllegalArgumentException("tMs");
        }
        if (bodies == null || bodies.size() > 8) {
            throw new IllegalArgumentException("bodies cap is 8");
        }
        this.tMs = tMs;
        this.bodies = List.copyOf(bodies);
        for (BodyPose pose : this.bodies) {
            JsonSupport.requireFinite("x", pose.x);
            JsonSupport.requireFinite("y", pose.y);
            JsonSupport.requireFinite("angle", pose.angle);
        }
    }

    public void appendJson(StringBuilder out, String indent) {
        String inner = indent + "  ";
        String bodyIndent = inner + "  ";
        out.append(indent).append("{\n");
        out.append(inner).append("\"tMs\": ").append(tMs).append(",\n");
        out.append(inner).append("\"bodies\": [\n");
        for (int i = 0; i < bodies.size(); i++) {
            bodies.get(i).appendJson(out, bodyIndent);
            if (i + 1 < bodies.size()) {
                out.append(',');
            }
            out.append('\n');
        }
        out.append(inner).append("]\n");
        out.append(indent).append('}');
    }

    public static final class BodyPose {
        public final String id;
        public final double x;
        public final double y;
        public final double angle;

        public BodyPose(String id, double x, double y, double angle) {
            if (id == null || id.isBlank()) {
                throw new IllegalArgumentException("id");
            }
            JsonSupport.requireFinite("x", x);
            JsonSupport.requireFinite("y", y);
            JsonSupport.requireFinite("angle", angle);
            this.id = id;
            this.x = x;
            this.y = y;
            this.angle = angle;
        }

        void appendJson(StringBuilder out, String indent) {
            out.append(indent).append('{');
            out.append("\"id\": \"");
            JsonSupport.escape(out, id);
            out.append("\", \"x\": ").append(JsonSupport.number(x));
            out.append(", \"y\": ").append(JsonSupport.number(y));
            out.append(", \"angle\": ").append(JsonSupport.number(angle));
            out.append('}');
        }
    }

    static List<BodyPose> copyCapped(List<BodyPose> source) {
        List<BodyPose> capped = new ArrayList<>(Math.min(8, source.size()));
        for (int i = 0; i < source.size() && capped.size() < 8; i++) {
            capped.add(source.get(i));
        }
        return capped;
    }
}
