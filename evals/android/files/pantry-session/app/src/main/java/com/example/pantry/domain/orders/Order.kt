package com.example.pantry.domain.orders

import kotlinx.coroutines.flow.Flow

data class Order(val id: Long, val placedAt: String, val totalPaise: Long, val status: String)

/** The signed-in user's past orders, observed from the local cache. */
interface OrdersRepository {
    fun observeOrders(): Flow<List<Order>>

    suspend fun refresh()
}
