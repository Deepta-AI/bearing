package com.example.routebook

import android.app.Activity
import android.os.Bundle
import com.example.routebook.nav.NavigationLauncher

class MainActivity : Activity() {
    private val launcher by lazy { NavigationLauncher(this) }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Route list UI elided; tapping a stop calls launcher.navigateTo(lat, lng).
    }
}
