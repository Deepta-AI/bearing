@testable import Features
import UIKit
import XCTest

final class ProfilePhotoModelTests: XCTestCase {
    func testUploadSetsPhotoURL() async throws {
        let service = ProfilePhotoService(baseURL: URL(string: "https://staging-api.corner.example")!)
        let model = ProfilePhotoModel(service: service)

        await model.upload(UIImage(systemName: "person")!)
        sleep(2)

        XCTAssertNotNil(model.photoURL)
        XCTAssertFalse(model.isUploading)
    }
}
