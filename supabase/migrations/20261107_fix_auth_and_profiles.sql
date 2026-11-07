-- ============================================================
-- MIGRATION: 20261107_fix_auth_and_profiles.sql
-- PERBAIKAN:
-- 1. Auto-confirm email trigger pada auth.users (tanpa link konfirmasi)
-- 2. Schema profiles fleksibel (aman dijalankan meski kolom username tidak ada)
-- 3. RLS policy profiles aman untuk authenticated users
-- 4. Trigger handle_new_user yang adaptif & anti-gagal
-- ============================================================

-- 1. Trigger Auto-Confirm Email pada auth.users
CREATE OR REPLACE FUNCTION public.auto_confirm_user()
RETURNS TRIGGER AS $$
BEGIN
  NEW.email_confirmed_at = COALESCE(NEW.email_confirmed_at, NOW());
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tr_auto_confirm_user ON auth.users;
CREATE TRIGGER tr_auto_confirm_user
BEFORE INSERT ON auth.users
FOR EACH ROW
EXECUTE FUNCTION public.auto_confirm_user();

-- Konfirmasi semua user lama yang saat ini masih unconfirmed
UPDATE auth.users
SET email_confirmed_at = NOW()
WHERE email_confirmed_at IS NULL;


-- 2. Pastikan Tabel profiles Ada & Memiliki Kolom LiveTix
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT,
  email TEXT,
  phone TEXT,
  role TEXT DEFAULT 'User',
  avatar_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Tambah kolom jika belum ada
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS name TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS phone TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS email TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS role TEXT DEFAULT 'User';

-- Jika kolom role bertipe enum lama, ubah menjadi TEXT agar mendukung role LiveTix ('User', 'Produser', 'Admin')
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
      AND table_name = 'profiles' 
      AND column_name = 'role' 
      AND udt_name != 'text'
  ) THEN
    ALTER TABLE public.profiles ALTER COLUMN role TYPE TEXT USING role::TEXT;
  END IF;
END $$;

-- Jika kolom username ada dan NOT NULL, lepas constraint NOT NULL-nya secara aman
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
      AND table_name = 'profiles' 
      AND column_name = 'username'
  ) THEN
    ALTER TABLE public.profiles ALTER COLUMN username DROP NOT NULL;
  END IF;
END $$;


-- 3. Kebijakan Row Level Security (RLS) pada tabel profiles
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Pengguna dapat mengedit profil sendiri" ON public.profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can manage own profile" ON public.profiles;
DROP POLICY IF EXISTS "Semua orang bisa melihat profil publik" ON public.profiles;

-- Izinkan public membaca profil
CREATE POLICY "Semua orang bisa melihat profil publik"
ON public.profiles
FOR SELECT
TO public
USING (true);

-- Izinkan user terautentikasi mengelola (INSERT/UPDATE/DELETE) profil mereka sendiri
CREATE POLICY "Users can manage own profile"
ON public.profiles
FOR ALL
TO authenticated
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);


-- 4. Trigger Otomatis Pembuatan Profil saat Akun Didaftarkan (auth.users -> profiles)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  v_role TEXT;
  v_name TEXT;
  v_phone TEXT;
BEGIN
  v_role := COALESCE(NEW.raw_user_meta_data->>'role', 'User');
  v_name := COALESCE(
    NEW.raw_user_meta_data->>'name',
    NEW.raw_user_meta_data->>'full_name',
    split_part(NEW.email, '@', 1)
  );
  v_phone := COALESCE(NEW.raw_user_meta_data->>'phone', '');

  -- Insert adaptif: cek apakah kolom username ada di tabel
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
      AND table_name = 'profiles' 
      AND column_name = 'username'
  ) THEN
    INSERT INTO public.profiles (id, email, name, phone, role, username)
    VALUES (
      NEW.id,
      NEW.email,
      v_name,
      v_phone,
      v_role,
      'user_' || SUBSTRING(NEW.id::TEXT, 1, 8)
    )
    ON CONFLICT (id) DO UPDATE SET
      name = EXCLUDED.name,
      phone = EXCLUDED.phone,
      email = EXCLUDED.email;
  ELSE
    INSERT INTO public.profiles (id, email, name, phone, role)
    VALUES (
      NEW.id,
      NEW.email,
      v_name,
      v_phone,
      v_role
    )
    ON CONFLICT (id) DO UPDATE SET
      name = EXCLUDED.name,
      phone = EXCLUDED.phone,
      email = EXCLUDED.email;
  END IF;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  -- Mencegah proses registrasi gagal jika terjadi kendala pada pembuatan baris profil
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Pasang trigger pada auth.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW
EXECUTE FUNCTION public.handle_new_user();
