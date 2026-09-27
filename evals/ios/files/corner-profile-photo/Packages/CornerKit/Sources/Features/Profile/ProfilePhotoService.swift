import Core
import Foundation
import UIKit

private struct PhotoResponse: Decodable {
    let photoURL: String

    enum CodingKeys: String, CodingKey {
        case photoURL = "photo_url"
    }
}

/// Uploads the customer's profile photo.
public final class ProfilePhotoService: Sendable {
    private let baseURL: URL

    public init(baseURL: URL) {
        self.baseURL = baseURL
    }

    /// The largest photo part the server accepts (docs/api.md).
    public static let maxBytes = 2_097_152

    public func upload(jpeg: Data) async throws -> URL {
        let boundary = UUID().uuidString

        var request = URLRequest(url: baseURL.appendingPathComponent("/v1/me/photo"))
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        let token = UserDefaults.standard.string(forKey: "access_token") ?? ""
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = Self.multipart(jpeg, boundary: boundary)

        Log.request("photo upload headers=\(request.allHTTPHeaderFields ?? [:]) bytes=\(jpeg.count)")
        let (data, _) = try await URLSession.shared.data(for: request)
        let body = try JSONDecoder().decode(PhotoResponse.self, from: data)
        return URL(string: body.photoURL)!
    }

    static func multipart(_ jpeg: Data, boundary: String) -> Data {
        var body = Data()
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"photo\"; filename=\"photo.jpg\"\r\n".utf8))
        body.append(Data("Content-Type: image/jpeg\r\n\r\n".utf8))
        body.append(jpeg)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        return body
    }
}
