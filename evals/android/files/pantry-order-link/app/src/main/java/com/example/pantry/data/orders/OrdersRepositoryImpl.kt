package com.example.pantry.data.orders

import com.example.pantry.data.network.ApiService
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
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.withContext

@Singleton
class OrdersRepositoryImpl @Inject constructor(
    private val api: ApiService,
    private val dao: OrderDao,
    @IoDispatcher private val io: CoroutineDispatcher,
) : OrdersRepository {
    override fun observeOrders(): Flow<List<Order>> = dao.observeAll().map { rows ->
        rows.map { Order(it.id, it.placedAt, it.totalPaise, it.status) }
    }

    override suspend fun refresh() = withContext(io) {
        val fresh = api.orders().map { OrderEntity(it.id, it.placedAt, it.totalPaise, it.status) }
        dao.replaceAll(fresh)
    }
}

@Module
@InstallIn(SingletonComponent::class)
abstract class OrdersModule {
    @Binds
    abstract fun bindOrdersRepository(impl: OrdersRepositoryImpl): OrdersRepository
}
