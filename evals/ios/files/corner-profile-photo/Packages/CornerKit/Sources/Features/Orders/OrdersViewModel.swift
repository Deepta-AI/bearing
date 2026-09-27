import Core
import Foundation
import Observation

/// The Orders tab.
@Observable @MainActor
public final class OrdersViewModel {
    public enum State: Equatable {
        case idle
        case loading
        case loaded([Order])
        case empty
        case failed(AppError)
    }

    public private(set) var state: State = .idle
    private let service: OrdersService

    public init(service: OrdersService) { self.service = service }

    public func load() async {
        state = .loading
        do {
            let orders = try await service.orders()
            state = orders.isEmpty ? .empty : .loaded(orders)
        } catch AppError.cancelled {
            return
        } catch let error as AppError {
            state = .failed(error)
        } catch {
            state = .failed(.unknown)
        }
    }
}
