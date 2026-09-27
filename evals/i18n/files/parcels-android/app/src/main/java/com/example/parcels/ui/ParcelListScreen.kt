package com.example.parcels.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.absolutePadding
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.example.parcels.Parcel
import com.example.parcels.ParcelStatus
import com.example.parcels.R

@Composable
fun ParcelListScreen(parcels: List<Parcel>, onOpen: (Parcel) -> Unit, onSettings: () -> Unit) {
    val inTransit = parcels.count { it.status != ParcelStatus.DELIVERED }
    Column {
        Row(Modifier.fillMaxWidth().padding(16.dp)) {
            Text(stringResource(R.string.parcel_list_title), Modifier.weight(1f))
            IconButton(onClick = {}) {
                Icon(Icons.Filled.Refresh, contentDescription = stringResource(R.string.parcel_list_refresh))
            }
            IconButton(onClick = onSettings) {
                Icon(Icons.Filled.Settings, contentDescription = "Settings")
            }
        }
        Text(
            if (inTransit == 1) "1 parcel on its way" else "$inTransit parcels on their way",
            Modifier.absolutePadding(left = 16.dp),
        )
        if (parcels.isEmpty()) {
            Text("No parcels yet", Modifier.padding(16.dp))
        }
        LazyColumn {
            items(parcels) { parcel ->
                Row(
                    Modifier
                        .fillMaxWidth()
                        .clickable { onOpen(parcel) }
                        .padding(start = 16.dp, end = 16.dp, top = 8.dp, bottom = 8.dp),
                ) {
                    Text(parcel.trackingId, Modifier.weight(1f))
                    Text(statusText(parcel.status))
                }
            }
        }
    }
}

@Composable
fun statusText(status: ParcelStatus): String = when (status) {
    ParcelStatus.IN_TRANSIT -> stringResource(R.string.parcel_status_in_transit)
    ParcelStatus.OUT_FOR_DELIVERY -> stringResource(R.string.parcel_status_out_for_delivery)
    ParcelStatus.DELIVERED -> stringResource(R.string.parcel_status_delivered)
}
