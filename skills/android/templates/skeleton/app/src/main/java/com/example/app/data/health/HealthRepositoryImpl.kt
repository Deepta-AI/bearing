package com.example.app.data.health

import com.example.app.data.network.ApiService
import com.example.app.data.network.HealthDto
import com.example.app.di.IoDispatcher
import com.example.app.domain.health.Health
import com.example.app.domain.health.HealthRepository
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.withContext
import javax.inject.Inject

/**
 * Fetches health from the API and maps the DTO to the domain type here, so
 * nothing above this class sees Retrofit. A feature with local data would
 * write to Room here and expose a Flow from Room instead.
 */
class HealthRepositoryImpl @Inject constructor(
    private val api: ApiService,
    @IoDispatcher private val io: CoroutineDispatcher,
) : HealthRepository {
    override suspend fun check(): Result<Health> = withContext(io) {
        runCatching { api.health().toDomain() }
            .onFailure { if (it is CancellationException) throw it }
    }
}

private fun HealthDto.toDomain() = Health(status = status, version = version)
