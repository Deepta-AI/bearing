package com.example.app.data.health

import com.example.app.domain.health.HealthRepository
import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent

/** Binds the health repository interface to its implementation. */
@Module
@InstallIn(SingletonComponent::class)
interface HealthDataModule {
    @Binds
    fun bindHealthRepository(impl: HealthRepositoryImpl): HealthRepository
}
