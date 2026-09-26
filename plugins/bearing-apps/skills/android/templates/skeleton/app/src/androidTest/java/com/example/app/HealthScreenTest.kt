// Instrumented tests are JUnit 4: the AndroidX runner and createComposeRule are
// JUnit 4 rules. Unit tests under src/test are JUnit Jupiter.
package com.example.app

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.example.app.ui.health.HealthScreen
import com.example.app.ui.health.HealthTags
import com.example.app.ui.health.HealthUiState
import com.example.app.ui.theme.AppTheme
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class HealthScreenTest {
    @get:Rule
    val composeRule = createComposeRule()

    private val context = InstrumentationRegistry.getInstrumentation().targetContext

    @Test
    fun readyStateShowsStatusAndVersion() {
        composeRule.setContent {
            AppTheme {
                HealthScreen(state = HealthUiState.Ready(status = "ok", version = "1.2.3"), onRefresh = {})
            }
        }

        composeRule.onNodeWithTag(HealthTags.READY).assertIsDisplayed()
        composeRule.onNodeWithText(context.getString(R.string.health_ready, "ok", "1.2.3")).assertIsDisplayed()
    }

    @Test
    fun errorStateShowsTheMessage() {
        composeRule.setContent {
            AppTheme {
                HealthScreen(state = HealthUiState.Error(message = "offline"), onRefresh = {})
            }
        }

        composeRule.onNodeWithTag(HealthTags.ERROR).assertIsDisplayed()
    }

    @Test
    fun refreshButtonCallsBack() {
        var calls = 0
        composeRule.setContent {
            AppTheme {
                HealthScreen(state = HealthUiState.Loading, onRefresh = { calls++ })
            }
        }

        composeRule.onNodeWithTag(HealthTags.REFRESH).performClick()
        assertEquals(1, calls)
    }
}
