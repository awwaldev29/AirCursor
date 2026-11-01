# PRD — AirCursor

> Gerakkan tangan, kursor Mac ikut bergerak. Apple Watch sebagai *air mouse*.

| | |
|---|---|
| **Status** | Draft v1 — MVP |
| **Owner** | @awwaldev29 |
| **Tanggal** | 1 November 2026 |
| **Platform** | watchOS 11+ · macOS 15+ |

---

## 1. Latar belakang

Video yang sedang ramai menunjukkan Apple Watch dipakai sebagai mouse udara: tangan
digerakkan di udara → kursor Mac ikut bergerak, lalu jari di-*pinch* → klik. Solusi
komersial yang sudah ada (mis. WowMouse) berbayar dan *closed source*. Kita ingin
versi sendiri yang **gratis, open source, dan bisa dipasang dengan Apple ID biasa**
(tanpa Apple Developer Program berbayar).

## 2. Tujuan & non-tujuan

### Tujuan (MVP)
1. Memindahkan kursor Mac dengan rotasi pergelangan tangan, terasa responsif
   (target latensi end-to-end < 100 ms di Wi-Fi rumah).
2. Klik kiri dengan tap layar jam **atau** gesture *double tap* (pinch jari)
   di Apple Watch Series 9 / Ultra 2 ke atas.
3. Klik kanan (tombol terpisah) dan scroll (Digital Crown).
4. "Clutch": jeda gerakan supaya tangan bisa diposisikan ulang tanpa menggeser kursor
   (seperti mengangkat mouse dari meja).
5. Aman di jaringan lokal: hanya jam yang tahu **PIN** yang boleh menggerakkan kursor.
6. Bisa dipasang gratis lewat Xcode ke perangkat sendiri.

### Non-tujuan (MVP)
- Rilis App Store / TestFlight.
- Dukungan Windows / Linux.
- Drag & drop, gesture multi-jari, keyboard dari jam.
- Kontrol tanpa Wi-Fi (Bluetooth langsung jam → Mac tidak didukung oleh watchOS).

## 3. Persona & skenario

- **Presenter** — berdiri jauh dari laptop, ganti slide dan klik link dengan tangan.
- **Sofa user** — nonton YouTube / Spotify di Mac yang tersambung ke TV, kontrol dari sofa.
- **Developer/maker** — ingin pamer "built it myself" seperti di video.

**Skenario utama:** buka AirCursor di Mac → muncul IP + PIN → buka AirCursor di jam,
masukkan IP + PIN → tekan **Mulai** → arahkan tangan ke layar, gerakkan → kursor ikut →
tap/pinch untuk klik.

## 4. Kebutuhan fungsional

| ID | Kebutuhan | Prioritas |
|----|-----------|-----------|
| F1 | Mac app menjalankan server lokal dan menampilkan IP, port, PIN 4 digit | P0 |
| F2 | Mac app meminta & menampilkan status izin Accessibility | P0 |
| F3 | Watch app membaca gyroscope (CoreMotion, 60 Hz) dan mengubahnya jadi delta kursor | P0 |
| F4 | Watch mengirim delta ke Mac; request ditolak bila PIN salah | P0 |
| F5 | Klik kiri: tap tombol / double-tap gesture | P0 |
| F6 | Klik kanan: tombol terpisah | P1 |
| F7 | Scroll lewat Digital Crown | P1 |
| F8 | Clutch (Jeda/Lanjut) | P0 |
| F9 | Pengaturan sensitivitas & balik sumbu X/Y (untuk jam di tangan kanan) | P1 |
| F10 | Mac menampilkan status "Terhubung" + waktu event terakhir | P1 |
| F11 | Watch tetap mengirim saat layar redup (extended runtime session) | P2 |

## 5. Kebutuhan non-fungsional

- **Latensi:** < 100 ms p95 di LAN.
- **Kehalusan:** deadzone untuk menghilangkan *drift* gyroscope saat tangan diam.
- **Baterai:** sensor & jaringan berhenti total saat tidak dalam mode Mulai.
- **Keamanan:** server hanya menerima request dengan PIN benar; PIN bisa di-generate ulang.
- **Privasi:** tidak ada data keluar dari jaringan lokal, tanpa analytics.

## 6. Arsitektur

```
 ┌──────────────── Apple Watch ────────────────┐        ┌──────────────── Mac ─────────────────┐
 │ CoreMotion (gyro 60 Hz)                      │        │ NWListener (TCP :8787, HTTP/1.1)      │
 │   └─▶ MotionMapper (deadzone, gain, accel)   │  HTTP  │   └─▶ RequestParser + PIN check       │
 │         └─▶ EventSender (batch tiap ~16 ms)  │ ─────▶ │         └─▶ CursorController (CGEvent)│
 │ UI: Mulai/Jeda · Klik · Crown = scroll       │  JSON  │ UI: IP · PIN · izin · status          │
 └──────────────────────────────────────────────┘        └───────────────────────────────────────┘
                     ▲ shared: AirCursorKit (Swift Package) — protocol, mapper, parser, tests
```

Keputusan desain dicatat di [`docs/adr/`](adr/).

### Protokol (v1)

`POST /v1/events` — header `X-AirCursor-PIN: 1234`, body:

```json
{ "dx": 12.5, "dy": -3.0, "scroll": 0, "clicks": ["left"] }
```

Respon `204` sukses, `401` PIN salah, `400` body tidak valid.
`GET /v1/ping` → `200 {"name":"MacBook Air","version":1}` untuk tes koneksi.

## 7. Metrik keberhasilan

- Dari clone repo sampai kursor bergerak: **< 15 menit** mengikuti README.
- Latensi terasa "langsung" pada uji manual (tidak ada lag yang mengganggu).
- Kursor diam (tidak drift) saat tangan diam selama 10 detik.

## 8. Rencana rilis

| Milestone | Isi |
|-----------|-----|
| **M0 — Fondasi** | PRD, ADR, repo GitHub, struktur proyek, CI lokal (`swift test`) |
| **M1 — MVP** | F1–F8: kursor bergerak, klik, clutch, PIN |
| **M2 — Polish** | F9–F11, onboarding, ikon aplikasi |
| **M3 — Lanjutan** | Mode presenter (next/prev slide), drag, iPhone relay via UDP untuk latensi lebih rendah, GitHub Actions |

## 9. Risiko & mitigasi

| Risiko | Dampak | Mitigasi |
|--------|--------|----------|
| watchOS membatasi socket low-level (UDP/WebSocket) | Tidak bisa streaming UDP langsung | Pakai `URLSession` HTTP keep-alive + batching (ADR-0001) |
| Sertifikat Apple ID gratis kedaluwarsa 7 hari | App di jam berhenti jalan | Dokumentasikan: Run ulang dari Xcode |
| Izin Accessibility hilang tiap rebuild (signing ad-hoc) | Kursor tidak bergerak | Status izin terlihat di UI + tombol buka Settings |
| Drift gyroscope | Kursor jalan sendiri | Deadzone + clutch |
| Siapa pun di Wi-Fi bisa kirim event | Keamanan | PIN wajib, server bisa dimatikan |

## 10. Pertanyaan terbuka

- Perlukah mode "pointing" absolut (arah tangan = posisi layar) selain mode relatif?
- Perlukah iPhone companion app untuk discovery otomatis (Bonjour) agar tidak ketik IP?
