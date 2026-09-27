package com.example.pantry.ui.login

import app.cash.turbine.test
import com.example.pantry.domain.auth.AuthRepository
import com.example.pantry.domain.auth.Session
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test

private class FakeAuthRepository(private val fail: Boolean) : AuthRepository {
    override val session = MutableStateFlow<Session?>(null)

    override suspend fun login(email: String, password: String) {
        if (fail) error("401")
        session.value = Session(1, "a", "r", 0)
    }

    override suspend fun logout() {
        session.value = null
    }
}

@OptIn(ExperimentalCoroutinesApi::class)
class LoginViewModelTest {
    private val dispatcher = StandardTestDispatcher()

    @BeforeEach
    fun setUp() = Dispatchers.setMain(dispatcher)

    @AfterEach
    fun tearDown() = Dispatchers.resetMain()

    @Test
    fun `successful login ends signed in`() = runTest(dispatcher) {
        val vm = LoginViewModel(FakeAuthRepository(fail = false))
        vm.uiState.test {
            assertEquals(LoginUiState.Idle, awaitItem())
            vm.submit("a@example.com", "pw")
            assertEquals(LoginUiState.Submitting, awaitItem())
            assertEquals(LoginUiState.SignedIn, awaitItem())
        }
    }

    @Test
    fun `failed login reports failure`() = runTest(dispatcher) {
        val vm = LoginViewModel(FakeAuthRepository(fail = true))
        vm.uiState.test {
            assertEquals(LoginUiState.Idle, awaitItem())
            vm.submit("a@example.com", "bad")
            assertEquals(LoginUiState.Submitting, awaitItem())
            assertEquals(LoginUiState.Failed, awaitItem())
        }
    }
}
