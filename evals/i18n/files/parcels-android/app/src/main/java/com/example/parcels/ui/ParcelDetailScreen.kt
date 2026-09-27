package com.example.parcels.ui

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
import com.example.parcels.Parcel
import com.example.parcels.R
import com.example.parcels.util.Format

@Composable
fun ParcelDetailScreen(parcel: Parcel, onBack: () -> Unit) {
    Column(Modifier.padding(16.dp)) {
        IconButton(onClick = onBack) {
            Icon(Icons.Filled.ArrowBack, contentDescription = "Back")
        }
        Text(stringResource(R.string.parcel_detail_title, parcel.trackingId))
        Text(stringResource(R.string.parcel_status_label) + ": " + statusText(parcel.status))
        parcel.etaMinutes?.let {
            Text(stringResource(R.string.parcel_detail_eta, it))
        }
        parcel.deliveredAt?.let {
            Text(stringResource(R.string.parcel_delivered_at, Format.dateTime(it)))
        }
        Text(stringResource(R.string.parcel_detail_fee) + " " + Format.fee(parcel.feeMinor, parcel.currency))
    }
}
