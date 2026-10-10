import SwiftUI
import UIKit

// Wraps UIKit's camera screen so SwiftUI can show it.
struct CameraPicker: UIViewControllerRepresentable {
    let onPhoto: (Data) -> Void

    @Environment(\.dismiss) private var dismiss

    // Creates the camera screen with Apple's default controls.
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    // Nothing to update.
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    // Creates the delegate that receives the photo.
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    // Receives the camera's callbacks.
    @MainActor
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let parent: CameraPicker

        init(parent: CameraPicker) {
            self.parent = parent
        }

        // Called with the taken photo: sends it as JPEG and closes the camera.
        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage, let data = image.jpegData(compressionQuality: 0.9) {
                parent.onPhoto(data)
            }
            parent.dismiss()
        }

        // Called when the user cancels: closes the camera.
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
