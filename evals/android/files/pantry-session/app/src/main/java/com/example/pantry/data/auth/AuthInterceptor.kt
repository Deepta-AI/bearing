package com.example.pantry.data.auth

import javax.inject.Inject
import javax.inject.Singleton
import okhttp3.Interceptor
import okhttp3.Response

/** Adds the bearer token to every request when a user is signed in. */
@Singleton
class AuthInterceptor @Inject constructor(
    private val holder: SessionHolder,
) : Interceptor {
    override fun intercept(chain: Interceptor.Chain): Response {
        val token = holder.session.value?.accessToken
        val request = if (token == null) {
            chain.request()
        } else {
            chain.request().newBuilder().header("Authorization", "Bearer $token").build()
        }
        return chain.proceed(request)
    }
}
