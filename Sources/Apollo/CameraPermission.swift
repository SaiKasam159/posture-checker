import AppKit

/// `CameraManager` (in CameraManager.swift) requests camera access itself
/// when it starts. This is just the one thing it doesn't do: sending the
/// user to System Settings once access has already been denied.
enum CameraPermission {
    static func openSystemSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") else { return }
        NSWorkspace.shared.open(url)
    }
}
