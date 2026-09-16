package com.nomadgames.identity.internal;

import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

public interface CredentialRepository extends JpaRepository<CredentialEntity, UUID> {

    boolean existsByUsernameIgnoreCase(String username);

    Optional<CredentialEntity> findByUsernameIgnoreCase(String username);
}
