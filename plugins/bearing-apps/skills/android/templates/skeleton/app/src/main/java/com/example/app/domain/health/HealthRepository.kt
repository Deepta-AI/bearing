package com.example.app.domain.health

/** The single door to health data. Implementations decide where it comes from; callers never know. */
interface HealthRepository {
    /** Asks the API whether it is up. Failure carries the cause; cancellation is never wrapped. */
    suspend fun check(): Result<Health>
}
