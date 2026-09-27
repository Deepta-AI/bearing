package com.example.pantry.ui.login

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.pantry.domain.auth.AuthRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

sealed interface LoginUiState {
    data object Idle : LoginUiState
    data object Submitting : LoginUiState
    data object Failed : LoginUiState
    data object SignedIn : LoginUiState
}

@HiltViewModel
class LoginViewModel @Inject constructor(
    private val auth: AuthRepository,
) : ViewModel() {
    private val state = MutableStateFlow<LoginUiState>(LoginUiState.Idle)
    val uiState: StateFlow<LoginUiState> = state.asStateFlow()

    fun submit(email: String, password: String) {
        if (state.value == LoginUiState.Submitting) return
        state.value = LoginUiState.Submitting
        viewModelScope.launch {
            state.value = try {
                auth.login(email.trim(), password)
                LoginUiState.SignedIn
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                LoginUiState.Failed
            }
        }
    }
}
