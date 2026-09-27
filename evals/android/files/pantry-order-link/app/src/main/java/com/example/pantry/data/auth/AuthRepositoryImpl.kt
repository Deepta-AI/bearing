package com.example.pantry.data.auth

import com.example.pantry.data.network.ApiService
import com.example.pantry.data.network.LoginRequestDto
import com.example.pantry.data.network.TokenResponseDto
import com.example.pantry.di.IoDispatcher
import com.example.pantry.domain.auth.AuthRepository
import com.example.pantry.domain.auth.Session
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.withContext

@Singleton
class AuthRepositoryImpl @Inject constructor(
    private val api: ApiService,
    private val holder: SessionHolder,
    @IoDispatcher private val io: CoroutineDispatcher,
) : AuthRepository {
    override val session: StateFlow<Session?> = holder.session

    override suspend fun login(email: String, password: String) = withContext(io) {
        val response = api.login(LoginRequestDto(email, password))
        holder.set(response.toSession(System.currentTimeMillis() / 1000))
    }

    override suspend fun logout() {
        holder.set(null)
    }
}

internal fun TokenResponseDto.toSession(nowEpochSec: Long) = Session(
    userId = userId,
    accessToken = accessToken,
    refreshToken = refreshToken,
    accessExpiresAtEpochSec = nowEpochSec + expiresIn,
)
