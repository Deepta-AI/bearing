package com.example.app.data.network

import kotlinx.serialization.Serializable
import retrofit2.http.GET

/** Wire shape of GET /healthz. DTOs stay in data/network and are mapped in a repository. */
@Serializable
data class HealthDto(
    val status: String,
    val version: String = "unknown",
)

/** Retrofit surface of the API. One function per endpoint, suspend, returning DTOs. */
interface ApiService {
    @GET("healthz")
    suspend fun health(): HealthDto
}
