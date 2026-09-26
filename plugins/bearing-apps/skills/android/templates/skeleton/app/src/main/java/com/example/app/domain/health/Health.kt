package com.example.app.domain.health

/** What the API reports about itself. A domain type: no serialisation, no Android imports. */
data class Health(
    val status: String,
    val version: String,
)
