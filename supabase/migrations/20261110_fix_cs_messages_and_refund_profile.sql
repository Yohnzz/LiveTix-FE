-- ============================================================
-- MIGRATION: 20261110_fix_cs_messages_and_refund_profile.sql
-- PERBAIKAN:
-- 1. Dukung kolom is_from_admin dan is_admin_reply pada cs_messages
-- 2. Tambah sender_id pada cs_messages
-- 3. Tambah kolom refund_account pada profiles untuk sinkronisasi cloud
-- ============================================================

-- 1. Tabel Customer Service Messages (public.cs_messages)
ALTER TABLE public.cs_messages ADD COLUMN IF NOT EXISTS is_admin_reply BOOLEAN DEFAULT FALSE;
ALTER TABLE public.cs_messages ADD COLUMN IF NOT EXISTS is_from_admin BOOLEAN DEFAULT FALSE;
ALTER TABLE public.cs_messages ADD COLUMN IF NOT EXISTS sender_id TEXT;

-- 2. Kolom Rekening Refund pada public.profiles
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS refund_bank_name TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS refund_account_number TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS refund_account_name TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS refund_account_type TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS refund_last_updated TIMESTAMPTZ;

-- 3. RLS Pastikan cs_messages dapat diakses dengan aman
DROP POLICY IF EXISTS "CS Messages Select All" ON public.cs_messages;
CREATE POLICY "CS Messages Select All" ON public.cs_messages FOR SELECT USING (true);

DROP POLICY IF EXISTS "CS Messages Insert All" ON public.cs_messages;
CREATE POLICY "CS Messages Insert All" ON public.cs_messages FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "CS Messages Update All" ON public.cs_messages;
CREATE POLICY "CS Messages Update All" ON public.cs_messages FOR UPDATE USING (true) WITH CHECK (true);

