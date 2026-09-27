import Core
@testable import Features
import Foundation
import Testing

private struct FakeOrdersService: OrdersService {
    let result: Result<[Order], AppError>
    func orders() async throws -> [Order] { try result.get() }
}

@MainActor
struct OrdersViewModelTests {
    private let order = Order(id: 1, placedAt: Date(timeIntervalSince1970: 0), totalPaise: 125_099, status: .placed)

    @Test func loadedWhenThereAreOrders() async {
        let model = OrdersViewModel(service: FakeOrdersService(result: .success([order])))
        await model.load()
        #expect(model.state == .loaded([order]))
    }

    @Test func emptyWhenThereAreNone() async {
        let model = OrdersViewModel(service: FakeOrdersService(result: .success([])))
        await model.load()
        #expect(model.state == .empty)
    }

    @Test func failedKeepsTheError() async {
        let model = OrdersViewModel(service: FakeOrdersService(result: .failure(.offline)))
        await model.load()
        #expect(model.state == .failed(.offline))
    }

    @Test func unknownStatusDecodes() throws {
        let json = Data(#"{"id": 2, "placed_at": "2026-09-20T08:14:00Z", "total_paise": 10, "status": "lost"}"#.utf8)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        #expect(try decoder.decode(Order.self, from: json).status == .unknown)
    }
}
