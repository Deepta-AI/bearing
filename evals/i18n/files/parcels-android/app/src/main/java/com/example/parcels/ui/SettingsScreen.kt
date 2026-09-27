package com.example.parcels.ui

import androidx.appcompat.app.AppCompatDelegate
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.core.os.LocaleListCompat
import com.example.parcels.R

// Labels are each language's own name, so a user can find theirs.
private val languages = listOf(
    "English" to "en",
    "हिन्दी" to "hi",
)

@Composable
fun SettingsScreen(onBack: () -> Unit) {
    Column(Modifier.padding(16.dp)) {
        IconButton(onClick = onBack) {
            Icon(Icons.Filled.ArrowBack, contentDescription = "Back")
        }
        Text(stringResource(R.string.settings_title))
        Text(stringResource(R.string.settings_language))
        languages.forEach { (label, tag) ->
            Text(
                label,
                Modifier
                    .clickable {
                        AppCompatDelegate.setApplicationLocales(LocaleListCompat.forLanguageTags(tag))
                    }
                    .padding(vertical = 12.dp),
            )
        }
        Text(stringResource(R.string.settings_contact_support) + ": " + stringResource(R.string.support_email))
    }
}
