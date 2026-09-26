package com.example.app.ui.health

import app.cash.turbine.test
import com.example.app.domain.health.Health
import com.example.app.domain.health.HealthRepository
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import java.io.IOException

/** A fake, not a mock: it is the repository contract with a canned answer. */
private class FakeHealthRepository(private val answer: Result<Health>) : HealthRepository {
    var calls = 0
        private set

    override suspend fun check(): Result<Health> {
        calls++
        return answer
    }
}

@OptIn(ExperimentalCoroutinesApi::class)
class HealthViewModelTest {
    private val dispatcher = StandardTestDispatcher()

    @BeforeEach
    fun setUp() {
        Dispatchers.setMain(dispatcher)
    }

    @AfterEach
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun `starts loading then shows the API answer`() = runTest(dispatcher) {
        val repository = FakeHealthRepository(Result.success(Health(status = "ok", version = "1.2.3")))
        val viewModel = HealthViewModel(repository)

        viewModel.uiState.test {
            assertEquals(HealthUiState.Loading, awaitItem())
            assertEquals(HealthUiState.Ready(status = "ok", version = "1.2.3"), awaitItem())
        }
        assertEquals(1, repository.calls)
    }

    @Test
    fun `maps a failure to the error state with its message`() = runTest(dispatcher) {
        val viewModel = HealthViewModel(FakeHealthRepository(Result.failure(IOException("offline"))))

        viewModel.uiState.test {
            assertEquals(HealthUiState.Loading, awaitItem())
            assertEquals(HealthUiState.Error(message = "offline"), awaitItem())
        }
    }

    @Test
    fun `refresh asks the repository again`() = runTest(dispatcher) {
        val repository = FakeHealthRepository(Result.success(Health(status = "ok", version = "1")))
        val viewModel = HealthViewModel(repository)

        viewModel.uiState.test {
            awaitItem()
            awaitItem()
            viewModel.refresh()
            assertEquals(HealthUiState.Loading, awaitItem())
            assertEquals(HealthUiState.Ready(status = "ok", version = "1"), awaitItem())
        }
        assertEquals(2, repository.calls)
    }
}
