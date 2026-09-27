package com.example.pantry.ui.orders

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.pantry.domain.auth.AuthRepository
import com.example.pantry.domain.orders.Order
import com.example.pantry.domain.orders.OrdersRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

sealed interface OrdersUiState {
    data object Loading : OrdersUiState
    data class Ready(val orders: List<Order>, val refreshFailed: Boolean) : OrdersUiState
}

@HiltViewModel
class OrdersViewModel @Inject constructor(
    private val orders: OrdersRepository,
    private val auth: AuthRepository,
) : ViewModel() {
    private val refreshFailed = MutableStateFlow(false)

    val uiState: StateFlow<OrdersUiState> = combine(orders.observeOrders(), refreshFailed) { list, failed ->
        OrdersUiState.Ready(list, failed) as OrdersUiState
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), OrdersUiState.Loading)

    init {
        refresh()
    }

    fun refresh() {
        viewModelScope.launch {
            refreshFailed.value = try {
                orders.refresh()
                false
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                true
            }
        }
    }

    fun logout(onDone: () -> Unit) {
        viewModelScope.launch {
            auth.logout()
            onDone()
        }
    }
}
