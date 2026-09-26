# HTTP logging interceptor: Android (OkHttp, Timber)

File: `data/network/HttpLogInterceptor.kt`, added to the `OkHttpClient`
in `di/NetworkModule.kt` after the auth interceptor. Toggles live in a
`HttpLogConfig` backed by DataStore so the debug drawer can flip them.

## Configuration

```kotlin
data class HttpLogConfig(
    val enabled: Boolean = BuildConfig.DEBUG,
    val bodies: Boolean = false,
    val maxBytes: Int = 2048,
    val sample: Double = 1.0,
)

class HttpLogConfigStore @Inject constructor(private val store: DataStore<Preferences>) {
    val config: Flow<HttpLogConfig> = store.data.map { p ->
        HttpLogConfig(
            enabled = p[ENABLED] ?: BuildConfig.DEBUG,
            bodies = p[BODIES] ?: false,
            maxBytes = p[MAX_BYTES] ?: 2048,
            sample = p[SAMPLE] ?: 1.0,
        )
    }
    suspend fun update(block: (HttpLogConfig) -> HttpLogConfig) { /* edit preferences */ }
}
```

## Interceptor

```kotlin
class HttpLogInterceptor @Inject constructor(
    private val configStore: HttpLogConfigStore,
    private val logger: Logger,
) : Interceptor {
    @Volatile private var config = HttpLogConfig()
    init { /* collect configStore.config into config on an app scope */ }

    override fun intercept(chain: Interceptor.Chain): Response {
        val c = config
        if (!c.enabled || Random.nextDouble() > c.sample) return chain.proceed(chain.request())
        val req = chain.request()
        val start = System.nanoTime()
        logger.log(Level.DEBUG, "http request", mapOf(
            "method" to req.method, "url" to req.url.stripQuery(), "headers" to req.headers.safe(),
            "body" to if (c.bodies) req.peekBody(c.maxBytes).redacted() else null))
        val res = chain.proceed(req)
        val ms = (System.nanoTime() - start) / 1_000_000
        logger.log(Level.INFO, "http response", mapOf(
            "method" to req.method, "url" to req.url.stripQuery(), "status" to res.code,
            "duration_ms" to ms, "outcome" to outcome(res.code), "request_id" to res.header("X-Request-Id"),
            "body" to if (c.bodies) res.peekBody(c.maxBytes.toLong()).string().redacted() else null))
        return res
    }
}
```

`Headers.safe()` replaces `Authorization`, `Cookie`, `X-Api-Key` with
`[redacted]`. `String.redacted()` parses JSON when it can and replaces
deny-list keys. `peekBody` never consumes the stream.

## Flipping it at runtime

- Debug drawer (debug builds only, `src/debug/`): three switches bound
  to `HttpLogConfigStore.update`. Not compiled into release.
- Remote config, when present: `log_http` boolean applied through the
  same store, so support can enable logging for one device.
- `adb shell setprop` is not used; the store is the one toggle so the
  behaviour is the same on every build type.

## Test

JUnit with `MockWebServer` and a fake `Logger`: off records nothing, on
records two entries, bodies on redacts `password` and stops at
`maxBytes`.
