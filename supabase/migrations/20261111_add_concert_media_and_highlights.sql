-- ============================================================================
-- LIVE TIX: MIGRATION PENAMBAHAN KOLOM MEDIA HIGHLIGHTS, LOGO, POSTER & GATES
-- File: 20261111_add_concert_media_and_highlights.sql
-- Jalankan skrip ini di SQL Editor Supabase Console
-- ============================================================================

-- 1. Tambahkan kolom pendukung media, galeri highlights, dan pos gate ke tabel public.concerts
ALTER TABLE public.concerts
  ADD COLUMN IF NOT EXISTS banner_image_url TEXT,
  ADD COLUMN IF NOT EXISTS logo_image_url TEXT,
  ADD COLUMN IF NOT EXISTS square_logo_url TEXT,
  ADD COLUMN IF NOT EXISTS poster_data_url TEXT,
  ADD COLUMN IF NOT EXISTS square_logo_data_url TEXT,
  ADD COLUMN IF NOT EXISTS highlights TEXT[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS highlight_names TEXT[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS gates TEXT[] DEFAULT ARRAY['Gate A (Utama / VIP)', 'Gate B (Festival Barat)', 'Gate C (Tribun Timur)'],
  ADD COLUMN IF NOT EXISTS rejected_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS rejection_reason TEXT,
  ADD COLUMN IF NOT EXISTS cancellation_status TEXT DEFAULT 'none',
  ADD COLUMN IF NOT EXISTS cancellation_category TEXT DEFAULT 'Perizinan',
  ADD COLUMN IF NOT EXISTS cancellation_reason TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS cancellation_date TEXT,
  ADD COLUMN IF NOT EXISTS cancellation_attachment TEXT,
  ADD COLUMN IF NOT EXISTS tickets_sold INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS gross_revenue BIGINT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS is_completed BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS approval_status TEXT NOT NULL DEFAULT 'pending_create';

-- 2. Berikan izin akses kolom ke role authenticated, anon, dan service_role
GRANT ALL ON TABLE public.concerts TO authenticated;
GRANT ALL ON TABLE public.concerts TO anon;
GRANT ALL ON TABLE public.concerts TO service_role;

-- 3. Muat ulang Schema Cache PostgREST Supabase agar kolom baru langsung aktif
NOTIFY pgrst, 'reload schema';
