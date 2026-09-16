package com.nomadgames.economy;

import java.util.Map;
import java.util.UUID;

import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

@RestController
public class EconomyController {

    private final EconomyService economy;

    public EconomyController(EconomyService economy) {
        this.economy = economy;
    }

    @GetMapping("/v1/wallet")
    public WalletView wallet(@AuthenticationPrincipal Jwt jwt) {
        return economy.getWallet(playerId(jwt));
    }

    @GetMapping("/v1/shop/catalog")
    public ShopCatalog catalog(@AuthenticationPrincipal Jwt jwt) {
        return economy.listCatalog(playerId(jwt));
    }

    @PostMapping("/v1/shop/purchases")
    public PurchaseResult purchase(@AuthenticationPrincipal Jwt jwt, @RequestBody PurchaseRequest body) {
        if (body == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "body required");
        }
        return economy.purchase(playerId(jwt), body.skuId(), body.idempotencyKey());
    }

    @PostMapping("/v1/shop/equip")
    public EquipResult equip(@AuthenticationPrincipal Jwt jwt, @RequestBody EquipRequest body) {
        if (body == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "body required");
        }
        return economy.equip(playerId(jwt), body.slot(), body.skuId());
    }

    @GetMapping("/v1/loadout")
    public Map<String, String> loadout(@AuthenticationPrincipal Jwt jwt) {
        return economy.getLoadout(playerId(jwt));
    }

    private static UUID playerId(Jwt jwt) {
        return UUID.fromString(jwt.getSubject());
    }
}
