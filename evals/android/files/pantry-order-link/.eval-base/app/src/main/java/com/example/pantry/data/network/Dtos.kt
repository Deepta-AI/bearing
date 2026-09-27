package com.example.pantry.data.network

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class LoginRequestDto(val email: String, val password: String)

@Serializable
data class RefreshRequestDto(@SerialName("refresh_token") val refreshToken: String)

@Serializable
data class TokenResponseDto(
    @SerialName("access_token") val accessToken: String,
    @SerialName("refresh_token") val refreshToken: String,
    @SerialName("expires_in") val expiresIn: Long,
    @SerialName("user_id") val userId: Long,
)

@Serializable
data class OrderDto(
    val id: Long,
    @SerialName("placed_at") val placedAt: String,
    @SerialName("total_paise") val totalPaise: Long,
    val status: String,
)
