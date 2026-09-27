package com.example.routebook.location

import android.app.Service
import android.content.Intent
import android.os.IBinder
import android.os.Looper
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority

/** Runs only while a route is active; the driver sees a notification the whole time. */
class RouteTrackingService : Service() {

    private val client by lazy { LocationServices.getFusedLocationProviderClient(this) }
    private val uploader by lazy { LocationUploader(this) }

    private val callback = object : LocationCallback() {
        override fun onLocationResult(result: LocationResult) {
            result.lastLocation?.let { uploader.send(it.latitude, it.longitude, it.time) }
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForeground(1, TrackingNotification.build(this))
        val request = LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, 60_000L).build()
        client.requestLocationUpdates(request, callback, Looper.getMainLooper())
        return START_STICKY
    }

    override fun onDestroy() {
        client.removeLocationUpdates(callback)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
