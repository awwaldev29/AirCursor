# ADR-0002: Pemetaan gerakan relatif dari gyroscope

- **Status:** Diterima
- **Tanggal:** 2026-11-01

## Konteks

Ada dua cara mengubah gerakan tangan jadi kursor:

- **Absolut** — orientasi tangan dipetakan langsung ke posisi layar (seperti laser pointer).
  Butuh kalibrasi dan rentan drift heading karena jam tidak tahu posisi layar.
- **Relatif** — kecepatan rotasi (rad/s) dikalikan *gain* menjadi delta piksel (seperti mouse).

## Keputusan

Relatif. Dengan jam di pergelangan kiri, tangan menunjuk ke layar, telapak menghadap bawah:

| Gerakan tangan | Sumbu gyro | Kursor |
|---|---|---|
| Kiri/kanan (yaw) | `rotationRate.z` | `dx = -z` |
| Atas/bawah (pitch) | `rotationRate.y` | `dy = +y` |

Pipeline per sampel (60 Hz): deadzone → gain × (1 + akselerasi × |kecepatan|) × dt.
Tanda sumbu bisa dibalik dari pengaturan (untuk jam di tangan kanan atau gaya pegang lain).

## Konsekuensi

- (+) Tanpa kalibrasi, terasa seperti mouse biasa.
- (+) Drift gyroscope kecil dan dihapus oleh deadzone.
- (−) Butuh "clutch" (Jeda) untuk memosisikan ulang tangan — sudah masuk MVP (F8).
