import Foundation
import Networking

/// Loads the signed-in customer's orders.
public protocol OrdersService: Sendable {
    func orders() async throws -> [Order]
}

public struct RemoteOrdersService: OrdersService {
    private let client: APIClientProtocol

    public init(client: APIClientProtocol) { self.client = client }

    public func orders() async throws -> [Order] {
        try await client.send(.orders)
    }
}
