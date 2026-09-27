import Foundation
import Networking

/// One order as the list shows it.
public struct Order: Decodable, Equatable, Identifiable, Sendable {
    public enum Status: String, Decodable, Sendable {
        case placed, packed, outForDelivery = "out_for_delivery", delivered, cancelled
        case unknown

        public init(from decoder: Decoder) throws {
            let raw = try decoder.singleValueContainer().decode(String.self)
            self = Status(rawValue: raw) ?? .unknown
        }
    }

    public let id: Int
    public let placedAt: Date
    public let totalPaise: Int
    public let status: Status

    public init(id: Int, placedAt: Date, totalPaise: Int, status: Status) {
        self.id = id
        self.placedAt = placedAt
        self.totalPaise = totalPaise
        self.status = status
    }
}

extension Endpoint where Response == [Order] {
    static var orders: Self { Endpoint(path: "/v1/orders") }
}
