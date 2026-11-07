-- ============================================================================
-- MIGRASI LENGKAP FITUR PRODUSER, GATE CREW, PIN KEAMANAN, LIKES & LEGALITAS
-- Jalankan di Supabase SQL Editor
-- ============================================================================

-- 1. Pastikan ekstensi pgcrypto tersedia
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 2. Update tabel profiles (Role, PIN 6-Digit, Status Verifikasi & Approval Crew/Produser, Foto Profil)
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS avatar_url TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS pin_code VARCHAR(6) DEFAULT '123456',
  ADD COLUMN IF NOT EXISTS is_verified BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS verification_status TEXT NOT NULL DEFAULT 'approved',
  ADD COLUMN IF NOT EXISTS approval_status TEXT NOT NULL DEFAULT 'approved';

-- Hapus constraint lama terlebih dahulu
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_role_check;

-- Normalisasi baris yang sudah ada di tabel profiles agar tidak ada nilai role yang melanggar constraint
UPDATE public.profiles
SET role = 'User'
WHERE role IS NULL
   OR LOWER(TRIM(role)) NOT IN (
     'user', 'produser', 'producer', 'promoter', 'developer',
     'admin', 'gatecrew', 'gate_crew', 'crew', 'gate crew'
   );

-- Pasang constraint baru menggunakan LOWER(TRIM(role)) agar huruf besar/kecil ('User', 'Produser', 'Admin', 'Gatecrew') semua valid
ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_role_check
  CHECK (
    LOWER(TRIM(role)) IN (
      'user', 'produser', 'producer', 'promoter', 'developer',
      'admin', 'gatecrew', 'gate_crew', 'crew', 'gate crew'
    )
  );

-- 3. Buat / Lengkapi tabel promoter_profiles (Dokumen Legalitas KTP, Lembar Penanggung Jawab, Nama Pending & PIN)
CREATE TABLE IF NOT EXISTS public.promoter_profiles (
  id TEXT PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  company_name TEXT NOT NULL DEFAULT '',
  responsible_name TEXT DEFAULT '',
  pending_name TEXT,
  pending_company_name TEXT,
  business_email TEXT,
  phone TEXT DEFAULT '',
  emergency_phone TEXT,
  address TEXT DEFAULT '',
  office_address TEXT DEFAULT '',
  birth_date TEXT DEFAULT '',
  bank_name TEXT DEFAULT 'Bank Central Asia (BCA)',
  bank_account_number TEXT DEFAULT '',
  bank_account_name TEXT DEFAULT '',
  bank_account_holder TEXT DEFAULT '',
  ktp_url TEXT,
  ktp_file_name TEXT,
  responsibility_letter_url TEXT,
  responsibility_letter_file_name TEXT,
  pending_ktp_url TEXT,
  pending_ktp_file_name TEXT,
  pending_responsibility_letter_url TEXT,
  pending_responsibility_letter_file_name TEXT,
  pin_code VARCHAR(6) DEFAULT '123456',
  verification_tier TEXT NOT NULL DEFAULT 'GOLD',
  is_verified BOOLEAN NOT NULL DEFAULT FALSE,
  profile_change_status TEXT DEFAULT 'none',
  approval_status TEXT NOT NULL DEFAULT 'unverified',
  rejection_reason TEXT,
  submitted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.promoter_profiles
  ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS responsible_name TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS pending_name TEXT,
  ADD COLUMN IF NOT EXISTS pending_company_name TEXT,
  ADD COLUMN IF NOT EXISTS business_email TEXT,
  ADD COLUMN IF NOT EXISTS phone TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS emergency_phone TEXT,
  ADD COLUMN IF NOT EXISTS address TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS office_address TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS birth_date TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS bank_account_holder TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS ktp_url TEXT,
  ADD COLUMN IF NOT EXISTS ktp_file_name TEXT,
  ADD COLUMN IF NOT EXISTS responsibility_letter_url TEXT,
  ADD COLUMN IF NOT EXISTS responsibility_letter_file_name TEXT,
  ADD COLUMN IF NOT EXISTS pending_ktp_url TEXT,
  ADD COLUMN IF NOT EXISTS pending_ktp_file_name TEXT,
  ADD COLUMN IF NOT EXISTS pending_responsibility_letter_url TEXT,
  ADD COLUMN IF NOT EXISTS pending_responsibility_letter_file_name TEXT,
  ADD COLUMN IF NOT EXISTS pin_code VARCHAR(6) DEFAULT '123456',
  ADD COLUMN IF NOT EXISTS verification_tier TEXT NOT NULL DEFAULT 'GOLD',
  ADD COLUMN IF NOT EXISTS is_verified BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS profile_change_status TEXT DEFAULT 'none',
  ADD COLUMN IF NOT EXISTS approval_status TEXT NOT NULL DEFAULT 'unverified',
  ADD COLUMN IF NOT EXISTS rejection_reason TEXT,
  ADD COLUMN IF NOT EXISTS submitted_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

ALTER TABLE public.promoter_profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Promoter profiles viewable by owner and admin" ON public.promoter_profiles;
CREATE POLICY "Promoter profiles viewable by owner and admin"
  ON public.promoter_profiles FOR SELECT USING (true);

DROP POLICY IF EXISTS "Promoter profiles insertable by owner and admin" ON public.promoter_profiles;
CREATE POLICY "Promoter profiles insertable by owner and admin"
  ON public.promoter_profiles FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Promoter profiles updatable by owner and admin" ON public.promoter_profiles;
CREATE POLICY "Promoter profiles updatable by owner and admin"
  ON public.promoter_profiles FOR UPDATE USING (true);

-- 4. Update tabel concerts (Likes/Love, Riwayat Konser Selesai, Pendapatan, Tiket Terjual, Pembatalan, Approval)
ALTER TABLE public.concerts
  ADD COLUMN IF NOT EXISTS producer_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS subtitle TEXT NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS description TEXT NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS venue_address TEXT NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS square_logo_url TEXT,
  ADD COLUMN IF NOT EXISTS banner_image_url TEXT,
  ADD COLUMN IF NOT EXISTS total_capacity INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS likes_count INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS tickets_sold INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS gross_revenue BIGINT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS is_completed BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS approval_status TEXT NOT NULL DEFAULT 'pending_create',
  ADD COLUMN IF NOT EXISTS rejection_reason TEXT,
  ADD COLUMN IF NOT EXISTS cancellation_status TEXT NOT NULL DEFAULT 'none',
  ADD COLUMN IF NOT EXISTS cancellation_reason TEXT,
  ADD COLUMN IF NOT EXISTS cancellation_date TEXT,
  ADD COLUMN IF NOT EXISTS cancellation_attachment TEXT,
  ADD COLUMN IF NOT EXISTS pending_edit_payload JSONB;

-- 5. Buat tabel concert_likes untuk mencatat Like/Love dari User dan otomatis mengupdate concerts.likes_count
CREATE TABLE IF NOT EXISTS public.concert_likes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  concert_id TEXT NOT NULL,
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(concert_id, user_id)
);

ALTER TABLE public.concert_likes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Concert likes readable by everyone" ON public.concert_likes;
CREATE POLICY "Concert likes readable by everyone"
  ON public.concert_likes FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can insert their own concert likes" ON public.concert_likes;
CREATE POLICY "Users can insert their own concert likes"
  ON public.concert_likes FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Users can delete their own concert likes" ON public.concert_likes;
CREATE POLICY "Users can delete their own concert likes"
  ON public.concert_likes FOR DELETE USING (true);

-- Trigger sinkronisasi otomatis jumlah likes di tabel concerts
CREATE OR REPLACE FUNCTION public.sync_concert_likes_count()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF (TG_OP = 'INSERT') THEN
    UPDATE public.concerts
    SET likes_count = COALESCE(likes_count, 0) + 1
    WHERE id::text = NEW.concert_id;
    RETURN NEW;
  ELSIF (TG_OP = 'DELETE') THEN
    UPDATE public.concerts
    SET likes_count = GREATEST(0, COALESCE(likes_count, 0) - 1)
    WHERE id::text = OLD.concert_id;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS on_concert_like_changed ON public.concert_likes;
CREATE TRIGGER on_concert_like_changed
  AFTER INSERT OR DELETE ON public.concert_likes
  FOR EACH ROW EXECUTE FUNCTION public.sync_concert_likes_count();

-- 6. Pastikan tabel concert_gate_crews tersedia untuk Invite Gate Crew ke Konser
CREATE TABLE IF NOT EXISTS public.concert_gate_crews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  concert_id TEXT NOT NULL,
  concert_title TEXT NOT NULL DEFAULT 'Konser LiveTix',
  venue TEXT NOT NULL DEFAULT 'Venue Utama',
  crew_user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  gate_section TEXT NOT NULL DEFAULT 'Gate A (VIP & Reguler)',
  assigned_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(concert_id, crew_user_id)
);

ALTER TABLE public.concert_gate_crews ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Concert gate crews readable by all" ON public.concert_gate_crews;
CREATE POLICY "Concert gate crews readable by all"
  ON public.concert_gate_crews FOR SELECT USING (true);

DROP POLICY IF EXISTS "Concert gate crews manageable by producer and admin" ON public.concert_gate_crews;
CREATE POLICY "Concert gate crews manageable by producer and admin"
  ON public.concert_gate_crews FOR ALL USING (true) WITH CHECK (true);
