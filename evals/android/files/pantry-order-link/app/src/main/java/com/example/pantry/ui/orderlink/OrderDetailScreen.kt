package com.example.pantry.ui.orderlink

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

@Composable
fun OrderDetailScreen(viewModel: OrderDetailViewModel, modifier: Modifier = Modifier) {
    val order by viewModel.order.collectAsState()
    Column(modifier.fillMaxSize().padding(16.dp)) {
        val current = order
        if (current == null) {
            CircularProgressIndicator()
        } else {
            Text("Order #${current.id}", style = MaterialTheme.typography.headlineMedium)
            Text(current.status)
            current.lines.forEach { line ->
                Text("${line.quantity} x ${line.name}")
            }
            Text("Total: Rs " + current.totalPaise / 100)
        }
    }
}
