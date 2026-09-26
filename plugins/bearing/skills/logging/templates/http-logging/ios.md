# HTTP logging interceptor: iOS (URLSession, os.Logger)

File: `Packages/<Name>Kit/Sources/Networking/HTTPLogging.swift`. The
client in `Networking` has one `send(_:)`; the logging wraps it there.
No `URLProtocol` subclass: it cannot see the decoded route and it is
skipped by background sessions.

## Configuration

```swift
public struct HTTPLogConfig: Sendable {
    public var enabled: Bool
    public var bodies: Bool
    public var maxBytes: Int
    public var sample: Double

    public static func fromDefaults(_ d: UserDefaults = .standard, isDebug: Bool) -> HTTPLogConfig {
        HTTPLogConfig(
            enabled: d.object(forKey: "LOG_HTTP") as? Bool ?? isDebug,
            bodies: d.bool(forKey: "LOG_HTTP_BODIES"),
            maxBytes: d.object(forKey: "LOG_HTTP_MAX_BYTES") as? Int ?? 2048,
            sample: d.object(forKey: "LOG_HTTP_SAMPLE") as? Double ?? 1.0)
    }
}
```

## Interceptor

```swift
private let log = Logger(subsystem: subsystem, category: "http")
private let redacted: Set<String> = ["authorization", "cookie", "x-api-key"]

func loggedSend(_ request: URLRequest, config: HTTPLogConfig, session: URLSession) async throws -> (Data, HTTPURLResponse) {
    guard config.enabled, Double.random(in: 0...1) <= config.sample else { return try await send(request, session: session) }
    let route = request.url?.path ?? ""
    let method = request.httpMethod ?? "GET"
    let start = ContinuousClock.now
    log.debug("http request method=\(method, privacy: .public) route=\(route, privacy: .public) headers=\(safe(request.allHTTPHeaderFields), privacy: .private) body=\(config.bodies ? redact(request.httpBody, max: config.maxBytes) : "", privacy: .private)")
    let (data, response) = try await send(request, session: session)
    let ms = (ContinuousClock.now - start).milliseconds
    let requestId = response.value(forHTTPHeaderField: "X-Request-Id") ?? ""
    log.info("http response method=\(method, privacy: .public) route=\(route, privacy: .public) status=\(response.statusCode) duration_ms=\(ms) outcome=\(outcome(response.statusCode), privacy: .public) request_id=\(requestId, privacy: .public) body=\(config.bodies ? redact(data, max: config.maxBytes) : "", privacy: .private)")
    return (data, response)
}
```

`safe(_:)` replaces the redacted header names with `[redacted]`.
`redact(_:max:)` parses JSON when it can, replaces deny-list keys, and
truncates at `max` bytes. Headers and bodies are `.private` so they
never appear in a sysdiagnose from a release device; route, status and
ids are `.public`.

## Flipping it at runtime

- Launch argument in a scheme or on a test device: `-LOG_HTTP YES
  -LOG_HTTP_BODIES YES`. `UserDefaults` reads arguments first.
- Debug menu (debug builds only, `App/Debug/`): toggles that write the
  same `UserDefaults` keys; the client re-reads the config per request.
- Remote config, when present: `log_http` applied to the same keys.
- Read the output with `log stream --predicate 'category == "http"'` or
  Console.app. Release builds keep debug lines only while streaming.

## Test

`swift test` with a `URLProtocol` stub for the session and a `LogSpy`
behind the `Logger` wrapper: off records nothing, on records two
entries, bodies on redacts `password` and stops at `maxBytes`.
