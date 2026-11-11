-- =================================================================================
-- MIGRASI LENGKAP FITUR ADMIN, APPROVAL PRODUSER, KONSER (TAMBAH/EDIT/HAPUS),
-- EDIT NAMA PRODUSER, DAN APPROVAL GATE CREW (SUPABASE)
-- =================================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 1. Pastikan seluruh kolom yang dibutuhkan ada pada tabel public.profiles
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS name TEXT,
  ADD COLUMN IF NOT EXISTS full_name TEXT,
  ADD COLUMN IF NOT EXISTS email TEXT,
  ADD COLUMN IF NOT EXISTS phone TEXT,
  ADD COLUMN IF NOT EXISTS avatar_url TEXT,
  ADD COLUMN IF NOT EXISTS role TEXT DEFAULT 'User',
  ADD COLUMN IF NOT EXISTS pin_code TEXT,
  ADD COLUMN IF NOT EXISTS is_verified BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS verification_status TEXT DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS approval_status TEXT DEFAULT 'approved',
  ADD COLUMN IF NOT EXISTS ktp_url TEXT,
  ADD COLUMN IF NOT EXISTS responsibility_letter_url TEXT,
  ADD COLUMN IF NOT EXISTS pending_name TEXT,
  ADD COLUMN IF NOT EXISTS pending_ktp_url TEXT,
  ADD COLUMN IF NOT EXISTS pending_responsibility_letter_url TEXT,
  ADD COLUMN IF NOT EXISTS profile_change_status TEXT DEFAULT 'none',
  ADD COLUMN IF NOT EXISTS rejection_reason TEXT,
  ADD COLUMN IF NOT EXISTS rejected_at TIMESTAMP WITH TIME ZONE,
  ADD COLUMN IF NOT EXISTS producer_id TEXT,
  ADD COLUMN IF NOT EXISTS producer_name TEXT,
  ADD COLUMN IF NOT EXISTS producer_email TEXT,
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now());

-- Pastikan constraint role pada public.profiles mendukung semua variasi huruf
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_role_check;
UPDATE public.profiles
SET role = 'User'
WHERE role IS NULL
   OR lower(trim(role)) NOT IN ('user', 'produser', 'producer', 'promoter', 'admin', 'gatecrew', 'gate_crew', 'crew');

ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_role_check
  CHECK (
    lower(trim(role)) IN (
      'user', 'produser', 'producer', 'promoter', 'admin', 'gatecrew', 'gate_crew', 'crew'
    )
  );

-- 2. Pastikan tabel public.promoter_profiles beserta seluruh kolomnya tersedia
CREATE TABLE IF NOT EXISTS public.promoter_profiles (
  id UUID PRIMARY KEY,
  company_name TEXT DEFAULT '',
  email TEXT DEFAULT '',
  phone TEXT DEFAULT '-',
  responsible_name TEXT DEFAULT '',
  location TEXT DEFAULT 'Indonesia',
  description TEXT DEFAULT '',
  avatar_url TEXT,
  banner_url TEXT,
  ktp_image_url TEXT,
  responsibility_letter_url TEXT,
  pin_code TEXT,
  is_verified BOOLEAN DEFAULT FALSE,
  approval_status TEXT DEFAULT 'pending',
  rejection_reason TEXT,
  pending_name TEXT,
  pending_ktp_url TEXT,
  pending_responsibility_letter_url TEXT,
  profile_change_status TEXT DEFAULT 'none',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- Tambahkan semua kolom pada promoter_profiles apabila tabel sudah ada sebelumnya dengan skema lama
ALTER TABLE public.promoter_profiles
  ADD COLUMN IF NOT EXISTS user_id UUID,
  ADD COLUMN IF NOT EXISTS company_name TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS email TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS phone TEXT DEFAULT '-',
  ADD COLUMN IF NOT EXISTS responsible_name TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS location TEXT DEFAULT 'Indonesia',
  ADD COLUMN IF NOT EXISTS description TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS avatar_url TEXT,
  ADD COLUMN IF NOT EXISTS banner_url TEXT,
  ADD COLUMN IF NOT EXISTS ktp_image_url TEXT,
  ADD COLUMN IF NOT EXISTS responsibility_letter_url TEXT,
  ADD COLUMN IF NOT EXISTS pin_code TEXT,
  ADD COLUMN IF NOT EXISTS is_verified BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS approval_status TEXT DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS rejection_reason TEXT,
  ADD COLUMN IF NOT EXISTS rejected_at TIMESTAMP WITH TIME ZONE,
  ADD COLUMN IF NOT EXISTS pending_name TEXT,
  ADD COLUMN IF NOT EXISTS pending_ktp_url TEXT,
  ADD COLUMN IF NOT EXISTS pending_responsibility_letter_url TEXT,
  ADD COLUMN IF NOT EXISTS profile_change_status TEXT DEFAULT 'none',
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now());

-- Jika kolom user_id di promoter_profiles memiliki constraint NOT NULL dari skema lama, lepaskan NOT NULL-nya
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'promoter_profiles'
      AND column_name = 'user_id'
  ) THEN
    ALTER TABLE public.promoter_profiles ALTER COLUMN user_id DROP NOT NULL;
  END IF;
END $$;

-- Sinkronkan akun Produser yang sudah ada di public.profiles ke public.promoter_profiles
INSERT INTO public.promoter_profiles (
  id, user_id, company_name, email, phone, responsible_name, is_verified, approval_status
)
SELECT
  p.id,
  p.id,
  COALESCE(p.name, p.full_name, split_part(p.email, '@', 1), 'Produser LiveTix'),
  COALESCE(p.email, ''),
  COALESCE(p.phone, '-'),
  COALESCE(p.full_name, p.name, 'Penanggung Jawab'),
  COALESCE(p.is_verified, FALSE),
  COALESCE(p.approval_status, 'pending')
FROM public.profiles p
WHERE lower(trim(p.role)) IN ('produser', 'producer', 'promoter')
ON CONFLICT (id) DO UPDATE SET
  email = COALESCE(NULLIF(public.promoter_profiles.email, ''), EXCLUDED.email),
  company_name = COALESCE(NULLIF(public.promoter_profiles.company_name, ''), EXCLUDED.company_name),
  phone = COALESCE(NULLIF(public.promoter_profiles.phone, '-'), EXCLUDED.phone),
  responsible_name = COALESCE(NULLIF(public.promoter_profiles.responsible_name, ''), EXCLUDED.responsible_name);

-- 3. Pastikan tabel public.concerts dan public.ticket_tiers memiliki seluruh kolom yang dibutuhkan
ALTER TABLE public.concerts
  ADD COLUMN IF NOT EXISTS producer_id UUID,
  ADD COLUMN IF NOT EXISTS producer_name TEXT DEFAULT 'Produser LiveTix',
  ADD COLUMN IF NOT EXISTS title TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS subtitle TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS description TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS date TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS time TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS venue TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS venue_address TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS price BIGINT DEFAULT 0,
  ADD COLUMN IF NOT EXISTS category TEXT DEFAULT 'Pop',
  ADD COLUMN IF NOT EXISTS tag TEXT DEFAULT 'Musik',
  ADD COLUMN IF NOT EXISTS banner_image_url TEXT,
  ADD COLUMN IF NOT EXISTS logo_image_url TEXT,
  ADD COLUMN IF NOT EXISTS square_logo_url TEXT,
  ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS approval_status TEXT DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS total_capacity INTEGER DEFAULT 1000,
  ADD COLUMN IF NOT EXISTS likes_count INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS tickets_sold INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS gross_revenue BIGINT DEFAULT 0,
  ADD COLUMN IF NOT EXISTS is_completed BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS pending_edit_payload JSONB,
  ADD COLUMN IF NOT EXISTS rejection_reason TEXT,
  ADD COLUMN IF NOT EXISTS rejected_at TIMESTAMP WITH TIME ZONE,
  ADD COLUMN IF NOT EXISTS cancellation_reason TEXT,
  ADD COLUMN IF NOT EXISTS cancellation_date TEXT,
  ADD COLUMN IF NOT EXISTS cancellation_attachment TEXT,
  ADD COLUMN IF NOT EXISTS cancellation_status TEXT DEFAULT 'none',
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now());

ALTER TABLE public.ticket_tiers
  ADD COLUMN IF NOT EXISTS concert_id UUID,
  ADD COLUMN IF NOT EXISTS name TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS description TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS price BIGINT DEFAULT 0,
  ADD COLUMN IF NOT EXISTS quota INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS total_quota INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS remaining_quota INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS benefits TEXT[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now());

-- 4. Pastikan tabel public.concert_gate_crews mendukung kolom crew_id / crew_user_id dan gate_name / gate_section
CREATE TABLE IF NOT EXISTS public.concert_gate_crews (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  concert_id UUID REFERENCES public.concerts(id) ON DELETE CASCADE,
  crew_id UUID,
  crew_user_id UUID,
  crew_email TEXT,
  gate_name TEXT DEFAULT 'Gate A (Utama)',
  gate_section TEXT DEFAULT 'Gate A (Utama)',
  assigned_by UUID,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.concert_gate_crews
  ADD COLUMN IF NOT EXISTS crew_id UUID,
  ADD COLUMN IF NOT EXISTS crew_user_id UUID,
  ADD COLUMN IF NOT EXISTS crew_email TEXT,
  ADD COLUMN IF NOT EXISTS gate_name TEXT DEFAULT 'Gate A (Utama)',
  ADD COLUMN IF NOT EXISTS gate_section TEXT DEFAULT 'Gate A (Utama)',
  ADD COLUMN IF NOT EXISTS assigned_by UUID,
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now());

-- 5. Fungsi Helper public.is_admin() untuk pengecekan hak akses Super Admin
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.profiles
    WHERE id = auth.uid()
      AND lower(trim(role)) = 'admin'
  )
  OR lower(coalesce(auth.jwt() ->> 'email', '')) IN ('admin1@gmail.com', 'admin@livetix.com', 'admin@soundwave.com');
$$;

-- 6. Fungsi RPC public.upsert_gate_crew_account untuk Tambah & Approval Gate Crew (oleh Produser / Admin)
-- Membuat akun langsung di auth.users (password default: crewgate123) sekaligus di public.profiles
CREATE OR REPLACE FUNCTION public.upsert_gate_crew_account(
  p_email TEXT,
  p_name TEXT DEFAULT NULL,
  p_phone TEXT DEFAULT '-',
  p_approval_status TEXT DEFAULT 'pending',
  p_password TEXT DEFAULT 'crewgate123'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
  v_clean_email TEXT := lower(trim(p_email));
  v_user_id UUID;
  v_display_name TEXT;
  v_instance_id UUID;
BEGIN
  IF v_clean_email = '' THEN
    RAISE EXCEPTION 'Email Gate Crew tidak boleh kosong';
  END IF;

  v_display_name := COALESCE(NULLIF(trim(p_name), ''), split_part(v_clean_email, '@', 1));

  SELECT id INTO v_user_id
  FROM auth.users
  WHERE lower(email) = v_clean_email
  LIMIT 1;

  IF v_user_id IS NULL THEN
    SELECT id INTO v_user_id
    FROM public.profiles
    WHERE lower(email) = v_clean_email
    LIMIT 1;
  END IF;

  IF v_user_id IS NULL THEN
    v_user_id := gen_random_uuid();
    SELECT COALESCE(
      (SELECT instance_id FROM auth.users LIMIT 1),
      '00000000-0000-0000-0000-000000000000'::uuid
    ) INTO v_instance_id;

    INSERT INTO auth.users (
      instance_id,
      id,
      aud,
      role,
      email,
      encrypted_password,
      email_confirmed_at,
      raw_app_meta_data,
      raw_user_meta_data,
      created_at,
      updated_at,
      confirmation_token,
      email_change,
      email_change_token_new,
      recovery_token
    ) VALUES (
      v_instance_id,
      v_user_id,
      'authenticated',
      'authenticated',
      v_clean_email,
      crypt(COALESCE(NULLIF(p_password, ''), 'crewgate123'), gen_salt('bf')),
      now(),
      '{"provider":"email","providers":["email"]}'::jsonb,
      jsonb_build_object(
        'name', v_display_name,
        'full_name', v_display_name,
        'role', 'Gatecrew'
      ),
      now(),
      now(),
      '',
      '',
      '',
      ''
    );

    INSERT INTO auth.identities (
      id,
      user_id,
      provider_id,
      identity_data,
      provider,
      last_sign_in_at,
      created_at,
      updated_at
    ) VALUES (
      gen_random_uuid(),
      v_user_id,
      v_user_id::text,
      jsonb_build_object(
        'sub', v_user_id::text,
        'email', v_clean_email,
        'email_verified', true
      ),
      'email',
      now(),
      now(),
      now()
    ) ON CONFLICT DO NOTHING;
  END IF;

  INSERT INTO public.profiles (
    id,
    email,
    name,
    full_name,
    phone,
    role,
    is_verified,
    verification_status,
    approval_status
  ) VALUES (
    v_user_id,
    v_clean_email,
    v_display_name,
    v_display_name,
    COALESCE(p_phone, '-'),
    'Gatecrew',
    (lower(p_approval_status) = 'approved'),
    lower(p_approval_status),
    lower(p_approval_status)
  )
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    name = COALESCE(NULLIF(EXCLUDED.name, ''), public.profiles.name),
    full_name = COALESCE(NULLIF(EXCLUDED.full_name, ''), public.profiles.full_name),
    phone = COALESCE(NULLIF(EXCLUDED.phone, '-'), public.profiles.phone),
    role = 'Gatecrew',
    is_verified = (lower(p_approval_status) = 'approved'),
    verification_status = lower(p_approval_status),
    approval_status = lower(p_approval_status);

  RETURN jsonb_build_object(
    'id', v_user_id,
    'email', v_clean_email,
    'name', v_display_name,
    'phone', COALESCE(p_phone, '-'),
    'approval_status', lower(p_approval_status)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.upsert_gate_crew_account(TEXT, TEXT, TEXT, TEXT, TEXT) TO anon, authenticated;

-- 7. Kebijakan Row Level Security (RLS) agar Admin & Role Terkait Memiliki Akses Penuh ke Database
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.promoter_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.concerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ticket_tiers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.concert_gate_crews ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Profiles Select All" ON public.profiles;
CREATE POLICY "Profiles Select All"
  ON public.profiles FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "Profiles Insert Authenticated Or Admin" ON public.profiles;
CREATE POLICY "Profiles Insert Authenticated Or Admin"
  ON public.profiles FOR INSERT
  WITH CHECK (true);

DROP POLICY IF EXISTS "Profiles Update Self Or Admin" ON public.profiles;
CREATE POLICY "Profiles Update Self Or Admin"
  ON public.profiles FOR UPDATE
  USING (auth.uid() = id OR public.is_admin() OR auth.role() = 'authenticated')
  WITH CHECK (auth.uid() = id OR public.is_admin() OR auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Profiles Delete Admin" ON public.profiles;
CREATE POLICY "Profiles Delete Admin"
  ON public.profiles FOR DELETE
  USING (public.is_admin());

DROP POLICY IF EXISTS "Promoter Profiles Select All" ON public.promoter_profiles;
CREATE POLICY "Promoter Profiles Select All"
  ON public.promoter_profiles FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "Promoter Profiles Insert All" ON public.promoter_profiles;
CREATE POLICY "Promoter Profiles Insert All"
  ON public.promoter_profiles FOR INSERT
  WITH CHECK (true);

DROP POLICY IF EXISTS "Promoter Profiles Update Owner Or Admin" ON public.promoter_profiles;
CREATE POLICY "Promoter Profiles Update Owner Or Admin"
  ON public.promoter_profiles FOR UPDATE
  USING (auth.uid() = id OR public.is_admin() OR auth.role() = 'authenticated')
  WITH CHECK (auth.uid() = id OR public.is_admin() OR auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Promoter Profiles Delete Admin" ON public.promoter_profiles;
CREATE POLICY "Promoter Profiles Delete Admin"
  ON public.promoter_profiles FOR DELETE
  USING (public.is_admin());

DROP POLICY IF EXISTS "Public Concerts Viewable" ON public.concerts;
DROP POLICY IF EXISTS "Concerts Select All" ON public.concerts;
CREATE POLICY "Concerts Select All"
  ON public.concerts FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "Promoters Can Insert Concerts" ON public.concerts;
DROP POLICY IF EXISTS "Concerts Insert Producer Or Admin" ON public.concerts;
CREATE POLICY "Concerts Insert Producer Or Admin"
  ON public.concerts FOR INSERT
  WITH CHECK (true);

DROP POLICY IF EXISTS "Admin Can Update Concerts" ON public.concerts;
DROP POLICY IF EXISTS "Concerts Update Producer Or Admin" ON public.concerts;
CREATE POLICY "Concerts Update Producer Or Admin"
  ON public.concerts FOR UPDATE
  USING (true)
  WITH CHECK (true);

DROP POLICY IF EXISTS "Concerts Delete Producer Or Admin" ON public.concerts;
CREATE POLICY "Concerts Delete Producer Or Admin"
  ON public.concerts FOR DELETE
  USING (true);

DROP POLICY IF EXISTS "Public Tiers Viewable" ON public.ticket_tiers;
DROP POLICY IF EXISTS "Ticket Tiers Select All" ON public.ticket_tiers;
CREATE POLICY "Ticket Tiers Select All"
  ON public.ticket_tiers FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "Promoters Can Insert Tiers" ON public.ticket_tiers;
DROP POLICY IF EXISTS "Ticket Tiers Insert All" ON public.ticket_tiers;
CREATE POLICY "Ticket Tiers Insert All"
  ON public.ticket_tiers FOR INSERT
  WITH CHECK (true);

DROP POLICY IF EXISTS "Ticket Tiers Update All" ON public.ticket_tiers;
CREATE POLICY "Ticket Tiers Update All"
  ON public.ticket_tiers FOR UPDATE
  USING (true)
  WITH CHECK (true);

DROP POLICY IF EXISTS "Ticket Tiers Delete All" ON public.ticket_tiers;
CREATE POLICY "Ticket Tiers Delete All"
  ON public.ticket_tiers FOR DELETE
  USING (true);

DROP POLICY IF EXISTS "Concert Gate Crews Select All" ON public.concert_gate_crews;
CREATE POLICY "Concert Gate Crews Select All"
  ON public.concert_gate_crews FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "Concert Gate Crews Manage All" ON public.concert_gate_crews;
CREATE POLICY "Concert Gate Crews Manage All"
  ON public.concert_gate_crews FOR ALL
  USING (true)
  WITH CHECK (true);

-- 8. Tabel Customer Service Messages (public.cs_messages)
CREATE TABLE IF NOT EXISTS public.cs_messages (
  id TEXT PRIMARY KEY,
  thread_id TEXT NOT NULL,
  sender_role TEXT NOT NULL,
  sender_name TEXT NOT NULL,
  sender_email TEXT NOT NULL,
  message TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
  is_admin_reply BOOLEAN DEFAULT FALSE,
  status TEXT DEFAULT 'sent'
);

ALTER TABLE public.cs_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "CS Messages Select All" ON public.cs_messages;
CREATE POLICY "CS Messages Select All" ON public.cs_messages FOR SELECT USING (true);

DROP POLICY IF EXISTS "CS Messages Insert All" ON public.cs_messages;
CREATE POLICY "CS Messages Insert All" ON public.cs_messages FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "CS Messages Update All" ON public.cs_messages;
CREATE POLICY "CS Messages Update All" ON public.cs_messages FOR UPDATE USING (true) WITH CHECK (true);

-- 9. Tabel Validasi Check-In Tiket Gate Crew (public.ticket_checkins)
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
CREATE POLICY "Ticket Checkins Select All" ON public.ticket_checkins FOR SELECT USING (true);

DROP POLICY IF EXISTS "Ticket Checkins Insert All" ON public.ticket_checkins;
CREATE POLICY "Ticket Checkins Insert All" ON public.ticket_checkins FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Ticket Checkins Update All" ON public.ticket_checkins;
CREATE POLICY "Ticket Checkins Update All" ON public.ticket_checkins FOR UPDATE USING (true) WITH CHECK (true);
