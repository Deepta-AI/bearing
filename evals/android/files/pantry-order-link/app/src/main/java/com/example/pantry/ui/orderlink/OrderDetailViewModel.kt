package com.example.pantry.ui.orderlink

import androidx.lifecycle.ViewModel
import com.example.pantry.data.network.ApiService
import com.example.pantry.data.network.OrderDetailDto
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.launch

@HiltViewModel
class OrderDetailViewModel @Inject constructor(
    private val api: ApiService,
) : ViewModel() {
    val order = MutableStateFlow<OrderDetailDto?>(null)

    fun load(id: String) {
        GlobalScope.launch(Dispatchers.IO) {
            runCatching { api.order(id) }
                .onSuccess { order.value = it }
        }
    }
}
