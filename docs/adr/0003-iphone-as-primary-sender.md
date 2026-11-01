# ADR-0003: iPhone sebagai pengirim utama, Apple Watch opsional

- **Status:** Diterima
- **Tanggal:** 2026-11-01

## Konteks

Saat uji di perangkat asli (Apple Watch Series 4, watchOS 10.6.2), aplikasi jam tidak bisa
dipasang. Log `remotepairingd` menunjukkan Mac berhasil membangunkan jam lewat Bluetooth,
tapi jam tidak pernah mengiklankan diri di Wi-Fi yang sama dengan Mac
(`timeout for browsing for on-demand bonjour advert`). Jam lebih memilih jalur Bluetooth ke
iPhone, dan hotspot iPhone pasangan tidak bisa dipakai jam. Selain itu Series 4 hanya
mendukung Wi-Fi 2.4 GHz. Hasilnya: proses pemasangan rapuh dan sangat bergantung pada kondisi jaringan.

## Keputusan

Tambahkan aplikasi iPhone sebagai pengirim utama. iPhone dipegang seperti remote,
dan ujung atasnya menunjuk ke layar.

- `MotionStreamer` dipindah ke `Shared/` dan dipakai bersama oleh jam dan iPhone.
  Perbedaannya hanya pemetaan sumbu (`Axes.wrist` vs `Axes.handheld`).
- Mac mengiklankan `_aircursor._tcp` lewat Bonjour, sehingga iPhone menemukan Mac tanpa
  mengetik IP. iOS tidak membatasi low-level networking seperti watchOS (lihat ADR-0001).
- Mode **tahan untuk gerak**: kursor hanya bergerak saat jempol menahan pad, dan tap cepat = klik.
  Ini menggantikan tombol Jeda sebagai *clutch* default.
- Aplikasi jam tetap dipertahankan untuk jam yang bisa terhubung.

## Konsekuensi

- (+) Instalasi lewat kabel USB jauh lebih andal dibanding jam.
- (+) Tanpa ketik IP; layar besar untuk klik kiri/kanan dan scroll.
- (+) Protokol dan aplikasi Mac tidak berubah (hanya ditambah iklan Bonjour).
- (−) Perangkat dipegang, bukan di pergelangan seperti di video.
- (−) Satu target aplikasi tambahan yang perlu dirawat.
