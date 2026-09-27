package com.example.pantry.domain.auth

import kotlinx.coroutines.flow.StateFlow

/** Signs the user in and out and exposes the current session. */
interface AuthRepository {
    val session: StateFlow<Session?>

    suspend fun login(email: String, password: String)

    suspend fun logout()
}
