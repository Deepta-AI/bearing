package com.example.parcels

import android.os.Bundle
import androidx.activity.compose.setContent
import androidx.appcompat.app.AppCompatActivity
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import com.example.parcels.ui.ParcelDetailScreen
import com.example.parcels.ui.ParcelListScreen
import com.example.parcels.ui.SettingsScreen

class MainActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MaterialTheme {
                var screen by remember { mutableStateOf<Screen>(Screen.List) }
                when (val s = screen) {
                    Screen.List -> ParcelListScreen(
                        parcels = Parcels.sample,
                        onOpen = { screen = Screen.Detail(it) },
                        onSettings = { screen = Screen.Settings },
                    )
                    is Screen.Detail -> ParcelDetailScreen(s.parcel, onBack = { screen = Screen.List })
                    Screen.Settings -> SettingsScreen(onBack = { screen = Screen.List })
                }
            }
        }
    }
}

sealed interface Screen {
    data object List : Screen
    data class Detail(val parcel: Parcel) : Screen
    data object Settings : Screen
}
