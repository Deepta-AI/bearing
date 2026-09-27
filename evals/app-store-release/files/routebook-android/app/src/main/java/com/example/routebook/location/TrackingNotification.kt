package com.example.routebook.location

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import com.example.routebook.R

object TrackingNotification {
    private const val CHANNEL = "route_tracking"

    fun build(context: Context): Notification {
        val nm = context.getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(NotificationChannel(CHANNEL, "Route tracking", NotificationManager.IMPORTANCE_LOW))
        return Notification.Builder(context, CHANNEL)
            .setContentTitle(context.getString(R.string.tracking_notification))
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setOngoing(true)
            .build()
    }
}
