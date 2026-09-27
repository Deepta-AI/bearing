package com.example.pantry.data.orders

import com.example.pantry.data.network.ApiService
import com.example.pantry.di.ApplicationScope
import com.example.pantry.di.IoDispatcher
import com.example.pantry.domain.orders.Order
import com.example.pantry.domain.orders.OrdersRepository
import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.async
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

@Singleton
class OrdersRepositoryImpl @Inject constructor(
    private val api: ApiService,
    private val dao: OrderDao,
    @IoDispatcher private val io: CoroutineDispatcher,
    @ApplicationScope private val appScope: CoroutineScope,
) : OrdersRepository {
    override fun observeOrders(): Flow<List<Order>> = dao.observeAll().map { rows ->
        rows.map { Order(it.id, it.placedAt, it.totalPaise, it.status) }
    }

    // Runs in the application scope so a slow refresh started on the orders
    // screen still lands in the cache when the user leaves the screen.
    override suspend fun refresh() {
        appScope.async(io) {
            val fresh = api.orders().map { OrderEntity(it.id, it.placedAt, it.totalPaise, it.status) }
            dao.replaceAll(fresh)
        }.await()
    }
}

@Module
@InstallIn(SingletonComponent::class)
abstract class OrdersModule {
    @Binds
    abstract fun bindOrdersRepository(impl: OrdersRepositoryImpl): OrdersRepository
}
