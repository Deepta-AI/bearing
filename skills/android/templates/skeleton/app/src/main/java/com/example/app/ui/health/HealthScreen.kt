package com.example.app.ui.health

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.example.app.R
import com.example.app.ui.theme.AppTheme

/** Test tags for the health screen; shared with androidTest. */
object HealthTags {
    const val READY = "health_ready"
    const val ERROR = "health_error"
    const val REFRESH = "health_refresh"
}

/** Gets the ViewModel, collects state with the lifecycle, hands callbacks down. Nothing else. */
@Composable
fun HealthRoute(viewModel: HealthViewModel = hiltViewModel()) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    HealthScreen(state = state, onRefresh = viewModel::refresh)
}

/** Stateless and previewable. Every string comes from resources, every colour from the theme. */
@Composable
fun HealthScreen(
    state: HealthUiState,
    onRefresh: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val loadingLabel = stringResource(R.string.health_loading)
    Scaffold(modifier = modifier) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(text = stringResource(R.string.health_title), style = MaterialTheme.typography.headlineSmall)
            when (state) {
                HealthUiState.Loading -> CircularProgressIndicator(
                    modifier = Modifier.semantics { contentDescription = loadingLabel },
                )
                is HealthUiState.Ready -> Text(
                    text = stringResource(R.string.health_ready, state.status, state.version),
                    modifier = Modifier.testTag(HealthTags.READY),
                )
                is HealthUiState.Error -> Text(
                    text = stringResource(R.string.health_error, state.message),
                    color = MaterialTheme.colorScheme.error,
                    modifier = Modifier.testTag(HealthTags.ERROR),
                )
            }
            Button(onClick = onRefresh, modifier = Modifier.testTag(HealthTags.REFRESH)) {
                Text(text = stringResource(R.string.health_refresh))
            }
        }
    }
}

@Preview(showBackground = true)
@Composable
private fun HealthScreenReadyPreview() {
    AppTheme {
        HealthScreen(state = HealthUiState.Ready(status = "ok", version = "0.1.0"), onRefresh = {})
    }
}

@Preview(showBackground = true)
@Composable
private fun HealthScreenErrorPreview() {
    AppTheme {
        HealthScreen(state = HealthUiState.Error(message = "timeout"), onRefresh = {})
    }
}
