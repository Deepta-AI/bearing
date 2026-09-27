import Features
import PhotosUI
import SwiftUI

struct ProfileView: View {
    @StateObject private var model: ProfilePhotoModel
    @State private var showCamera = false
    @State private var pickerItem: PhotosPickerItem?

    init(model: ProfilePhotoModel) {
        _model = StateObject(wrappedValue: model)
    }

    var body: some View {
        VStack(spacing: 16) {
            AsyncImage(url: model.photoURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Image(systemName: "person.crop.circle").resizable()
            }
            .frame(width: 120, height: 120)
            .clipShape(Circle())

            if model.isUploading {
                ProgressView()
            }
            if let message = model.errorMessage {
                Text(message).foregroundStyle(.red)
            }

            Button("Take photo") { showCamera = true }
            PhotosPicker("Choose from library", selection: $pickerItem, matching: .images)
        }
        .padding()
        .sheet(isPresented: $showCamera) {
            CameraPicker { image in
                Task { await model.upload(image) }
            }
        }
        .onChange(of: pickerItem) { _, item in
            Task {
                let data = try! await item?.loadTransferable(type: Data.self)
                // Library photos are already compressed: send the file as it is when it fits.
                if data!.count <= ProfilePhotoService.maxBytes {
                    await model.upload(jpeg: data!)
                } else {
                    await model.upload(UIImage(data: data!)!)
                }
            }
        }
    }
}
