package com.example.pantry.ui.orderlink

import com.example.pantry.data.network.ApiService
import com.example.pantry.data.network.LoginRequestDto
import com.example.pantry.data.network.OrderDetailDto
import com.example.pantry.data.network.OrderDto
import com.example.pantry.data.network.RefreshRequestDto
import com.example.pantry.data.network.TokenResponseDto
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test

private class FakeApi : ApiService {
    override suspend fun login(body: LoginRequestDto): TokenResponseDto = error("unused")
    override suspend fun refresh(body: RefreshRequestDto): TokenResponseDto = error("unused")
    override suspend fun logout() = Unit
    override suspend fun orders(): List<OrderDto> = emptyList()
    override suspend fun order(id: String) = OrderDetailDto(id.toLong(), "2026-09-20", 125_000, "delivered", emptyList())
}

class OrderDetailViewModelTest {
    @Test
    fun `loads the order from the link`() {
        val vm = OrderDetailViewModel(FakeApi())
        vm.load("42")
        Thread.sleep(500)
        assertEquals(42L, vm.order.value?.id)
    }
}
