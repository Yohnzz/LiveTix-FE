-- ==============================================================================
-- MIGRATION: SETUP ROLES (User, Produser, Admin, Gatecrew) & PROFILES
-- LiveTix / Soundwave System
-- ==============================================================================

-- 1. Pastikan ekstensi uuid-ossp tersedia
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. Pastikan tabel public.profiles memiliki semua kolom yang diperlukan
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username TEXT,
  email TEXT,
  name TEXT,
  full_name TEXT,
  phone TEXT DEFAULT '',
  avatar_url TEXT DEFAULT '',
  role TEXT NOT NULL DEFAULT 'User',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Pastikan kolom-kolom penting ada jika tabel sudah terbuat sebelumnya
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS username TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS name TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS full_name TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS phone TEXT DEFAULT '';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS avatar_url TEXT DEFAULT '';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS role TEXT NOT NULL DEFAULT 'User';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT NOW();
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

-- Izinkan username bernilai NULL atau opsional agar pendaftaran via Auth tidak terbentur
ALTER TABLE public.profiles ALTER COLUMN username DROP NOT NULL;

-- 3. Pasang CHECK CONSTRAINT agar kolom 'role' hanya menerima User, Produser, Admin, atau Gatecrew
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_role_check;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_role_check
  CHECK (LOWER(role) IN ('user', 'produser', 'producer', 'promoter', 'admin', 'gatecrew', 'gate_crew', 'crew'));

-- 4. Tabel promoter_profiles untuk data legalitas & verifikasi Produser
CREATE TABLE IF NOT EXISTS public.promoter_profiles (
  id TEXT PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  company_name TEXT NOT NULL,
  address TEXT DEFAULT 'Jl. Sudirman No. 45, Jakarta',
  bank_name TEXT DEFAULT '',
  bank_account_number TEXT DEFAULT '',
  bank_account_name TEXT DEFAULT '',
  is_verified BOOLEAN NOT NULL DEFAULT FALSE,
  approval_status TEXT NOT NULL DEFAULT 'pending',
  rejection_reason TEXT,
  submitted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 5. Helper Function: Cek apakah user saat ini adalah Admin
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND LOWER(role) = 'admin'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. Helper Function: Cek apakah user saat ini adalah Produser
CREATE OR REPLACE FUNCTION public.is_producer()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND LOWER(role) IN ('produser', 'producer', 'promoter', 'developer')
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. Helper Function: Cek apakah user saat ini adalah Gatecrew
CREATE OR REPLACE FUNCTION public.is_gatecrew()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND LOWER(role) IN ('gatecrew', 'gate_crew', 'crew')
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 8. Trigger Otomatis saat Pengguna Mendaftar (auth.users -> public.profiles)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  v_role TEXT;
  v_name TEXT;
  v_username TEXT;
  v_phone TEXT;
BEGIN
  -- Normalisasi role: Produser / Admin / Gatecrew / User
  v_role := COALESCE(NEW.raw_user_meta_data->>'role', 'User');
  IF LOWER(v_role) IN ('produser', 'producer', 'promoter', 'developer') THEN
    v_role := 'Produser';
  ELSIF LOWER(v_role) = 'admin' THEN
    v_role := 'Admin';
  ELSIF LOWER(v_role) IN ('gatecrew', 'gate_crew', 'crew') THEN
    v_role := 'Gatecrew';
  ELSE
    v_role := 'User';
  END IF;

  -- Normalisasi nama
  v_name := COALESCE(
    NEW.raw_user_meta_data->>'name',
    NEW.raw_user_meta_data->>'full_name',
    split_part(NEW.email, '@', 1)
  );

  -- Normalisasi username unik
  v_username := COALESCE(
    NEW.raw_user_meta_data->>'username',
    split_part(NEW.email, '@', 1) || '_' || substr(NEW.id::text, 1, 6)
  );

  v_phone := COALESCE(NEW.raw_user_meta_data->>'phone', '');

  -- Simpan / perbarui ke tabel profiles
  INSERT INTO public.profiles (id, email, username, name, full_name, phone, role)
  VALUES (NEW.id, NEW.email, v_username, v_name, v_name, v_phone, v_role)
  ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    full_name = EXCLUDED.full_name,
    phone = EXCLUDED.phone,
    role = EXCLUDED.role,
    email = EXCLUDED.email,
    updated_at = NOW();

  -- Jika mendaftar sebagai Produser, otomatis buat entri promoter_profiles bila belum ada
  IF v_role = 'Produser' THEN
    INSERT INTO public.promoter_profiles (id, user_id, company_name, is_verified, approval_status, submitted_at)
    VALUES (
      'promoter-' || substr(NEW.id::text, 1, 8),
      NEW.id,
      v_name,
      TRUE,
      'approved',
      NOW()
    )
    ON CONFLICT (id) DO NOTHING;
  END IF;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Pasang trigger pada auth.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 9. Atur Row Level Security (RLS) pada tabel profiles
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'public.profiles'::regclass AND polname = 'Semua orang bisa melihat profil publik') THEN
    CREATE POLICY "Semua orang bisa melihat profil publik" ON public.profiles FOR SELECT USING (TRUE);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'public.profiles'::regclass AND polname = 'Pengguna dapat menyisipkan profil sendiri') THEN
    CREATE POLICY "Pengguna dapat menyisipkan profil sendiri" ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'public.profiles'::regclass AND polname = 'Pengguna dapat mengedit profil sendiri') THEN
    CREATE POLICY "Pengguna dapat mengedit profil sendiri" ON public.profiles FOR UPDATE USING (auth.uid() = id) WITH CHECK (auth.uid() = id);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'public.profiles'::regclass AND polname = 'Admin dapat mengelola seluruh profil') THEN
    CREATE POLICY "Admin dapat mengelola seluruh profil" ON public.profiles FOR ALL USING (public.is_admin());
  END IF;
END $$;

-- 10. Atur Row Level Security (RLS) pada tabel promoter_profiles
ALTER TABLE public.promoter_profiles ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'public.promoter_profiles'::regclass AND polname = 'Lihat promoter profile') THEN
    CREATE POLICY "Lihat promoter profile" ON public.promoter_profiles FOR SELECT
      USING (auth.uid() = user_id OR public.is_admin());
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'public.promoter_profiles'::regclass AND polname = 'Tambah promoter profile sendiri') THEN
    CREATE POLICY "Tambah promoter profile sendiri" ON public.promoter_profiles FOR INSERT
      WITH CHECK (auth.uid() = user_id);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'public.promoter_profiles'::regclass AND polname = 'Ubah promoter profile sendiri atau admin') THEN
    CREATE POLICY "Ubah promoter profile sendiri atau admin" ON public.promoter_profiles FOR UPDATE
      USING (auth.uid() = user_id OR public.is_admin())
      WITH CHECK (auth.uid() = user_id OR public.is_admin());
  END IF;
END $$;
