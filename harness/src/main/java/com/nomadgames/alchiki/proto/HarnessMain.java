package com.nomadgames.alchiki.proto;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;

/**
 * Spring-free CLI: ThrowInput file → Dyn4jBurstSim → ThrowResolved file (D-02, D-11).
 * Local files only — no bind port, no HTTP, no WebSocket.
 */
public final class HarnessMain {
    private HarnessMain() {}

    public static void main(String[] args) {
        if (args == null || args.length != 2) {
            System.err.println("usage: HarnessMain <throw_input.json> <throw_resolved.json>");
            System.exit(2);
        }
        Path inputPath = Path.of(args[0]);
        Path outputPath = Path.of(args[1]);
        try {
            String json = Files.readString(inputPath, StandardCharsets.UTF_8);
            ThrowInput input = ThrowInput.parse(json);
            ThrowResolved resolved = Dyn4jBurstSim.simulate(input).resolved();
            Path parent = outputPath.toAbsolutePath().getParent();
            if (parent != null) {
                Files.createDirectories(parent);
            }
            Files.writeString(outputPath, resolved.toJson(), StandardCharsets.UTF_8);
        } catch (IllegalArgumentException ex) {
            System.err.println(ex.getMessage());
            System.exit(1);
        } catch (IOException ex) {
            System.err.println(ex.getMessage());
            System.exit(1);
        }
    }
}
