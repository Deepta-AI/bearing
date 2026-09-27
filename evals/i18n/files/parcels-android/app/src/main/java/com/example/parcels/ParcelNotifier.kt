package com.example.parcels

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat

class ParcelNotifier(private val context: Context) {
    private val channelId = "parcel_updates"

    fun notify(parcel: Parcel) {
        val nm = context.getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(
            NotificationChannel(
                channelId,
                context.getString(R.string.notification_channel_name),
                NotificationManager.IMPORTANCE_DEFAULT,
            ),
        )
        val views = RemoteViews(context.packageName, R.layout.notification_parcel)
        views.setTextViewText(
            R.id.notification_title,
            "Parcel " + parcel.trackingId + " is " + parcel.status.name.lowercase().replace('_', ' '),
        )
        val n = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setCustomContentView(views)
            .build()
        nm.notify(parcel.trackingId.hashCode(), n)
    }
}
