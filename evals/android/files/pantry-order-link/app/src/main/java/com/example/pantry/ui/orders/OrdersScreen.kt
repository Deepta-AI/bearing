package com.example.pantry.ui.orders

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.example.pantry.R

@Composable
fun OrdersRoute(onSignedOut: () -> Unit, viewModel: OrdersViewModel = hiltViewModel()) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    OrdersScreen(state = state, onRetry = viewModel::refresh, onLogout = { viewModel.logout(onSignedOut) })
}

@Composable
fun OrdersScreen(state: OrdersUiState, onRetry: () -> Unit, onLogout: () -> Unit, modifier: Modifier = Modifier) {
    Column(modifier.fillMaxSize().safeDrawingPadding().padding(16.dp)) {
        Text(stringResource(R.string.orders_title), style = MaterialTheme.typography.headlineMedium)
        TextButton(onClick = onLogout) { Text(stringResource(R.string.logout)) }
        when (state) {
            OrdersUiState.Loading -> CircularProgressIndicator()
            is OrdersUiState.Ready -> {
                if (state.refreshFailed) {
                    TextButton(onClick = onRetry) { Text(stringResource(R.string.orders_error)) }
                }
                if (state.orders.isEmpty()) Text(stringResource(R.string.orders_empty))
                LazyColumn {
                    items(state.orders, key = { it.id }) { order ->
                        ListItem(
                            headlineContent = { Text(order.placedAt) },
                            supportingContent = {
                                Text(stringResource(R.string.orders_total, "%.2f".format(order.totalPaise / 100.0)))
                            },
                        )
                    }
                }
            }
        }
    }
}
