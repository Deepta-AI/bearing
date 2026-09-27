package com.example.pantry.data.network

import retrofit2.http.Body
import retrofit2.http.GET
import retrofit2.http.POST
import retrofit2.http.Path

interface ApiService {
    @POST("auth/login")
    suspend fun login(@Body body: LoginRequestDto): TokenResponseDto

    @POST("auth/refresh")
    suspend fun refresh(@Body body: RefreshRequestDto): TokenResponseDto

    @POST("auth/logout")
    suspend fun logout()

    @GET("orders")
    suspend fun orders(): List<OrderDto>

    // encoded = true: ids from email links arrive already URL-encoded.
    @GET("orders/{id}")
    suspend fun order(@Path(value = "id", encoded = true) id: String): OrderDetailDto
}
