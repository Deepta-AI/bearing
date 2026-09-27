package com.example.routebook.location

import android.content.Context
import com.example.routebook.BuildConfig
import com.example.routebook.net.Session
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody

/** Posts the driver's position to dispatch so customers get a live ETA. */
class LocationUploader(private val context: Context) {

    private val http = OkHttpClient()

    fun send(lat: Double, lng: Double, at: Long) {
        val driverId = Session.driverId(context) ?: return
        val body = """{"driverId":"$driverId","lat":$lat,"lng":$lng,"at":$at}"""
            .toRequestBody("application/json".toMediaType())
        val request = Request.Builder()
            .url("${BuildConfig.API_BASE}/v1/drivers/location")
            .post(body)
            .build()
        http.newCall(request).execute().close()
    }
}
