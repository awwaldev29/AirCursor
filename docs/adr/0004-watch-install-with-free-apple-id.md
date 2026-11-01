# ADR-0004: Aplikasi jam tetap mandiri, dipasang langsung dari Xcode

- **Status:** Diterima
- **Tanggal:** 2026-11-01

## Konteks

Memasang aplikasi ke Apple Watch dengan Apple ID gratis (Personal Team) ternyata penuh jebakan.
Hasil uji di Apple Watch Series 5 (watchOS 10.6.2) dengan Xcode 27:

1. **Jam harus satu jaringan Wi-Fi dengan Mac.** Xcode membangunkan jam lewat Bluetooth, lalu
   mencari iklan Bonjour jam di Wi-Fi. Kalau jam memakai jalur Bluetooth ke iPhone, koneksinya
   timeout. Hotspot dari iPhone pasangan tidak bisa dipakai jam. Jam lama hanya mendukung 2.4 GHz.
2. **Developer Mode jam** baru bisa dinyalakan setelah Xcode berhasil tersambung satu kali.
3. **Layar jam yang tidur memutus Wi-Fi.** Transfer *developer disk image* jadi macet
   (`kAMDMobileImageMounterExistingTransferInProgress`), dan baru beres setelah jam di-restart.
4. Kami mencoba menanam aplikasi jam di aplikasi iPhone supaya dipasang lewat aplikasi Watch.
   Ini **ditolak oleh watchOS**:
   `MIInstallerErrorDomain 111 — authorized by a free provisioning profile, but apps validated by
   those are not allowed to be installed from this source`.
5. Provisioning profile lama yang di-cache Xcode tidak otomatis ikut memuat jam yang baru terdaftar.

## Keputusan

- Aplikasi jam tetap **watch-only** (`WKWatchOnly`) dan **tidak ditanam** di aplikasi iPhone.
- Pemasangan selalu **langsung dari Xcode / `devicectl` ke jam**.
- Team signing disimpan di `Config/Local.xcconfig` (di-ignore Git) lewat `Config/Signing.xcconfig`,
  supaya `xcodegen generate` tidak pernah menghapusnya.
- Mode latar belakang `physical-therapy` (PRD F11) dihapus dulu: belum terbukti berguna dan
  menambah risiko penolakan saat instalasi.

## Konsekuensi

- (+) Jalur instalasi yang terbukti berhasil terdokumentasi di README (Troubleshooting).
- (−) Pengguna akun gratis harus mengulang ⌘R dari Xcode setiap 7 hari, untuk jam maupun iPhone.
- (−) Aplikasi bisa berhenti saat layar jam redup lama (F11 ditunda ke M2).
