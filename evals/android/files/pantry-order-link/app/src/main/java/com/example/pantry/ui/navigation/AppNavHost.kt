package com.example.pantry.ui.navigation

import androidx.compose.runtime.Composable
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.example.pantry.ui.login.LoginRoute
import com.example.pantry.ui.orders.OrdersRoute
import kotlinx.serialization.Serializable

@Serializable
object LoginDestination

@Serializable
object OrdersDestination

@Composable
fun AppNavHost() {
    val nav = rememberNavController()
    NavHost(navController = nav, startDestination = LoginDestination) {
        composable<LoginDestination> {
            LoginRoute(onSignedIn = {
                nav.navigate(OrdersDestination) { popUpTo(LoginDestination) { inclusive = true } }
            })
        }
        composable<OrdersDestination> {
            OrdersRoute(onSignedOut = {
                nav.navigate(LoginDestination) { popUpTo(OrdersDestination) { inclusive = true } }
            })
        }
    }
}
