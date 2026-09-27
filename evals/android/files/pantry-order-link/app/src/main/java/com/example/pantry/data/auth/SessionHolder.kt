package com.example.pantry.data.auth

import com.example.pantry.domain.auth.Session
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/** The current session, in memory only. Lost when the process dies. */
@Singleton
class SessionHolder @Inject constructor() {
    private val current = MutableStateFlow<Session?>(null)
    val session: StateFlow<Session?> = current.asStateFlow()

    fun set(session: Session?) {
        current.value = session
    }
}
