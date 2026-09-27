package com.example.parcels

import java.time.Instant

enum class ParcelStatus { IN_TRANSIT, OUT_FOR_DELIVERY, DELIVERED }

data class Parcel(
    val trackingId: String,
    val status: ParcelStatus,
    val etaMinutes: Int?,
    val deliveredAt: Instant?,
    val feeMinor: Long,
    val currency: String,
)

object Parcels {
    val sample = listOf(
        Parcel("PX-1042", ParcelStatus.OUT_FOR_DELIVERY, 25, null, 1250, "SAR"),
        Parcel("PX-1043", ParcelStatus.IN_TRANSIT, null, null, 1250, "SAR"),
        Parcel("PX-0998", ParcelStatus.DELIVERED, null, Instant.parse("2026-09-20T14:05:00Z"), 900, "SAR"),
        Parcel("PX-2210", ParcelStatus.IN_TRANSIT, null, null, 1250, "BHD"),
    )
}
