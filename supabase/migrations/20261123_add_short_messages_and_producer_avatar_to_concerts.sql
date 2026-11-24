-- ============================================================================
-- LIVE TIX: MIGRATION PENAMBAHAN KOLOM SHORT_MESSAGES & PRODUCER_AVATAR_URL
-- File: 20261123_add_short_messages_and_producer_avatar_to_concerts.sql
-- ============================================================================

-- 1. Tambahkan kolom short_messages dan producer_avatar_url ke public.concerts
ALTER TABLE public.concerts
  ADD COLUMN IF NOT EXISTS short_messages TEXT[] DEFAULT ARRAY['Festival • 17+', 'Seru!'],
  ADD COLUMN IF NOT EXISTS producer_avatar_url TEXT;

-- 2. Pastikan permission diberikan
GRANT ALL ON TABLE public.concerts TO authenticated;
GRANT ALL ON TABLE public.concerts TO anon;
GRANT ALL ON TABLE public.concerts TO service_role;

-- 3. Muat ulang cache schema PostgREST
NOTIFY pgrst, 'reload schema';
