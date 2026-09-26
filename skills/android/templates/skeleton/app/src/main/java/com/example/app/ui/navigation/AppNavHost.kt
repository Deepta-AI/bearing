package com.example.app.ui.navigation

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.example.app.ui.health.HealthRoute
import kotlinx.serialization.Serializable

/** Type-safe destinations. One object or data class per screen; arguments are constructor fields. */
@Serializable
data object HealthDestination

/** The navigation graph. Routes get their ViewModel here, screens stay stateless. */
@Composable
fun AppNavHost(
    modifier: Modifier = Modifier,
    navController: NavHostController = rememberNavController(),
) {
    NavHost(navController = navController, startDestination = HealthDestination, modifier = modifier) {
        composable<HealthDestination> { HealthRoute() }
    }
}
