-- ============================================================================
-- LIVE TIX: MIGRATION VERIFIKASI USER (NIK), PRODUSER (REKENING & PIN),
-- DAN PERBAIKAN PERSISTENSI TAMBAH KONSER
-- File: 20261111_verification_and_concert_fix.sql
-- Jalankan skrip ini di SQL Editor Supabase Console
-- ============================================================================

-- 1. Kolom verifikasi pada public.profiles (NIK, status verifikasi, rekening, PIN)
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS nik TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS is_verified BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS verification_status TEXT DEFAULT 'unverified',
  ADD COLUMN IF NOT EXISTS approval_status TEXT DEFAULT 'unverified',
  ADD COLUMN IF NOT EXISTS birth_date TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS address TEXT DEFAULT '',
  -- PIN hanya dimiliki role Produser; role lain menyimpan NULL.
  ADD COLUMN IF NOT EXISTS pin_code TEXT,
  ADD COLUMN IF NOT EXISTS bank_name TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS bank_account_number TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS bank_account_name TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS bank_account_holder TEXT DEFAULT '';

ALTER TABLE public.profiles
  ALTER COLUMN is_verified SET DEFAULT FALSE,
  ALTER COLUMN verification_status SET DEFAULT 'unverified',
  ALTER COLUMN approval_status SET DEFAULT 'unverified',
  ALTER COLUMN pin_code DROP DEFAULT,
  -- Pastikan cukup menampung hash SHA-256 (bila sebelumnya VARCHAR(6)).
  ALTER COLUMN pin_code TYPE TEXT;

-- 2. Pastikan tabel & kolom public.promoter_profiles lengkap
CREATE TABLE IF NOT EXISTS public.promoter_profiles (
  id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  user_id TEXT,
  full_name TEXT DEFAULT '',
  company_name TEXT DEFAULT '',
  birth_date TEXT DEFAULT '',
  phone TEXT DEFAULT '',
  address TEXT DEFAULT '',
  ktp_url TEXT DEFAULT '',
  responsibility_letter_url TEXT DEFAULT '',
  pin_code TEXT,
  pin TEXT,
  bank_name TEXT DEFAULT '',
  bank_account_number TEXT DEFAULT '',
  bank_account_name TEXT DEFAULT '',
  bank_account_holder TEXT DEFAULT '',
  is_verified BOOLEAN NOT NULL DEFAULT FALSE,
  verification_status TEXT DEFAULT 'unverified',
  approval_status TEXT DEFAULT 'unverified',
  quota_remaining INT NOT NULL DEFAULT 3,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.promoter_profiles
  ADD COLUMN IF NOT EXISTS user_id TEXT,
  ADD COLUMN IF NOT EXISTS full_name TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS company_name TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS birth_date TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS phone TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS address TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS ktp_url TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS responsibility_letter_url TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS pin_code TEXT,
  ADD COLUMN IF NOT EXISTS pin TEXT,
  ADD COLUMN IF NOT EXISTS bank_name TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS bank_account_number TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS bank_account_name TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS bank_account_holder TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS is_verified BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS verification_status TEXT DEFAULT 'unverified',
  ADD COLUMN IF NOT EXISTS approval_status TEXT DEFAULT 'unverified',
  ADD COLUMN IF NOT EXISTS quota_remaining INT NOT NULL DEFAULT 3,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

-- PIN Produser tidak boleh punya nilai default; role lain disimpan NULL.
ALTER TABLE public.promoter_profiles
  ALTER COLUMN pin_code DROP DEFAULT,
  ALTER COLUMN pin DROP DEFAULT,
  -- Pastikan cukup menampung hash SHA-256 (bila sebelumnya VARCHAR(6)).
  ALTER COLUMN pin_code TYPE TEXT,
  ALTER COLUMN pin TYPE TEXT;

-- 3. Backfill status verifikasi User (wajib isi NIK + nama lengkap jika belum)
UPDATE public.profiles
SET
  is_verified = CASE
    WHEN LOWER(COALESCE(role, 'user')) IN ('admin', 'gatecrew', 'gate_crew', 'crew') THEN TRUE
    WHEN LOWER(COALESCE(role, 'user')) = 'user'
         AND LENGTH(REGEXP_REPLACE(COALESCE(nik, ''), '[^0-9]', '', 'g')) >= 16
         AND NULLIF(TRIM(COALESCE(name, full_name, '')), '') IS NOT NULL THEN TRUE
    ELSE FALSE
  END,
  verification_status = CASE
    WHEN LOWER(COALESCE(role, 'user')) IN ('admin', 'gatecrew', 'gate_crew', 'crew') THEN 'approved'
    WHEN LOWER(COALESCE(role, 'user')) = 'user'
         AND LENGTH(REGEXP_REPLACE(COALESCE(nik, ''), '[^0-9]', '', 'g')) >= 16
         AND NULLIF(TRIM(COALESCE(name, full_name, '')), '') IS NOT NULL THEN 'approved'
    ELSE 'unverified'
  END,
  approval_status = CASE
    WHEN LOWER(COALESCE(role, 'user')) IN ('admin', 'gatecrew', 'gate_crew', 'crew') THEN 'approved'
    WHEN LOWER(COALESCE(role, 'user')) = 'user'
         AND LENGTH(REGEXP_REPLACE(COALESCE(nik, ''), '[^0-9]', '', 'g')) >= 16
         AND NULLIF(TRIM(COALESCE(name, full_name, '')), '') IS NOT NULL THEN 'approved'
    ELSE 'unverified'
  END
WHERE LOWER(COALESCE(role, 'user')) IN ('user', 'admin', 'gatecrew', 'gate_crew', 'crew');

-- Sync Produser existing: terverifikasi hanya jika sudah memiliki nomor rekening & PIN
UPDATE public.profiles p
SET
  is_verified = (
    COALESCE(NULLIF(TRIM(p.bank_account_number), ''), NULLIF(TRIM(pr.bank_account_number), '')) IS NOT NULL
    AND COALESCE(NULLIF(TRIM(p.pin_code), ''), NULLIF(TRIM(pr.pin_code), ''), NULLIF(TRIM(pr.pin), '')) IS NOT NULL
  ),
  verification_status = CASE
    WHEN LOWER(COALESCE(pr.verification_status, p.verification_status, '')) IN ('rejected', 'deactivated') THEN LOWER(COALESCE(pr.verification_status, p.verification_status))
    WHEN COALESCE(NULLIF(TRIM(p.bank_account_number), ''), NULLIF(TRIM(pr.bank_account_number), '')) IS NOT NULL
         AND COALESCE(NULLIF(TRIM(p.pin_code), ''), NULLIF(TRIM(pr.pin_code), ''), NULLIF(TRIM(pr.pin), '')) IS NOT NULL THEN 'approved'
    ELSE 'unverified'
  END,
  approval_status = CASE
    WHEN LOWER(COALESCE(pr.approval_status, p.approval_status, '')) IN ('rejected', 'deactivated') THEN LOWER(COALESCE(pr.approval_status, p.approval_status))
    WHEN COALESCE(NULLIF(TRIM(p.bank_account_number), ''), NULLIF(TRIM(pr.bank_account_number), '')) IS NOT NULL
         AND COALESCE(NULLIF(TRIM(p.pin_code), ''), NULLIF(TRIM(pr.pin_code), ''), NULLIF(TRIM(pr.pin), '')) IS NOT NULL THEN 'approved'
    ELSE 'unverified'
  END
FROM public.promoter_profiles pr
WHERE LOWER(COALESCE(p.role, '')) IN ('produser', 'producer', 'promoter')
  AND (pr.id::text = p.id::text OR COALESCE(pr.user_id::text, '') = p.id::text);

-- Produser yang belum punya row promoter_profiles dianggap unverified bila belum lengkap rekening+PIN
UPDATE public.profiles
SET
  is_verified = CASE
    WHEN NULLIF(TRIM(COALESCE(bank_account_number, '')), '') IS NOT NULL
         AND NULLIF(TRIM(COALESCE(pin_code, '')), '') IS NOT NULL THEN TRUE
    ELSE FALSE
  END,
  verification_status = CASE
    WHEN NULLIF(TRIM(COALESCE(bank_account_number, '')), '') IS NOT NULL
         AND NULLIF(TRIM(COALESCE(pin_code, '')), '') IS NOT NULL THEN 'approved'
    ELSE 'unverified'
  END,
  approval_status = CASE
    WHEN NULLIF(TRIM(COALESCE(bank_account_number, '')), '') IS NOT NULL
         AND NULLIF(TRIM(COALESCE(pin_code, '')), '') IS NOT NULL THEN 'approved'
    ELSE 'unverified'
  END
WHERE LOWER(COALESCE(role, '')) IN ('produser', 'producer', 'promoter')
  AND NOT EXISTS (
    SELECT 1 FROM public.promoter_profiles pr
    WHERE pr.id::text = public.profiles.id::text
      OR COALESCE(pr.user_id::text, '') = public.profiles.id::text
  );

-- 3b. Hanya Produser yang boleh menyimpan PIN; role lain disimpan NULL.
UPDATE public.profiles SET pin_code = NULL
WHERE LOWER(COALESCE(role, '')) NOT IN ('produser', 'producer', 'promoter');

UPDATE public.profiles SET pin_code = NULL WHERE TRIM(COALESCE(pin_code, '')) = '';
UPDATE public.promoter_profiles SET pin_code = NULL WHERE TRIM(COALESCE(pin_code, '')) = '';
UPDATE public.promoter_profiles SET pin = NULL WHERE TRIM(COALESCE(pin, '')) = '';

-- 3c. Hash PIN Produser lama yang masih plaintext agar konsisten dengan aplikasi.
-- Format sama dengan Dart: 'sha256:' + SHA-256('livetix::pin::v1::' + PIN) dalam hex.
-- Bila pgcrypto tidak tersedia, blok dilewati dan PIN akan di-hash ulang saat login.
DO $$
BEGIN
  UPDATE public.profiles
  SET pin_code = 'sha256:' || encode(digest('livetix::pin::v1::' || pin_code, 'sha256'), 'hex')
  WHERE pin_code IS NOT NULL
    AND TRIM(pin_code) <> ''
    AND pin_code NOT LIKE 'sha256:%'
    AND LOWER(COALESCE(role, '')) IN ('produser', 'producer', 'promoter');

  UPDATE public.promoter_profiles
  SET pin_code = 'sha256:' || encode(digest('livetix::pin::v1::' || pin_code, 'sha256'), 'hex')
  WHERE pin_code IS NOT NULL
    AND TRIM(pin_code) <> ''
    AND pin_code NOT LIKE 'sha256:%';

  UPDATE public.promoter_profiles
  SET pin = 'sha256:' || encode(digest('livetix::pin::v1::' || pin, 'sha256'), 'hex')
  WHERE pin IS NOT NULL
    AND TRIM(pin) <> ''
    AND pin NOT LIKE 'sha256:%';
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'Hash PIN lama dilewati: %', SQLERRM;
END $$;

-- 4. Perbarui trigger handle_new_user agar akun baru tidak otomatis bypass verifikasi
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_raw_role TEXT;
  v_role TEXT;
  v_name TEXT;
  v_phone TEXT;
  v_nik TEXT;
  v_pin TEXT;
  v_bank_no TEXT;
  v_is_verified BOOLEAN := FALSE;
  v_status TEXT := 'unverified';
BEGIN
  v_raw_role := LOWER(TRIM(COALESCE(new.raw_user_meta_data->>'role', 'User')));
  IF v_raw_role = 'admin' THEN
    v_role := 'Admin';
  ELSIF v_raw_role IN ('produser', 'producer', 'developer', 'promoter') THEN
    v_role := 'Produser';
  ELSIF v_raw_role IN ('gatecrew', 'gate_crew', 'crew', 'gate crew') THEN
    v_role := 'Gatecrew';
  ELSE
    v_role := 'User';
  END IF;

  v_name := COALESCE(
    NULLIF(TRIM(new.raw_user_meta_data->>'name'), ''),
    NULLIF(TRIM(new.raw_user_meta_data->>'full_name'), ''),
    SPLIT_PART(COALESCE(new.email, 'user'), '@', 1)
  );
  v_phone := COALESCE(new.raw_user_meta_data->>'phone', '');
  v_nik := COALESCE(new.raw_user_meta_data->>'nik', '');
  v_pin := COALESCE(new.raw_user_meta_data->>'pin_code', '');
  v_bank_no := COALESCE(new.raw_user_meta_data->>'bank_account_number', '');

  IF v_role IN ('Admin', 'Gatecrew') THEN
    v_is_verified := TRUE;
    v_status := 'approved';
  ELSIF v_role = 'User' THEN
    IF LENGTH(REGEXP_REPLACE(v_nik, '[^0-9]', '', 'g')) >= 16 AND NULLIF(TRIM(v_name), '') IS NOT NULL THEN
      v_is_verified := TRUE;
      v_status := 'approved';
    END IF;
  ELSIF v_role = 'Produser' THEN
    IF NULLIF(TRIM(v_bank_no), '') IS NOT NULL AND NULLIF(TRIM(v_pin), '') IS NOT NULL THEN
      v_is_verified := TRUE;
      v_status := 'approved';
    END IF;
  END IF;

  INSERT INTO public.profiles (
    id, email, name, full_name, phone, role, nik,
    is_verified, verification_status, approval_status, updated_at
  )
  VALUES (
    new.id, new.email, v_name, v_name, v_phone, v_role, v_nik,
    v_is_verified, v_status, v_status, NOW()
  )
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    name = COALESCE(NULLIF(public.profiles.name, ''), EXCLUDED.name),
    full_name = COALESCE(NULLIF(public.profiles.full_name, ''), EXCLUDED.full_name),
    phone = COALESCE(NULLIF(public.profiles.phone, ''), EXCLUDED.phone),
    role = COALESCE(NULLIF(public.profiles.role, ''), EXCLUDED.role),
    updated_at = NOW();

  IF v_role = 'Produser' THEN
    BEGIN
      INSERT INTO public.promoter_profiles (
        id, user_id, full_name, company_name, phone,
        is_verified, verification_status, approval_status, quota_remaining, updated_at
      )
      VALUES (
        new.id, new.id, v_name, v_name, v_phone,
        v_is_verified, v_status, v_status, 3, NOW()
      )
      ON CONFLICT (id) DO NOTHING;
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'handle_new_user promoter_profiles insert warning: %', SQLERRM;
    END;
  END IF;

  RETURN new;
END;
$$;

-- 5. RLS policies untuk profiles & promoter_profiles
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "profiles_select_authenticated" ON public.profiles;
CREATE POLICY "profiles_select_authenticated"
  ON public.profiles FOR SELECT TO authenticated
  USING (TRUE);

DROP POLICY IF EXISTS "profiles_insert_own" ON public.profiles;
CREATE POLICY "profiles_insert_own"
  ON public.profiles FOR INSERT TO authenticated
  WITH CHECK (id = auth.uid());

DROP POLICY IF EXISTS "profiles_update_own_or_admin" ON public.profiles;
CREATE POLICY "profiles_update_own_or_admin"
  ON public.profiles FOR UPDATE TO authenticated
  USING (
    id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid() AND LOWER(COALESCE(p.role, '')) = 'admin'
    )
  )
  WITH CHECK (
    id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid() AND LOWER(COALESCE(p.role, '')) = 'admin'
    )
  );

ALTER TABLE public.promoter_profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "promoter_profiles_select_all" ON public.promoter_profiles;
CREATE POLICY "promoter_profiles_select_all"
  ON public.promoter_profiles FOR SELECT TO authenticated
  USING (TRUE);

DROP POLICY IF EXISTS "promoter_profiles_insert_own" ON public.promoter_profiles;
CREATE POLICY "promoter_profiles_insert_own"
  ON public.promoter_profiles FOR INSERT TO authenticated
  WITH CHECK (
    id::text = auth.uid()::text
    OR COALESCE(user_id::text, '') = auth.uid()::text
    OR EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid() AND LOWER(COALESCE(p.role, '')) IN ('admin', 'produser', 'producer', 'promoter')
    )
  );

DROP POLICY IF EXISTS "promoter_profiles_update_own_or_admin" ON public.promoter_profiles;
CREATE POLICY "promoter_profiles_update_own_or_admin"
  ON public.promoter_profiles FOR UPDATE TO authenticated
  USING (
    id::text = auth.uid()::text
    OR COALESCE(user_id::text, '') = auth.uid()::text
    OR EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid() AND LOWER(COALESCE(p.role, '')) = 'admin'
    )
  )
  WITH CHECK (
    id::text = auth.uid()::text
    OR COALESCE(user_id::text, '') = auth.uid()::text
    OR EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid() AND LOWER(COALESCE(p.role, '')) = 'admin'
    )
  );

-- 6. Pastikan semua kolom konser, ticket_tiers, dan storage bucket 'concerts' lengkap
DO $$
BEGIN
  IF to_regclass('public.concerts') IS NOT NULL THEN
    ALTER TABLE public.concerts
      ADD COLUMN IF NOT EXISTS subtitle TEXT DEFAULT '',
      ADD COLUMN IF NOT EXISTS time TEXT DEFAULT '19:00 WIB',
      ADD COLUMN IF NOT EXISTS venue TEXT DEFAULT '',
      ADD COLUMN IF NOT EXISTS venue_address TEXT DEFAULT '',
      ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION,
      ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION,
      ADD COLUMN IF NOT EXISTS price BIGINT NOT NULL DEFAULT 0,
      ADD COLUMN IF NOT EXISTS category TEXT DEFAULT 'Konser',
      ADD COLUMN IF NOT EXISTS tag TEXT DEFAULT '',
      ADD COLUMN IF NOT EXISTS description TEXT DEFAULT '',
      ADD COLUMN IF NOT EXISTS is_featured BOOLEAN NOT NULL DEFAULT FALSE,
      ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'pending',
      ADD COLUMN IF NOT EXISTS approval_status TEXT NOT NULL DEFAULT 'pending_create',
      ADD COLUMN IF NOT EXISTS producer_id TEXT,
      ADD COLUMN IF NOT EXISTS producer_name TEXT DEFAULT '',
      ADD COLUMN IF NOT EXISTS banner_image_url TEXT DEFAULT '',
      ADD COLUMN IF NOT EXISTS logo_image_url TEXT DEFAULT '',
      ADD COLUMN IF NOT EXISTS square_logo_url TEXT DEFAULT '',
      ADD COLUMN IF NOT EXISTS poster_data_url TEXT,
      ADD COLUMN IF NOT EXISTS square_logo_data_url TEXT,
      ADD COLUMN IF NOT EXISTS total_capacity INT NOT NULL DEFAULT 0,
      ADD COLUMN IF NOT EXISTS total_sold INT NOT NULL DEFAULT 0,
      ADD COLUMN IF NOT EXISTS tickets_sold INT NOT NULL DEFAULT 0,
      ADD COLUMN IF NOT EXISTS total_revenue BIGINT NOT NULL DEFAULT 0,
      ADD COLUMN IF NOT EXISTS gross_revenue BIGINT NOT NULL DEFAULT 0,
      ADD COLUMN IF NOT EXISTS is_completed BOOLEAN NOT NULL DEFAULT FALSE,
      ADD COLUMN IF NOT EXISTS likes_count BIGINT NOT NULL DEFAULT 0,
      ADD COLUMN IF NOT EXISTS rejected_at TIMESTAMPTZ,
      ADD COLUMN IF NOT EXISTS rejection_reason TEXT,
      ADD COLUMN IF NOT EXISTS cancellation_status TEXT DEFAULT 'none',
      ADD COLUMN IF NOT EXISTS cancellation_category TEXT DEFAULT 'Perizinan',
      ADD COLUMN IF NOT EXISTS cancellation_reason TEXT DEFAULT '',
      ADD COLUMN IF NOT EXISTS cancellation_date TEXT,
      ADD COLUMN IF NOT EXISTS cancellation_attachment TEXT;

    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'concerts' AND column_name = 'highlights'
    ) THEN
      ALTER TABLE public.concerts ADD COLUMN highlights TEXT[] DEFAULT '{}';
    END IF;

    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'concerts' AND column_name = 'highlight_names'
    ) THEN
      ALTER TABLE public.concerts ADD COLUMN highlight_names TEXT[] DEFAULT '{}';
    END IF;

    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'concerts' AND column_name = 'gates'
    ) THEN
      ALTER TABLE public.concerts ADD COLUMN gates JSONB DEFAULT '[]'::jsonb;
    END IF;
  END IF;

  IF to_regclass('public.ticket_tiers') IS NOT NULL THEN
    ALTER TABLE public.ticket_tiers
      ADD COLUMN IF NOT EXISTS description TEXT DEFAULT '',
      ADD COLUMN IF NOT EXISTS quota INT NOT NULL DEFAULT 0,
      ADD COLUMN IF NOT EXISTS total_quota INT NOT NULL DEFAULT 0,
      ADD COLUMN IF NOT EXISTS quota_type TEXT NOT NULL DEFAULT 'limited',
      ADD COLUMN IF NOT EXISTS sold_count INT NOT NULL DEFAULT 0,
      ADD COLUMN IF NOT EXISTS reserved_count INT NOT NULL DEFAULT 0,
      ADD COLUMN IF NOT EXISTS accent_color TEXT DEFAULT '#E91E8C',
      ADD COLUMN IF NOT EXISTS sort_order INT NOT NULL DEFAULT 0;
  END IF;
END $$;

-- RLS concerts & ticket_tiers agar Produser terautentikasi dapat insert/update konser mereka
DO $$
BEGIN
  IF to_regclass('public.concerts') IS NOT NULL THEN
    ALTER TABLE public.concerts ENABLE ROW LEVEL SECURITY;

    DROP POLICY IF EXISTS "concerts_select_policy" ON public.concerts;
    CREATE POLICY "concerts_select_policy"
      ON public.concerts FOR SELECT TO public
      USING (TRUE);

    DROP POLICY IF EXISTS "concerts_insert_policy" ON public.concerts;
    CREATE POLICY "concerts_insert_policy"
      ON public.concerts FOR INSERT TO authenticated
      WITH CHECK (
        COALESCE(producer_id::text, '') = auth.uid()::text
        OR EXISTS (
          SELECT 1 FROM public.profiles p
          WHERE p.id = auth.uid()
            AND LOWER(COALESCE(p.role, '')) IN ('admin', 'produser', 'producer', 'promoter')
        )
      );

    DROP POLICY IF EXISTS "concerts_update_policy" ON public.concerts;
    CREATE POLICY "concerts_update_policy"
      ON public.concerts FOR UPDATE TO authenticated
      USING (
        COALESCE(producer_id::text, '') = auth.uid()::text
        OR EXISTS (
          SELECT 1 FROM public.profiles p
          WHERE p.id = auth.uid()
            AND LOWER(COALESCE(p.role, '')) IN ('admin', 'produser', 'producer', 'promoter')
        )
      )
      WITH CHECK (
        COALESCE(producer_id::text, '') = auth.uid()::text
        OR EXISTS (
          SELECT 1 FROM public.profiles p
          WHERE p.id = auth.uid()
            AND LOWER(COALESCE(p.role, '')) IN ('admin', 'produser', 'producer', 'promoter')
        )
      );

    DROP POLICY IF EXISTS "concerts_delete_policy" ON public.concerts;
    CREATE POLICY "concerts_delete_policy"
      ON public.concerts FOR DELETE TO authenticated
      USING (
        COALESCE(producer_id::text, '') = auth.uid()::text
        OR EXISTS (
          SELECT 1 FROM public.profiles p
          WHERE p.id = auth.uid() AND LOWER(COALESCE(p.role, '')) = 'admin'
        )
      );
  END IF;

  IF to_regclass('public.ticket_tiers') IS NOT NULL THEN
    ALTER TABLE public.ticket_tiers ENABLE ROW LEVEL SECURITY;

    DROP POLICY IF EXISTS "ticket_tiers_select_policy" ON public.ticket_tiers;
    CREATE POLICY "ticket_tiers_select_policy"
      ON public.ticket_tiers FOR SELECT TO public
      USING (TRUE);

    DROP POLICY IF EXISTS "ticket_tiers_insert_policy" ON public.ticket_tiers;
    CREATE POLICY "ticket_tiers_insert_policy"
      ON public.ticket_tiers FOR INSERT TO authenticated
      WITH CHECK (
        EXISTS (
          SELECT 1 FROM public.concerts c
          WHERE c.id::text = ticket_tiers.concert_id::text
            AND (
              COALESCE(c.producer_id::text, '') = auth.uid()::text
              OR EXISTS (
                SELECT 1 FROM public.profiles p
                WHERE p.id = auth.uid()
                  AND LOWER(COALESCE(p.role, '')) IN ('admin', 'produser', 'producer', 'promoter')
              )
            )
        )
      );

    DROP POLICY IF EXISTS "ticket_tiers_update_policy" ON public.ticket_tiers;
    CREATE POLICY "ticket_tiers_update_policy"
      ON public.ticket_tiers FOR UPDATE TO authenticated
      USING (
        EXISTS (
          SELECT 1 FROM public.concerts c
          WHERE c.id::text = ticket_tiers.concert_id::text
            AND (
              COALESCE(c.producer_id::text, '') = auth.uid()::text
              OR EXISTS (
                SELECT 1 FROM public.profiles p
                WHERE p.id = auth.uid()
                  AND LOWER(COALESCE(p.role, '')) IN ('admin', 'produser', 'producer', 'promoter')
              )
            )
        )
      );

    DROP POLICY IF EXISTS "ticket_tiers_delete_policy" ON public.ticket_tiers;
    CREATE POLICY "ticket_tiers_delete_policy"
      ON public.ticket_tiers FOR DELETE TO authenticated
      USING (
        EXISTS (
          SELECT 1 FROM public.concerts c
          WHERE c.id::text = ticket_tiers.concert_id::text
            AND (
              COALESCE(c.producer_id::text, '') = auth.uid()::text
              OR EXISTS (
                SELECT 1 FROM public.profiles p
                WHERE p.id = auth.uid()
                  AND LOWER(COALESCE(p.role, '')) IN ('admin', 'produser', 'producer', 'promoter')
              )
            )
        )
      );
  END IF;
END $$;

-- 7. Bucket Storage 'concerts' & 'avatars'
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'concerts',
  'concerts',
  TRUE,
  10485760,
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
ON CONFLICT (id) DO UPDATE SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS "concerts_storage_select_public" ON storage.objects;
CREATE POLICY "concerts_storage_select_public"
  ON storage.objects FOR SELECT TO public
  USING (bucket_id = 'concerts');

DROP POLICY IF EXISTS "concerts_storage_insert_auth" ON storage.objects;
CREATE POLICY "concerts_storage_insert_auth"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'concerts');

DROP POLICY IF EXISTS "concerts_storage_update_auth" ON storage.objects;
CREATE POLICY "concerts_storage_update_auth"
  ON storage.objects FOR UPDATE TO authenticated
  USING (bucket_id = 'concerts');

GRANT ALL ON TABLE public.profiles TO authenticated;
GRANT ALL ON TABLE public.promoter_profiles TO authenticated;
GRANT ALL ON TABLE public.concerts TO authenticated, anon;
GRANT ALL ON TABLE public.ticket_tiers TO authenticated, anon;

NOTIFY pgrst, 'reload schema';

