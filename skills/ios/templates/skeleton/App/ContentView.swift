import Core
import Features
import SwiftUI

/// Root screen: shows whether the API is reachable. Small on purpose; it is
/// the pattern every screen follows, not a feature.
struct ContentView: View {
    @State private var model: HealthViewModel

    /// State flows down: the screen receives its dependencies and owns its
    /// view model. `@State` holds an `@Observable` reference for the view's
    /// lifetime; SwiftUI re-renders only for the properties `body` reads.
    init(container: AppContainer) {
        _model = State(initialValue: HealthViewModel(service: container.healthService, clock: container.clock))
    }

    var body: some View {
        NavigationStack {
            HealthView(model: model)
                .navigationTitle(Text("health.title"))
        }
    }
}

/// Renders all four states. A screen that only renders `loaded` is a review
/// finding. Events flow up: taps call the model; the model never touches a view.
struct HealthView: View {
    let model: HealthViewModel

    var body: some View {
        Group {
            switch model.state {
            case .idle, .loading:
                ProgressView(Text("health.loading"))
                    .accessibilityIdentifier("health.loading")
            case let .loaded(health):
                loaded(health)
            case let .failed(error):
                failed(error)
            }
        }
        // Structured: leaving the screen cancels the request.
        .task { await model.refresh() }
        .refreshable { await model.refresh() }
    }

    private func loaded(_ health: Health) -> some View {
        VStack(spacing: 12) {
            Image(systemName: health.isHealthy ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(health.isHealthy ? .green : .orange)
                .accessibilityHidden(true)
            Text(health.isHealthy ? "health.ok" : "health.degraded")
                .font(.title2.weight(.semibold))
            Text("health.version \(health.version)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let checked = model.lastCheckedAt {
                Text("health.checked \(checked, style: .time)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .multilineTextAlignment(.center)
        .padding()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("health.loaded")
    }

    private func failed(_ error: AppError) -> some View {
        ContentUnavailableView {
            Label(Text("health.failed"), systemImage: "wifi.exclamationmark")
        } description: {
            Text(LocalizedStringKey(error.messageKey))
        } actions: {
            if model.canRetry {
                Button {
                    Task { await model.refresh() }
                } label: {
                    Text("action.retry")
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("health.retry")
            }
        }
        .accessibilityIdentifier("health.failed")
    }
}

#Preview("Loaded") {
    ContentView(container: .preview())
}

#Preview("Offline") {
    ContentView(container: .preview(health: .failure(AppError.offline)))
}
