import SwiftUI
import UIKit

/// The system camera, handing back the photo as JPEG data for text recognition.
struct CameraPicker: UIViewControllerRepresentable {
    let onPhoto: (Data) -> Void
    @Environment(\.dismiss) private var dismiss

    static var isAvailable: Bool {
        #if DEBUG
        if DemoCamera.isRequested { return true }
        #endif
        return UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ picker: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage, let data = image.jpegData(compressionQuality: 0.9) {
                parent.onPhoto(data)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#if DEBUG
/// The simulator's stand-in for the camera: with `-demoCamera YES`, "Take photo" is offered and
/// hands back a rendered page of text, so the scan flow runs where there is no camera.
enum DemoCamera {
    static var isRequested: Bool { UserDefaults.standard.bool(forKey: "demoCamera") }

    /// A page of English prose, as a JPEG.
    static func page() -> Data {
        let size = CGSize(width: 1500, height: 2000)
        let text = """
        My uncle was an eccentric man with one obsession: the lighthouse at the end of the pier. \
        He kept meticulous notes on every ship that passed, convinced the light was more than \
        ephemeral beauty. The neighbours found his diligence baffling, yet when the storm came, \
        it was his careful logbook that guided the lost boat home.
        """
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 14
        let image = UIGraphicsImageRenderer(size: size).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            text.draw(in: CGRect(x: 120, y: 200, width: 1260, height: 1600),
                      withAttributes: [.font: UIFont.systemFont(ofSize: 54), .paragraphStyle: style])
        }
        return image.jpegData(compressionQuality: 0.9) ?? Data()
    }
}

/// The stand-in camera's screen: a shutter that "takes" the sample page.
struct DemoCameraView: View {
    let onPhoto: (Data) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 32) {
                Text("Demo camera").foregroundStyle(.white)
                Button("Take photo") {
                    onPhoto(DemoCamera.page())
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                Button("Cancel") { dismiss() }.foregroundStyle(.white)
            }
        }
    }
}
#endif
