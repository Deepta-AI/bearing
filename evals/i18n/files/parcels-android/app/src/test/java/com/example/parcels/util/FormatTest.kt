package com.example.parcels.util

import org.junit.Assert.assertEquals
import org.junit.Test

class FormatTest {
    @Test
    fun feeShowsCurrencyAndTwoDecimals() {
        assertEquals("SAR 12.50", Format.fee(1250, "SAR"))
    }
}
