import Foundation

#if os(iOS)
import AVFoundation
import UIKit
import VisionKit
#endif

enum CaptureAvailability {
    static var showsDocumentScanner: Bool {
        #if os(iOS)
        true
        #else
        false
        #endif
    }

    static var documentScannerSupported: Bool {
        #if os(iOS)
        VNDocumentCameraViewController.isSupported
        #else
        false
        #endif
    }

    static var showsCamera: Bool {
        #if os(iOS)
        true
        #else
        false
        #endif
    }

    static var cameraAvailable: Bool {
        #if os(iOS)
        UIImagePickerController.isSourceTypeAvailable(.camera)
        #else
        false
        #endif
    }

    static var platformHint: String? {
        #if os(macOS)
        "请从相册或文件选入。用 iPhone 扫描后，图片会出现在相册里。"
        #elseif os(iOS)
        nil
        #else
        "请从相册或文件选入。"
        #endif
    }

    static func openSystemSettings() {
        #if os(iOS)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
        #endif
    }

    #if os(iOS)
    static func authorizeCamera() async -> CameraAuthorization {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return .authorized
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            return granted ? .authorized : .denied
        case .denied, .restricted:
            return .denied
        @unknown default:
            return .denied
        }
    }
    #endif
}

enum CameraAuthorization {
    case authorized
    case denied
}
