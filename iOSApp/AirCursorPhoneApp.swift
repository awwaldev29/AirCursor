import AirCursorKit
import SwiftUI

@main
struct AirCursorPhoneApp: App {
    @State private var model = PhoneModel()

    var body: some Scene {
        WindowGroup {
            if model.isRunning {
                RemoteView(model: model)
            } else {
                NavigationStack {
                    SetupView(model: model)
                }
            }
        }
    }
}

struct SetupView: View {
    @Bindable var model: PhoneModel
    @State private var browser = MacBrowser()
    @State private var showSettings = false

    var body: some View {
        Form {
            Section {
                TextField("PIN 4 digit", text: $model.pin)
                    .keyboardType(.numberPad)
                    .font(.title2.monospaced())
            } header: {
                Text("PIN")
            } footer: {
                Text("PIN tampil di aplikasi AirCursor di Mac.")
            }

            Section("Mac di jaringan ini") {
                if browser.macs.isEmpty {
                    Label("Mencari Mac…", systemImage: "magnifyingglass")
                        .foregroundStyle(.secondary)
                }
                ForEach(browser.macs) { mac in
                    Button {
                        Task { await model.connect(to: mac) }
                    } label: {
                        Label(mac.name, systemImage: "laptopcomputer")
                    }
                    .disabled(model.pin.count != 4 || model.status == .checking)
                }
            }

            Section {
                TextField("IP Mac, mis. 192.168.1.5", text: $model.host)
                    .keyboardType(.numbersAndPunctuation)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("Sambungkan manual") {
                    Task { await model.connect() }
                }
                .disabled(!model.canConnect || model.status == .checking)
            } header: {
                Text("Atau masukkan IP")
            }

            if model.status == .checking {
                ProgressView("Menyambungkan…")
            }
            if case .error(let message) = model.status {
                Text(message).foregroundStyle(.red)
            }
        }
        .navigationTitle("AirCursor")
        .toolbar {
            Button("Pengaturan", systemImage: "slider.horizontal.3") { showSettings = true }
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack { SettingsView(model: model) }
        }
        .onAppear { browser.start() }
        .onDisappear { browser.stop() }
    }
}

/// The remote: hold the phone flat, top edge pointing at the screen.
struct RemoteView: View {
    @Bindable var model: PhoneModel
    @State private var pressStart: Date?
    @State private var lastScrollY: CGFloat?

    var body: some View {
        VStack(spacing: 12) {
            header

            HStack(spacing: 12) {
                movePad
                scrollStrip
            }

            HStack(spacing: 12) {
                mouseButton("Klik", systemImage: "cursorarrow.click") { model.click(.left) }
                mouseButton("Klik kanan", systemImage: "contextualmenu.and.cursorarrow") { model.click(.right) }
            }
            .frame(height: 110)
        }
        .padding()
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                if case .connected(let name) = model.status {
                    Text(name).font(.headline)
                } else if case .error(let message) = model.status {
                    Text(message).font(.footnote).foregroundStyle(.red).lineLimit(2)
                }
                Text(model.holdToMove ? "Tahan pad untuk menggerakkan kursor" : "Kursor selalu mengikuti HP")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if !model.holdToMove {
                Button(model.isMoving ? "Jeda" : "Lanjut", systemImage: model.isMoving ? "pause.fill" : "play.fill") {
                    model.setMoving(!model.isMoving)
                }
                .buttonStyle(.bordered)
            }
            Button("Stop", systemImage: "stop.fill", role: .destructive, action: model.stop)
                .buttonStyle(.bordered)
        }
    }

    /// Hold-to-move: thumb down = cursor follows the phone, thumb up = clutch. A quick tap clicks.
    private var movePad: some View {
        RoundedRectangle(cornerRadius: 28)
            .fill(model.isMoving ? Color.green.opacity(0.35) : Color.white.opacity(0.08))
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: model.isMoving ? "dot.radiowaves.left.and.right" : "hand.point.up.left")
                        .font(.system(size: 44))
                    Text(model.isMoving ? "Bergerak" : (model.holdToMove ? "Tahan di sini" : "Dijeda"))
                        .font(.headline)
                    Text("Tap = klik")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard pressStart == nil else { return }
                        pressStart = Date()
                        if model.holdToMove { model.setMoving(true) }
                    }
                    .onEnded { value in
                        let duration = Date().timeIntervalSince(pressStart ?? Date())
                        pressStart = nil
                        if model.holdToMove { model.setMoving(false) }
                        let distance = hypot(value.translation.width, value.translation.height)
                        if duration < 0.25 && distance < 12 {
                            model.click(.left)
                        }
                    }
            )
    }

    /// Drag a thumb up and down to scroll.
    private var scrollStrip: some View {
        RoundedRectangle(cornerRadius: 28)
            .fill(Color.white.opacity(0.08))
            .frame(width: 70)
            .overlay {
                VStack {
                    Image(systemName: "chevron.up")
                    Spacer()
                    Text("Scroll").font(.caption).rotationEffect(.degrees(-90)).fixedSize()
                    Spacer()
                    Image(systemName: "chevron.down")
                }
                .padding(.vertical, 20)
                .foregroundStyle(.secondary)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let y = value.location.y
                        if let last = lastScrollY {
                            model.scroll(Double(y - last) * 2)
                        }
                        lastScrollY = y
                    }
                    .onEnded { _ in lastScrollY = nil }
            )
    }

    private func mouseButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.roundedRectangle(radius: 24))
    }
}

struct SettingsView: View {
    @Bindable var model: PhoneModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section {
                Toggle("Tahan untuk gerak", isOn: $model.holdToMove)
            } footer: {
                Text("Nyala: kursor hanya bergerak saat jempol menahan pad. Mati: kursor selalu mengikuti HP; pakai tombol Jeda di atas.")
            }
            Section("Kecepatan") {
                Slider(value: $model.settings.sensitivity, in: 300...2000, step: 100)
                Text("Sensitivitas \(Int(model.settings.sensitivity))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section {
                Toggle("Balik kiri/kanan", isOn: $model.settings.invertX)
                Toggle("Balik atas/bawah", isOn: $model.settings.invertY)
            } footer: {
                Text("Pegang HP mendatar, ujung atas menunjuk ke layar Mac.")
            }
            Section {
                Button("Reset ke default") { model.settings = MotionSettings() }
            }
        }
        .navigationTitle("Pengaturan")
        .toolbar {
            Button("Selesai") { dismiss() }
        }
    }
}
