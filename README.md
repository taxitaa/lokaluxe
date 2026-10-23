# LokaLuxe

<<<<<<< HEAD
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
=======
Flutter application for travel planning.

## Supabase authentication

The app supports Supabase Auth for account login across devices. The Supabase
project URL and publishable key are provided at build/run time; never use a
`service_role` key in the client app.

1. In the Supabase SQL Editor, run [`supabase/schema.sql`](supabase/schema.sql).
2. In Supabase Authentication settings, choose the email confirmation policy
   appropriate for the app. If confirmation is enabled, users must confirm the
   message before they can sign in on another device.
3. Run the app with these Dart defines, replacing the values with the project's
   URL and publishable key:

   ```powershell
   flutter run `
     --dart-define=SUPABASE_URL=https://your-project.supabase.co `
     --dart-define=SUPABASE_PUBLISHABLE_KEY=your-publishable-key
   ```

   Add the same defines to the build command used to distribute the app.
4. To migrate an account that exists only in the old local database, sign in on
   the original device once with its existing email and password while the app
   is configured for Supabase. If email confirmation is required, confirm it
   before signing in on another device.

Without both defines, authentication retains the existing local-only behavior.
Only authentication and basic profile information are stored in Supabase;
trips, expenses, and other app data remain local to each device.
>>>>>>> 6e8dd35f19ed7910b86630cdab283773570867af
