package com.nomadgames;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling
public class NomadGamesApplication {

    public static void main(String[] args) {
        SpringApplication.run(NomadGamesApplication.class, args);
    }
}
