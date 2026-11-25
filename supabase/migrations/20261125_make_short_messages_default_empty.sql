-- ============================================================================
-- LIVE TIX: DEFAULT SHORT_MESSAGES MENJADI KOSONG
-- File: 20261125_make_short_messages_default_empty.sql
--
-- Badge banner kini disimpulkan otomatis oleh AI dari deskripsi konser.
-- Jika deskripsi tidak punya kata kunci menarik, badge dibiarkan kosong.
-- Karena itu default kolom tidak lagi berisi badge contoh.
-- ============================================================================

ALTER TABLE public.concerts
  ALTER COLUMN short_messages SET DEFAULT ARRAY[]::TEXT[];

-- Muat ulang cache schema PostgREST
NOTIFY pgrst, 'reload schema';
