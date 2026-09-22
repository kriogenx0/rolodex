import AppKit
import SwiftUI

struct PermissionDeniedView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Contacts Access Needed", systemImage: "lock.fill")
        } description: {
            Text("Rolodex needs permission to read and manage your Contacts. Open System Settings > Privacy & Security > Contacts and enable access for Rolodex, then relaunch the app.")
        } actions: {
            Button("Open Privacy Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Contacts") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
}

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading Contacts…")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
