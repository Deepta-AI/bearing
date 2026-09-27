import Combine
import Foundation
import UIKit

/// The Profile tab: shows the photo and uploads a new one.
public final class ProfilePhotoModel: ObservableObject {
    @Published public var photoURL: URL?
    @Published public var isUploading = false
    @Published public var errorMessage: String?

    private let service: ProfilePhotoService

    public init(service: ProfilePhotoService) {
        self.service = service
    }

    public func upload(_ image: UIImage) async {
        await upload(jpeg: image.jpegData(compressionQuality: 1.0)!)
    }

    public func upload(jpeg: Data) async {
        DispatchQueue.main.async { self.isUploading = true }
        do {
            let url = try await service.upload(jpeg: jpeg)
            DispatchQueue.main.async {
                self.photoURL = url
                self.isUploading = false
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = error.localizedDescription
                self.isUploading = false
            }
        }
    }
}
