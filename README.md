# AirCursor

Gerakkan tangan, kursor Mac ikut bergerak. Apple Watch jadi *air mouse*: gratis, open source,
dan bisa dipasang dengan Apple ID biasa.

- Miringkan pergelangan tangan → kursor bergerak
- Tap layar jam atau **double tap / pinch jari** (Series 9, Ultra 2 ke atas) → klik
- Digital Crown → scroll
- Tombol **Jeda** → posisikan ulang tangan tanpa menggeser kursor

Detail produk ada di [docs/PRD.md](docs/PRD.md), keputusan arsitektur di [docs/adr/](docs/adr/).

## Kebutuhan

- Mac dengan macOS 15+ dan Xcode 16+
- Apple Watch Series 4 ke atas dengan watchOS 10+, dipasangkan ke iPhone
- Mac dan jam di **Wi-Fi yang sama** (atau iPhone di dekat jam, di Wi-Fi yang sama)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`

## Instalasi (gratis, tanpa Apple Developer Program)

```bash
git clone https://github.com/awwaldev29/AirCursor.git && cd AirCursor
xcodegen generate
open AirCursor.xcodeproj
```

1. **Xcode → Settings → Accounts** → tambahkan Apple ID kamu.
2. Pilih proyek **AirCursor** → tiap target (**AirCursorMac** dan **AirCursorWatch**) →
   **Signing & Capabilities** → *Team* = Apple ID kamu (Personal Team).
3. **Mac:** pilih scheme `AirCursorMac` → destination *My Mac* → ⌘R.
   Klik **Buka pengaturan Accessibility** di aplikasinya, lalu nyalakan AirCursor.
4. **Apple Watch:** di jam, aktifkan *Settings → Privacy & Security → Developer Mode*.
   Pilih scheme `AirCursorWatch` → destination jam kamu → ⌘R.
   Saat pertama kali, buka *Settings → General → VPN & Device Management* di jam/iPhone
   untuk mempercayai sertifikat developer kamu.
5. Di jam, masukkan **IP** dan **PIN** yang tampil di aplikasi Mac → **Mulai**.

> Dengan Apple ID gratis, aplikasi di jam kedaluwarsa setelah **7 hari**. Jalankan ⌘R lagi
> dari Xcode untuk memperpanjang.

## Cara pakai

Pakai jam di **tangan kiri**, arahkan tangan ke layar dengan telapak menghadap ke bawah, lalu:

| Gerakan | Hasil |
|---|---|
| Putar tangan ke kiri/kanan | Kursor ke kiri/kanan |
| Angkat/turunkan ujung jari | Kursor ke atas/bawah |
| Tap tombol hijau / double tap jari | Klik kiri |
| Tombol menu kecil | Klik kanan |
| Putar Digital Crown | Scroll |
| Jeda / Lanjut | *Clutch*: kursor berhenti sementara |

Kalau arah kursor terbalik (misalnya jam di tangan kanan), buka **Pengaturan** di jam lalu
nyalakan *Balik kiri/kanan* atau *Balik atas/bawah*.

## Troubleshooting

| Masalah | Solusi |
|---|---|
| Kursor tidak bergerak, tapi status Mac "Menerima gerakan" | Izin Accessibility belum aktif, atau hilang setelah rebuild. Matikan lalu nyalakan lagi AirCursor di *Accessibility*. |
| Jam: "PIN salah" | PIN di Mac diganti. Masukkan PIN yang baru. |
| Jam: timeout / tidak terhubung | Pastikan jaringannya sama, IP benar, dan Firewall macOS mengizinkan AirCursor. |
| Kursor jalan sendiri | Tekan **Jeda**, atau naikkan deadzone di `MotionSettings`. |

## Struktur proyek

```
AirCursorKit/   Swift Package bersama: protokol, MotionMapper, HTTPParser (+ unit test)
MacApp/         Aplikasi macOS: server lokal + CGEvent untuk menggerakkan kursor
WatchApp/       Aplikasi watchOS: CoreMotion → HTTP ke Mac
docs/           PRD dan ADR
project.yml     Definisi proyek XcodeGen (file .xcodeproj tidak di-commit)
```

## Development

```bash
# Unit test logika inti
cd AirCursorKit && swift test

# Build kedua aplikasi tanpa signing (cek kompilasi)
xcodegen generate
xcodebuild -scheme AirCursorMac   -destination 'generic/platform=macOS'   CODE_SIGNING_ALLOWED=NO build
xcodebuild -scheme AirCursorWatch -destination 'generic/platform=watchOS' CODE_SIGNING_ALLOWED=NO build
```

### Alur Git

- `main` selalu dalam kondisi bisa di-build; jangan commit langsung ke sana.
- Satu fitur = satu branch: `feat/…`, `fix/…`, `docs/…`, `chore/…`.
- Pesan commit memakai [Conventional Commits](https://www.conventionalcommits.org/):
  `feat(watch): add scroll with Digital Crown`.
- Buka Pull Request ke `main`, pastikan `swift test` dan kedua build lulus, lalu *squash merge*.
- Rilis diberi tag semver: `v0.1.0`.

## Lisensi

MIT — lihat [LICENSE](LICENSE).
