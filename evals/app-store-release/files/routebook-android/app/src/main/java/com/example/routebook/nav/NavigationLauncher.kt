package com.example.routebook.nav

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri

/** Hands a stop off to the driver's preferred navigation app. */
class NavigationLauncher(private val context: Context) {

    private val preferred = listOf(
        "com.google.android.apps.maps",
        "com.waze",
        "com.here.app.maps",
    )

    fun installedNavigationApps(): List<String> {
        val installed = context.packageManager
            .getInstalledApplications(PackageManager.GET_META_DATA)
            .map { it.packageName }
            .toSet()
        return preferred.filter { it in installed }
    }

    fun navigateTo(lat: Double, lng: Double) {
        val uri = Uri.parse("google.navigation:q=$lat,$lng")
        val target = installedNavigationApps().firstOrNull()
        val intent = Intent(Intent.ACTION_VIEW, uri).apply {
            if (target != null) setPackage(target)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        context.startActivity(intent)
    }
}
