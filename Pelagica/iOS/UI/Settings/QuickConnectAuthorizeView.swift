//
//  QuickConnectAuthorizeView.swift
//  Pelagica
//

@preconcurrency import AVFoundation
import SwiftUI

struct QuickConnectAuthorizeView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var code = ""
    @State private var isAuthorizing = false
    @State private var status: Status?
    @State private var scans = 0
    @FocusState private var isCodeFocused: Bool

    private enum Status {
        case authorized, failed
    }

    private static let codeLength = 6
    private static let dismissDelay: Duration = .seconds(1.5)

    private var isValidCode: Bool { code.count == Self.codeLength }

    var body: some View {
        Form {
            if QRCodeScanner.isAvailable {
                Section {
                    QRCodeScanner(isPaused: isAuthorizing || status == .authorized, onScan: handleScan)
                        .aspectRatio(1, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .listRowInsets(EdgeInsets())
                }
                .listRowBackground(Color.clear)
            }

            Section {
                TextField(i18n.t("login:quick_connect_code"), text: $code)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .font(.title3.monospacedDigit())
                    .focused($isCodeFocused)
                    .onChange(of: code) { _, newValue in
                        let digits = String(newValue.filter(\.isNumber).prefix(Self.codeLength))
                        if digits != newValue { code = digits }
                        if status == .failed { status = nil }
                    }
            } footer: {
                switch status {
                case .authorized:
                    Text(i18n.t("sidebar:quick_connect_authorized")).foregroundStyle(.green)
                case .failed:
                    Text(i18n.t("sidebar:quick_connect_authorization_failed")).foregroundStyle(.red)
                case nil:
                    Text(i18n.t("sidebar:enter_quick_connect_code"))
                }
            }

            Section {
                Button(action: authorize) {
                    HStack {
                        Text(i18n.t("sidebar:authorize_quick_connect"))
                        if isAuthorizing {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(!isValidCode || isAuthorizing || status == .authorized)
            }
        }
        .navigationTitle(i18n.t("quick_connect"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(i18n.t("close"), systemImage: "xmark") { dismiss() }
            }
        }
        .sensoryFeedback(.success, trigger: scans)
        .sensoryFeedback(trigger: status) { _, newValue in
            switch newValue {
            case .authorized: .success
            case .failed: .error
            case nil: nil
            }
        }
    }

    private func handleScan(_ payload: String) {
        guard !isAuthorizing, status != .authorized, let scanned = Self.code(from: payload) else { return }
        guard scanned != code || status != .failed else { return }
        code = scanned
        scans += 1
        authorize()
    }

    private func authorize() {
        guard isValidCode, !isAuthorizing else { return }
        isCodeFocused = false
        status = nil
        isAuthorizing = true
        Task {
            let isAuthorized = (try? await appState.authorizeQuickConnect(code: code)) ?? false
            isAuthorizing = false
            status = isAuthorized ? .authorized : .failed
            guard isAuthorized else { return }
            try? await Task.sleep(for: Self.dismissDelay)
            dismiss()
        }
    }

    static func code(from payload: String) -> String? {
        let trimmed = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count == codeLength, trimmed.allSatisfy(\.isNumber) { return trimmed }

        guard let fragment = URLComponents(string: trimmed)?.fragment,
              let query = URLComponents(string: fragment)?.queryItems,
              let value = query.first(where: { $0.name == "code" })?.value,
              value.count == codeLength, value.allSatisfy(\.isNumber)
        else { return nil }
        return value
    }
}

struct QRCodeScanner: UIViewRepresentable {
    var isPaused = false
    let onScan: (String) -> Void

    static var isAvailable: Bool {
        AVCaptureDevice.default(for: .video) != nil
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.backgroundColor = .black
        view.previewLayer.videoGravity = .resizeAspectFill
        view.previewLayer.session = context.coordinator.session
        context.coordinator.onScan = onScan
        context.coordinator.start()
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {
        context.coordinator.onScan = onScan
        context.coordinator.isPaused = isPaused
    }

    static func dismantleUIView(_ view: PreviewView, coordinator: Coordinator) {
        coordinator.stop()
    }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }

    final class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        let session = AVCaptureSession()
        var onScan: ((String) -> Void)?
        var isPaused = false

        private var isConfigured = false
        private let sessionQueue = DispatchQueue(label: "QRCodeScanner.session")

        func start() {
            Task {
                guard await AVCaptureDevice.requestAccess(for: .video) else { return }
                if !isConfigured { configure() }
                let session = session
                sessionQueue.async { session.startRunning() }
            }
        }

        func stop() {
            let session = session
            sessionQueue.async { session.stopRunning() }
        }

        private func configure() {
            isConfigured = true
            guard let device = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: device),
                  session.canAddInput(input)
            else { return }
            session.addInput(input)

            let output = AVCaptureMetadataOutput()
            guard session.canAddOutput(output) else { return }
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.qr]
        }

        nonisolated func metadataOutput(
            _ output: AVCaptureMetadataOutput,
            didOutput metadataObjects: [AVMetadataObject],
            from connection: AVCaptureConnection
        ) {
            let payload = metadataObjects
                .compactMap { ($0 as? AVMetadataMachineReadableCodeObject)?.stringValue }
                .first
            guard let payload else { return }
            MainActor.assumeIsolated {
                guard !isPaused else { return }
                onScan?(payload)
            }
        }
    }
}
