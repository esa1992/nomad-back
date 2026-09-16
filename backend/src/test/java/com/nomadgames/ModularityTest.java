package com.nomadgames;

import org.junit.jupiter.api.Test;
import org.springframework.modulith.core.ApplicationModules;

class ModularityTest {

    @Test
    void modulesShouldVerify() {
        ApplicationModules.of(NomadGamesApplication.class).verify();
    }
}
