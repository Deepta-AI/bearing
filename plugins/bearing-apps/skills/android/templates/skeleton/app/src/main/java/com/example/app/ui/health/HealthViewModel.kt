package com.example.app.ui.health

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.app.domain.health.HealthRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

/** Everything the health screen can show. One sealed state, no separate loading or error flags. */
sealed interface HealthUiState {
    data object Loading : HealthUiState

    data class Ready(val status: String, val version: String) : HealthUiState

    data class Error(val message: String) : HealthUiState
}

/** Owns the health screen state. Exposes one StateFlow; the UI calls [refresh]. */
@HiltViewModel
class HealthViewModel @Inject constructor(
    private val repository: HealthRepository,
) : ViewModel() {
    private val _uiState = MutableStateFlow<HealthUiState>(HealthUiState.Loading)
    val uiState: StateFlow<HealthUiState> = _uiState.asStateFlow()

    init {
        refresh()
    }

    /** Re-checks the API. Safe to call while a check is in flight; the last result wins. */
    fun refresh() {
        viewModelScope.launch {
            _uiState.value = HealthUiState.Loading
            _uiState.value = repository.check().fold(
                onSuccess = { HealthUiState.Ready(status = it.status, version = it.version) },
                onFailure = { HealthUiState.Error(message = it.message ?: it::class.simpleName.orEmpty()) },
            )
        }
    }
}
