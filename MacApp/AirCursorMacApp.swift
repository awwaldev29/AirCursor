import SwiftUI

@main
struct AirCursorMacApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        Window("AirCursor", id: "main") {
            ContentView(model: model)
        }
        .windowResizability(.contentSize)

        MenuBarExtra("AirCursor", systemImage: model.isReceiving ? "applewatch.radiowaves.left.and.right" : "applewatch") {
            Text("IP: \(model.addresses.first ?? "-")  ·  PIN: \(model.pin)")
            Text(model.isReceiving ? "Menerima gerakan" : "Menunggu Apple Watch")
            Divider()
            Button("Keluar") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
    }
}

struct ContentView: View {
    let model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label("AirCursor", systemImage: "applewatch.radiowaves.left.and.right")
                .font(.largeTitle.bold())

            GroupBox("Masukkan ini di Apple Watch") {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                    GridRow {
                        Text("Alamat IP").foregroundStyle(.secondary)
                        HStack {
                            Text(model.addresses.first ?? "Tidak ada Wi-Fi")
                                .font(.title2.monospaced().bold())
                                .textSelection(.enabled)
                            Button("Refresh", systemImage: "arrow.clockwise", action: model.refreshAddresses)
                                .labelStyle(.iconOnly)
                                .buttonStyle(.borderless)
                        }
                    }
                    GridRow {
                        Text("PIN").foregroundStyle(.secondary)
                        HStack {
                            Text(model.pin).font(.title2.monospaced().bold())
                            Button("PIN baru", action: model.regeneratePIN)
                                .buttonStyle(.borderless)
                        }
                    }
                    GridRow {
                        Text("Port").foregroundStyle(.secondary)
                        Text(String(model.port)).monospaced()
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GroupBox("Status") {
                VStack(alignment: .leading, spacing: 10) {
                    StatusRow(ok: model.isTrusted,
                              text: model.isTrusted ? "Izin Accessibility aktif" : "Izin Accessibility belum aktif")
                    if !model.isTrusted {
                        Button("Buka pengaturan Accessibility", action: model.requestAccessibility)
                        Text("Tanpa izin ini macOS mengabaikan gerakan kursor dari aplikasi.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    StatusRow(ok: model.serverState == "Siap" || model.serverState == "Terhubung",
                              text: "Server: \(model.serverState)")
                    StatusRow(ok: model.isReceiving,
                              text: model.isReceiving
                                ? "Menerima gerakan (\(model.eventCount) paket)"
                                : "Menunggu Apple Watch…")
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(24)
        .frame(width: 420)
    }
}

private struct StatusRow: View {
    let ok: Bool
    let text: String

    var body: some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: ok ? "checkmark.circle.fill" : "circle.dotted")
                .foregroundStyle(ok ? .green : .orange)
        }
    }
}
