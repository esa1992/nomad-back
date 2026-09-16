package com.nomadgames.session;

import org.springframework.context.annotation.Configuration;
import org.springframework.web.socket.config.annotation.EnableWebSocket;
import org.springframework.web.socket.config.annotation.WebSocketConfigurer;
import org.springframework.web.socket.config.annotation.WebSocketHandlerRegistry;

import com.nomadgames.session.internal.MatchWebSocketHandler;
import com.nomadgames.session.internal.WsTicketInterceptor;

@Configuration
@EnableWebSocket
public class MatchWebSocketConfig implements WebSocketConfigurer {

    private final MatchWebSocketHandler matchHandler;
    private final WsTicketInterceptor ticketInterceptor;

    public MatchWebSocketConfig(MatchWebSocketHandler matchHandler, WsTicketInterceptor ticketInterceptor) {
        this.matchHandler = matchHandler;
        this.ticketInterceptor = ticketInterceptor;
    }

    @Override
    public void registerWebSocketHandlers(WebSocketHandlerRegistry registry) {
        registry.addHandler(matchHandler, "/v1/matches/{matchId}/ws")
                .addInterceptors(ticketInterceptor)
                .setAllowedOriginPatterns("*");
    }
}
