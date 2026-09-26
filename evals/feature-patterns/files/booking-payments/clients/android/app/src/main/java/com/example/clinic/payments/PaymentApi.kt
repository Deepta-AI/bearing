package com.example.clinic.payments

import java.io.IOException
import java.util.UUID

data class CreatePaymentRequest(
    val bookingId: String,
    val amountRupees: Double,
)

data class CreatePaymentResponse(val razorpayOrderId: String, val keyId: String)

interface PaymentService {
    fun createPayment(idempotencyKey: String, body: CreatePaymentRequest): CreatePaymentResponse
}

class PaymentApi(private val service: PaymentService) {

    // Retries network failures so a patient on a weak connection can still pay.
    fun startPayment(bookingId: String, amountRupees: Double): CreatePaymentResponse {
        var lastError: IOException? = null
        repeat(3) {
            val idempotencyKey = UUID.randomUUID().toString()
            try {
                return service.createPayment(idempotencyKey, CreatePaymentRequest(bookingId, amountRupees))
            } catch (e: IOException) {
                lastError = e
            }
        }
        throw lastError ?: IOException("payment failed")
    }
}
