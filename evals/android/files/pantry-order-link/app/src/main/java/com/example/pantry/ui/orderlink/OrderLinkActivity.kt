package com.example.pantry.ui.orderlink

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.viewModels
import androidx.compose.material3.MaterialTheme
import dagger.hilt.android.AndroidEntryPoint

/** Opens one order from a link in an order email. */
@AndroidEntryPoint
class OrderLinkActivity : ComponentActivity() {
    private val viewModel: OrderDetailViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val orderId = intent.data?.lastPathSegment
        viewModel.load(orderId!!)
        setContent {
            MaterialTheme {
                OrderDetailScreen(viewModel)
            }
        }
    }
}
