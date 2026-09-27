import Core
import Features
import SwiftUI

struct OrdersView: View {
    @State private var model: OrdersViewModel

    init(model: OrdersViewModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("orders.title")
        }
        .task { await model.load() }
    }

    @ViewBuilder private var content: some View {
        switch model.state {
        case .idle, .loading:
            ProgressView()
                .accessibilityLabel("orders.loading")
        case let .loaded(orders):
            List(orders) { order in
                OrderRow(order: order)
            }
        case .empty:
            ContentUnavailableView("orders.empty.title", systemImage: "bag",
                                   description: Text("orders.empty.body"))
        case let .failed(error):
            ContentUnavailableView {
                Label(LocalizedStringKey(error.messageKey), systemImage: "exclamationmark.triangle")
            } actions: {
                if error.isRetryable {
                    Button("common.retry") { Task { await model.load() } }
                }
            }
        }
    }
}

private struct OrderRow: View {
    let order: Order

    var body: some View {
        VStack(alignment: .leading) {
            Text("orders.row.number \(order.id)")
                .font(.headline)
            Text(Decimal(order.totalPaise) / 100, format: .currency(code: "INR"))
                .font(.body)
        }
        .accessibilityElement(children: .combine)
    }
}
