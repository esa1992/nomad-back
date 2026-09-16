package com.nomadgames.alchiki.proto;

/**
 * Shared table constants from 01-RESEARCH.md Shared ThrowInput table only.
 * Both engines: meters, Y-up, gravity (0,0), physicsHz 60.
 */
public final class TableConstants {
    public static final double circleRadiusM = 1.40;
    public static final double sakaRadiusM = 0.07;
    public static final double boneRadiusM = 0.055;
    public static final double sakaMassKg = 0.12;
    public static final double boneMassKg = 0.055;
    public static final double friction = 0.30;
    public static final double restitution = 0.38;
    public static final double linearDamping = 1.15;
    public static final double angularDamping = 0.85;
    public static final double impulseMinNs = 0.06;
    public static final double impulseMaxNs = 0.38;
    public static final int physicsHz = 60;
    public static final int keyframeHz = 20;
    public static final double settleTimeoutS = 1.2;
    public static final int boneCount = 6;

    public static final TableConstants PROTO_V1 = new TableConstants();

    private TableConstants() {}

    public void appendJson(StringBuilder out, String indent) {
        String inner = indent + "  ";
        out.append(indent).append("{\n");
        field(out, inner, "circleRadiusM", circleRadiusM, true);
        field(out, inner, "sakaRadiusM", sakaRadiusM, true);
        field(out, inner, "boneRadiusM", boneRadiusM, true);
        field(out, inner, "sakaMassKg", sakaMassKg, true);
        field(out, inner, "boneMassKg", boneMassKg, true);
        field(out, inner, "friction", friction, true);
        field(out, inner, "restitution", restitution, true);
        field(out, inner, "linearDamping", linearDamping, true);
        field(out, inner, "angularDamping", angularDamping, true);
        field(out, inner, "impulseMinNs", impulseMinNs, true);
        field(out, inner, "impulseMaxNs", impulseMaxNs, true);
        field(out, inner, "physicsHz", physicsHz, true);
        field(out, inner, "keyframeHz", keyframeHz, true);
        field(out, inner, "settleTimeoutS", settleTimeoutS, true);
        field(out, inner, "boneCount", boneCount, false);
        out.append('\n').append(indent).append('}');
    }

    private static void field(StringBuilder out, String indent, String name, double value, boolean comma) {
        JsonSupport.requireFinite(name, value);
        out.append(indent).append('"').append(name).append("\": ").append(JsonSupport.number(value));
        if (comma) {
            out.append(",\n");
        }
    }
}
