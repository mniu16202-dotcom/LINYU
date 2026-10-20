import AVFoundation
import LinYuCore
import SwiftUI
import UIKit

/// 相机扫码。
///
/// 用 AVFoundation 自己实现，而不是 `DataScannerViewController`：后者要求 A12+ 且
/// 界面由系统接管，做不出安卓那套"纯黑遮罩 + 白框 + 手电筒"的样子。
final class CameraScanner: NSObject, ObservableObject {

    @Published private(set) var permissionDenied = false
    @Published private(set) var isTorchAvailable = false
    @Published private(set) var isTorchOn = false

    let session = AVCaptureSession()

    /// 解出一个合法设备码时回调（主线程）
    var onCode: ((String) -> Void)?

    private let queue = DispatchQueue(label: "com.hualala.linyu.camera")
    private var isConfigured = false
    private var lastCode: String?

    // MARK: - 生命周期

    func start() {
        lastCode = nil
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            beginSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard let self else { return }
                if granted {
                    self.beginSession()
                } else {
                    DispatchQueue.main.async { self.permissionDenied = true }
                }
            }
        default:
            permissionDenied = true
        }
    }

    func stop() {
        if isTorchOn { setTorch(false) }
        queue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning { self.session.stopRunning() }
        }
    }

    func setTorch(_ on: Bool) {
        guard let device = videoDevice(),
              device.hasTorch,
              device.isTorchModeSupported(on ? .on : .off) else { return }
        do {
            try device.lockForConfiguration()
            device.torchMode = on ? .on : .off
            device.unlockForConfiguration()
            isTorchOn = on
        } catch {
            isTorchOn = false
        }
    }

    // MARK: - 配置

    private func beginSession() {
        queue.async { [weak self] in
            guard let self else { return }
            self.configureIfNeeded()
            if !self.session.isRunning { self.session.startRunning() }
            let torchAvailable = self.videoDevice()?.hasTorch ?? false
            DispatchQueue.main.async {
                self.permissionDenied = false
                self.isTorchAvailable = torchAvailable
            }
        }
    }

    private func configureIfNeeded() {
        guard !isConfigured else { return }
        isConfigured = true

        session.beginConfiguration()
        defer { session.commitConfiguration() }

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]
    }

    private func videoDevice() -> AVCaptureDevice? {
        session.inputs.compactMap { ($0 as? AVCaptureDeviceInput)?.device }.first
    }
}

extension CameraScanner: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let object = metadataObjects.compactMap({ $0 as? AVMetadataMachineReadableCodeObject }).first,
              let raw = object.stringValue,
              let code = QRPayload.deviceCode(from: raw) else { return }
        // 同一张码连续出帧时只回调一次
        guard code != lastCode else { return }
        lastCode = code
        onCode?(code)
    }
}

/// 相机预览层
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewContainer {
        let container = PreviewContainer()
        container.previewLayer.session = session
        container.previewLayer.videoGravity = .resizeAspectFill
        return container
    }

    func updateUIView(_ uiView: PreviewContainer, context: Context) {
        if uiView.previewLayer.session !== session {
            uiView.previewLayer.session = session
        }
    }
}

final class PreviewContainer: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    var previewLayer: AVCaptureVideoPreviewLayer {
        // layerClass 已固定为 AVCaptureVideoPreviewLayer
        layer as! AVCaptureVideoPreviewLayer
    }
}
