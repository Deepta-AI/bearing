package com.example.pantry.domain.auth

/** A signed-in user's tokens. [accessExpiresAtEpochSec] comes from the server's expires_in. */
data class Session(
    val userId: Long,
    val accessToken: String,
    val refreshToken: String,
    val accessExpiresAtEpochSec: Long,
)
