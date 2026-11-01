import AirCursorKit
import SwiftUI

@main
struct AirCursorWatchApp: App {
    @State private var model = WatchModel()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                if model.isRunning {
                    ControlView(model: model)
                } else {
                    SetupView(model: model)
                }
            }
        }
    }
}

struct SetupView: View {
    @Bindable var model: WatchModel

    var body: some View {
        Form {
            Section {
                TextField("IP Mac (192.168.x.x)", text: $model.host)
                    .textContentType(.URL)
                TextField("PIN", text: $model.pin)
            } footer: {
                Text("Lihat IP dan PIN di aplikasi AirCursor di Mac.")
            }

            Section {
                Button {
                    Task { await model.connect() }
                } label: {
                    if model.status == .checking {
                        ProgressView()
                    } else {
                        Label("Mulai", systemImage: "play.fill")
                    }
                }
                .disabled(!model.canConnect || model.status == .checking)

                if case .error(let message) = model.status {
                    Text(message).foregroundStyle(.red).font(.footnote)
                }
            }

            Section {
                NavigationLink("Pengaturan") { SettingsView(model: model) }
            }
        }
        .navigationTitle("AirCursor")
    }
}

struct ControlView: View {
    @Bindable var model: WatchModel
    @State private var crown = 0.0
    @State private var lastCrown = 0.0

    var body: some View {
        VStack(spacing: 8) {
            Button {
                model.click(.left)
            } label: {
                Image(systemName: "cursorarrow.click.2")
                    .font(.system(size: 34, weight: .semibold))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(model.isMoving ? .green : .gray)
            .modifier(DoubleTapClick())

            HStack {
                Button(model.isMoving ? "Jeda" : "Lanjut", systemImage: model.isMoving ? "pause.fill" : "hand.point.up.left.fill") {
                    model.toggleMoving()
                }
                Button("Klik kanan", systemImage: "contextualmenu.and.cursorarrow") {
                    model.click(.right)
                }
                .labelStyle(.iconOnly)
                .frame(width: 50)
                Button("Stop", systemImage: "stop.fill", role: .destructive) {
                    model.stop()
                }
                .labelStyle(.iconOnly)
                .frame(width: 50)
            }
            .font(.footnote)

            if case .error(let message) = model.status {
                Text(message).font(.caption2).foregroundStyle(.red).lineLimit(1)
            }
        }
        .focusable()
        .digitalCrownRotation($crown, from: -10_000, through: 10_000, sensitivity: .medium,
                              isContinuous: true, isHapticFeedbackEnabled: false)
        .onChange(of: crown) { _, value in
            // Crown up scrolls content up, like a trackpad with natural scrolling.
            model.scroll((value - lastCrown) * 4)
            lastCrown = value
        }
        .navigationTitle(model.isMoving ? "Aktif" : "Dijeda")
    }
}

struct SettingsView: View {
    @Bindable var model: WatchModel

    var body: some View {
        Form {
            Section("Kecepatan") {
                Slider(value: $model.settings.sensitivity, in: 300...2000, step: 100) {
                    Text("Sensitivitas")
                }
                Text("\(Int(model.settings.sensitivity))").font(.footnote).foregroundStyle(.secondary)
            }
            Section {
                Toggle("Balik kiri/kanan", isOn: $model.settings.invertX)
                Toggle("Balik atas/bawah", isOn: $model.settings.invertY)
            } footer: {
                Text("Nyalakan jika jam dipakai di tangan kanan atau arah kursor terbalik.")
            }
            Section {
                Button("Reset") { model.settings = MotionSettings() }
            }
        }
        .navigationTitle("Pengaturan")
    }
}

/// Double tap (pinch) on Series 9 / Ultra 2 and later triggers the primary action.
/// The API only exists on watchOS 11; older watches just use a screen tap.
private struct DoubleTapClick: ViewModifier {
    func body(content: Content) -> some View {
        if #available(watchOS 11.0, *) {
            content.handGestureShortcut(.primaryAction)
        } else {
            content
        }
    }
}
