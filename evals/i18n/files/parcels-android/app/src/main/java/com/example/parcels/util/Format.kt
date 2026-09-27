package com.example.parcels.util

import java.text.SimpleDateFormat
import java.time.Instant
import java.util.Date
import java.util.Locale

object Format {
    // Fees are minor units (halalas, paise) with an ISO 4217 code.
    fun fee(minor: Long, currency: String): String =
        currency + " " + String.format("%.2f", minor / 100.0)

    fun dateTime(instant: Instant): String =
        SimpleDateFormat("dd/MM/yyyy hh:mm a", Locale.US).format(Date.from(instant))
}
