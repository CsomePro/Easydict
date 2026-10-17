//
//  LoginItemToggle.swift
//  Easydict
//

import ServiceManagement
import SwiftUI

/// Reads the system login-item status without blocking settings layout or drawing.
struct LoginItemToggle: View {
    var body: some View {
        Toggle(isOn: Binding(get: { model.isEnabled }, set: model.setEnabled)) {
            Text("launch_at_startup")
        }
        .disabled(!model.hasLoaded || model.isBusy)
        .onAppear { model.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            model.refresh()
        }
        .alert("launch_at_startup", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("ok", role: .cancel) {}
        } message: {
            Text(verbatim: model.errorMessage ?? "")
        }
    }

    @StateObject private var model = LoginItemViewModel()
}

@MainActor
private final class LoginItemViewModel: ObservableObject {
    @Published private(set) var isEnabled = false
    @Published private(set) var hasLoaded = false
    @Published private(set) var isBusy = false
    @Published var errorMessage: String?

    func refresh() {
        update(enabled: nil)
    }

    func setEnabled(_ enabled: Bool) {
        update(enabled: enabled)
    }

    private func update(enabled: Bool?) {
        guard !isBusy else { return }
        isBusy = true
        Task {
            // SMAppService.status performs synchronous IPC. SwiftUI can read a
            // toggle binding many times per frame, so expose only cached state.
            let result = await Task.detached(priority: .userInitiated) {
                Self.readOrUpdate(enabled: enabled)
            }.value
            isEnabled = result.enabled
            hasLoaded = true
            isBusy = false
            if let error = result.error { errorMessage = error }
            if enabled != nil {
                AnalyticsService.logEvent(withName: "settings", parameters: ["launch_at_startup": result.enabled])
            }
        }
    }

    private struct Snapshot: Sendable {
        let enabled: Bool
        let error: String?
    }

    nonisolated private static func readOrUpdate(enabled: Bool?) -> Snapshot {
        let service = SMAppService.mainApp
        var errorMessage: String?
        if let enabled {
            do {
                if enabled {
                    if service.status != .enabled { try service.register() }
                } else {
                    try service.unregister()
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        return Snapshot(enabled: service.status == .enabled, error: errorMessage)
    }
}
