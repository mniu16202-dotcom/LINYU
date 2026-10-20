import LinYuCore
import SwiftUI

/// 扫码流程：扫码页 → 设备详情。用 NavigationStack 内部跳转，
/// 避免"关掉扫码 sheet 再立刻弹另一个 sheet"这种在 SwiftUI 里很容易丢事件的写法。
struct ScannerFlowView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var path: [String] = []

    var body: some View {
        NavigationStack(path: $path) {
            ScanScreen { code in
                path.append(code)
            }
            .navigationTitle("扫码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") { dismiss() }
                }
            }
            .navigationDestination(for: String.self) { code in
                DeviceDetailView(code: code)
            }
        }
    }
}

struct ScanScreen: View {

    let onScanned: (String) -> Void

    @StateObject private var camera = CameraScanner()
    @State private var handled = false
    @State private var manualCode = ""
    @State private var showingManualEntry = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if camera.permissionDenied {
                permissionView
            } else {
                CameraPreview(session: camera.session)
                    .ignoresSafeArea()
                overlay
            }
        }
        .onAppear {
            handled = false
            camera.onCode = { code in
                guard !handled else { return }
                handled = true
                onScanned(code)
            }
            camera.start()
        }
        .onDisappear { camera.stop() }
        .alert("手动输入设备码", isPresented: $showingManualEntry) {
            TextField("12 位设备码", text: $manualCode)
            Button("查询") {
                if let code = MacFormat.normalize(manualCode) {
                    onScanned(code)
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("设备二维码最后一段的 12 位十六进制，例如 00158304D300")
        }
    }

    // MARK: - 叠加层

    private var overlay: some View {
        VStack(spacing: 16) {
            GeometryReader { geo in
                let side = min(geo.size.width, geo.size.height) * 0.62
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.9), lineWidth: 3)
                    .frame(width: side, height: side)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Text("对准设备上的二维码")
                .font(.callout)
                .foregroundStyle(.white)

            HStack(spacing: 16) {
                if camera.isTorchAvailable {
                    Button {
                        camera.setTorch(!camera.isTorchOn)
                    } label: {
                        Label(
                            camera.isTorchOn ? "关手电筒" : "开手电筒",
                            systemImage: camera.isTorchOn ? "bolt.slash.fill" : "bolt.fill"
                        )
                    }
                    .buttonStyle(.bordered)
                }

                Button {
                    showingManualEntry = true
                } label: {
                    Label("手动输入", systemImage: "keyboard")
                }
                .buttonStyle(.bordered)
            }
            .tint(.white)
            .padding(.bottom, 24)
        }
        .padding(.top, 48)
    }

    private var permissionView: some View {
        VStack(spacing: 14) {
            Image(systemName: "camera.fill")
                .font(.largeTitle)
            Text("需要相机权限")
                .font(.headline)
            Text("在「设置 → 隐私与安全性 → 相机」里允许淋浴使用相机即可扫码；\n也可以直接手动输入设备码。")
                .font(.footnote)
                .multilineTextAlignment(.center)
            Button("手动输入设备码") { showingManualEntry = true }
                .buttonStyle(.borderedProminent)
        }
        .foregroundStyle(.white)
        .padding(32)
    }
}
