package com.example.pantry.data.settings

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.longPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import dagger.hilt.android.qualifiers.ApplicationContext
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

private val Context.settings: DataStore<Preferences> by preferencesDataStore(name = "settings")

/** User preferences that are not secret: the chosen store. Backed up on purpose. */
@Singleton
class SettingsStore @Inject constructor(
    @ApplicationContext private val context: Context,
) {
    private val storeIdKey = longPreferencesKey("store_id")

    val storeId: Flow<Long?> = context.settings.data.map { it[storeIdKey] }

    suspend fun setStoreId(id: Long) {
        context.settings.edit { it[storeIdKey] = id }
    }
}
