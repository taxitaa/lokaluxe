# lokaluxe

## Mengaktifkan AI Concierge

1. Buka [Google AI Studio](https://aistudio.google.com/app/apikey), masuk dengan
   akun Google, lalu buat Gemini API key.
2. Di PowerShell, dari folder project, buat file konfigurasi lokal:

   ```powershell
   Copy-Item secrets.json.example secrets.json
   notepad secrets.json
   ```

3. Ganti `PASTE_YOUR_GEMINI_API_KEY_HERE` di `secrets.json` dengan key milikmu,
   simpan file, lalu jalankan:

   ```powershell
   flutter run --dart-define-from-file=secrets.json
   ```

   Jika `secrets.json` yang sudah ada mencantumkan `GEMINI_MODEL`, hapus baris
   tersebut. Aplikasi sekarang mengambil daftar model yang benar-benar tersedia
   untuk API key dan memilih Gemini Flash yang didukung secara otomatis.

   Jangan kirim API key ke chat atau commit `secrets.json`. File itu sudah
dikecualikan di `.gitignore`. Jika menggunakan VS Code, jalankan perintah
Flutter di terminal terintegrasi VS Code agar key tetap diberikan ke proses
build.

API key yang ditanam ke aplikasi klien masih dapat diekstrak dari build. Untuk
aplikasi produksi, gunakan backend proxy dan batasi akses serta kuota key di
Google Cloud. Concierge diarahkan untuk menjawab topik perjalanan saja, tetapi
instruksi model bukan batas keamanan yang mutlak.
