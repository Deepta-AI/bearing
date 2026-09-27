package com.example.pantry.data.orders

import android.content.Context
import androidx.room.Dao
import androidx.room.Database
import androidx.room.Entity
import androidx.room.Insert
import androidx.room.PrimaryKey
import androidx.room.Query
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.room.Transaction
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton
import kotlinx.coroutines.flow.Flow

@Entity(tableName = "orders")
data class OrderEntity(
    @PrimaryKey val id: Long,
    val placedAt: String,
    val totalPaise: Long,
    val status: String,
)

@Dao
interface OrderDao {
    @Query("SELECT * FROM orders ORDER BY placedAt DESC")
    fun observeAll(): Flow<List<OrderEntity>>

    @Insert
    suspend fun insertAll(orders: List<OrderEntity>)

    @Query("DELETE FROM orders")
    suspend fun deleteAll()

    @Transaction
    suspend fun replaceAll(orders: List<OrderEntity>) {
        deleteAll()
        insertAll(orders)
    }
}

@Database(entities = [OrderEntity::class], version = 1, exportSchema = false)
abstract class PantryDatabase : RoomDatabase() {
    abstract fun orderDao(): OrderDao
}

@Module
@InstallIn(SingletonComponent::class)
object DatabaseModule {
    @Provides
    @Singleton
    fun provideDatabase(@ApplicationContext context: Context): PantryDatabase =
        Room.databaseBuilder(context, PantryDatabase::class.java, "pantry.db").build()

    @Provides
    fun provideOrderDao(db: PantryDatabase): OrderDao = db.orderDao()
}
