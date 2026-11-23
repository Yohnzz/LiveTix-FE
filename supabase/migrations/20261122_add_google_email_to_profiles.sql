-- File: 20261122_add_google_email_to_profiles.sql
-- Menambahkan kolom google_email pada public.profiles untuk mencatat email akun Google
-- yang ditautkan (bind) ke akun utama pengguna / produser.

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS google_email TEXT;

CREATE INDEX IF NOT EXISTS idx_profiles_google_email
  ON public.profiles (google_email);
