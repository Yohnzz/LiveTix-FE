**Ketentuan Login dan Registrasi Google OAuth**

Pada fitur autentikasi menggunakan Google OAuth, pastikan pengguna yang login menggunakan akun Google **tidak perlu melakukan registrasi secara manual**, baik pengguna lama maupun pengguna baru.

Ketentuan yang harus diterapkan:
1. **Login Google untuk pengguna baru:** Jika pengguna belum memiliki akun di database, sistem harus otomatis membuat akun baru berdasarkan informasi yang diperoleh dari Google OAuth, seperti nama, alamat email, foto profil, dan Google ID.
2. **Login Google untuk pengguna lama:** Jika email atau identitas Google sudah terdaftar, sistem harus langsung mengautentikasi pengguna menggunakan akun yang sudah tersedia tanpa membuat duplikasi data.
3. **Akses langsung:** Setelah proses autentikasi Google berhasil, pengguna langsung diarahkan ke dashboard atau halaman utama aplikasi tanpa melewati halaman registrasi tambahan.
4. **Sinkronisasi database:** Pastikan setiap akun Google yang berhasil login benar-benar tersimpan di tabel pengguna Supabase Auth dan tabel profil pengguna (jika aplikasi menggunakannya).
5. **Pencegahan duplikasi:** Gunakan identitas Google atau email yang telah diverifikasi untuk memastikan satu pengguna tidak memiliki beberapa akun akibat login berulang.
6. **Penanganan kegagalan:** Jika proses autentikasi atau penyimpanan profil gagal, tampilkan pesan kesalahan yang jelas dan jangan mengarahkan pengguna seolah-olah login berhasil.

**Hasil yang diharapkan:**
Pengguna cukup menekan tombol *Login with Google*, memilih akun Google, menyelesaikan proses autentikasi, kemudian langsung masuk ke aplikasi. Tidak ada proses registrasi manual atau pengisian formulir tambahan, termasuk bagi pengguna yang baru pertama kali menggunakan aplikasi.

https://arvydukozxjvwwhqnbth.supabase.co/auth/v1/callback<!--  -->