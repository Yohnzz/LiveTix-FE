-- Migration: 20261108_gate_crew_migration.sql
-- Migrasi Lengkap Hak Akses & Validasi QR Tiket Role Gate Crew (LiveTix)

-- 1. Pastikan tabel concert_gate_crews lengkap dengan semua kolom penugasan
CREATE TABLE IF NOT EXISTS public.concert_gate_crews (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  concert_id UUID REFERENCES public.concerts(id) ON DELETE CASCADE,
  concert_title TEXT,
  venue TEXT,
  crew_id UUID,
  crew_user_id UUID,
  crew_email TEXT,
  crew_name TEXT,
  gate_name TEXT DEFAULT 'Gate A',
  gate_section TEXT DEFAULT 'Gate A',
  assigned_by UUID,
  assigned_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.concert_gate_crews
  ADD COLUMN IF NOT EXISTS concert_id UUID,
  ADD COLUMN IF NOT EXISTS concert_title TEXT,
  ADD COLUMN IF NOT EXISTS venue TEXT,
  ADD COLUMN IF NOT EXISTS crew_id UUID,
  ADD COLUMN IF NOT EXISTS crew_user_id UUID,
  ADD COLUMN IF NOT EXISTS crew_email TEXT,
  ADD COLUMN IF NOT EXISTS crew_name TEXT,
  ADD COLUMN IF NOT EXISTS gate_name TEXT DEFAULT 'Gate A',
  ADD COLUMN IF NOT EXISTS gate_section TEXT DEFAULT 'Gate A',
  ADD COLUMN IF NOT EXISTS assigned_by UUID,
  ADD COLUMN IF NOT EXISTS assigned_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now());

ALTER TABLE public.concert_gate_crews ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Concert Gate Crews Select All" ON public.concert_gate_crews;
CREATE POLICY "Concert Gate Crews Select All"
  ON public.concert_gate_crews FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "Concert Gate Crews Manage All" ON public.concert_gate_crews;
CREATE POLICY "Concert Gate Crews Manage All"
  ON public.concert_gate_crews FOR ALL
  USING (true)
  WITH CHECK (true);

-- 2. Tabel Pencatatan & Log Check-In Tiket (public.ticket_checkins)
CREATE TABLE IF NOT EXISTS public.ticket_checkins (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  concert_id UUID,
  concert_title TEXT,
  ticket_code TEXT NOT NULL,
  booking_code TEXT,
  attendee_name TEXT,
  category TEXT,
  gate_name TEXT DEFAULT 'Gate A',
  crew_id UUID,
  crew_email TEXT,
  crew_name TEXT,
  scanned_count INTEGER DEFAULT 1,
  quota INTEGER DEFAULT 1,
  status TEXT DEFAULT 'Berhasil',
  notes TEXT,
  checked_in_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.ticket_checkins
  ADD COLUMN IF NOT EXISTS concert_id UUID,
  ADD COLUMN IF NOT EXISTS concert_title TEXT,
  ADD COLUMN IF NOT EXISTS ticket_code TEXT,
  ADD COLUMN IF NOT EXISTS booking_code TEXT,
  ADD COLUMN IF NOT EXISTS attendee_name TEXT,
  ADD COLUMN IF NOT EXISTS category TEXT,
  ADD COLUMN IF NOT EXISTS gate_name TEXT,
  ADD COLUMN IF NOT EXISTS crew_id UUID,
  ADD COLUMN IF NOT EXISTS crew_email TEXT,
  ADD COLUMN IF NOT EXISTS crew_name TEXT,
  ADD COLUMN IF NOT EXISTS scanned_count INTEGER DEFAULT 1,
  ADD COLUMN IF NOT EXISTS quota INTEGER DEFAULT 1,
  ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'Berhasil',
  ADD COLUMN IF NOT EXISTS notes TEXT,
  ADD COLUMN IF NOT EXISTS checked_in_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now());

ALTER TABLE public.ticket_checkins ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Ticket Checkins Select All" ON public.ticket_checkins;
CREATE POLICY "Ticket Checkins Select All"
  ON public.ticket_checkins FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "Ticket Checkins Insert All" ON public.ticket_checkins;
CREATE POLICY "Ticket Checkins Insert All"
  ON public.ticket_checkins FOR INSERT
  WITH CHECK (true);

DROP POLICY IF EXISTS "Ticket Checkins Update All" ON public.ticket_checkins;
CREATE POLICY "Ticket Checkins Update All"
  ON public.ticket_checkins FOR UPDATE
  USING (true)
  WITH CHECK (true);

