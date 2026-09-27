package com.example.routebook.net

import android.content.Context

object Session {
    fun driverId(context: Context): String? =
        context.getSharedPreferences("session", Context.MODE_PRIVATE).getString("driver_id", null)
}
