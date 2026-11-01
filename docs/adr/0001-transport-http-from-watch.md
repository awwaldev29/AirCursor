# ADR-0001: Watch → Mac lewat HTTP keep-alive, bukan UDP/WebSocket

- **Status:** Diterima
- **Tanggal:** 2026-11-01

## Konteks

Data gerakan perlu dikirim dari Apple Watch ke Mac ~60 kali per detik dengan latensi rendah.
Pilihan yang paling ideal adalah UDP. Namun watchOS hanya mengizinkan *low-level networking*
(`NWConnection`, `URLSessionWebSocketTask`) untuk aplikasi streaming audio / VoIP
(Apple TN3135). `URLSession` biasa (HTTP) diizinkan untuk semua aplikasi.

## Opsi

1. **UDP langsung dari jam** — ditolak oleh sistem untuk jenis aplikasi kita.
2. **Jam → iPhone (WatchConnectivity) → Mac (UDP)** — latensi bagus, tapi butuh aplikasi
   ketiga (iOS) dan iPhone harus selalu dekat.
3. **Jam → Mac via `URLSession` HTTP/1.1 keep-alive + batching** — satu hop, dua aplikasi saja.

## Keputusan

Opsi 3. Jam mengumpulkan delta gerakan dan mengirim **satu request yang sedang berjalan**
dalam satu waktu; delta yang terkumpul selama request berjalan ikut di request berikutnya.
Dengan begitu tidak ada antrean yang menumpuk saat jaringan lambat — kursor tidak "ketinggalan",
hanya gerakannya menjadi sedikit lebih kasar.

## Konsekuensi

- (+) Arsitektur sederhana: 2 target aplikasi + 1 Swift Package bersama.
- (+) Bekerja baik lewat Wi-Fi langsung maupun lewat proxy Bluetooth iPhone.
- (−) Overhead header HTTP per paket; diterima untuk MVP.
- (−) Tidak ada discovery otomatis (Bonjour juga low-level di watchOS) → pengguna mengetik IP.
- Opsi 2 dicatat sebagai peningkatan di milestone M3.
