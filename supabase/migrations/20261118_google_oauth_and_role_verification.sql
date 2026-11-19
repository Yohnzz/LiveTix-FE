-- ==============================================================================
-- LIVE TIX: GOOGLE OAUTH + VERIFIKASI ROLE
-- File: 20261118_google_oauth_and_role_verification.sql
--
-- Melengkapi struktur yang sudah ada tanpa membuat tabel/akun baru:
--   1. Kolom google_id & role_verification_status pada public.profiles
--   2. Backfill data lama agar pengguna lama tidak diminta memilih role ulang
--   3. handle_new_user: akun Google baru tidak otomatis diberi role final
--   4. RPC select_google_role (satu-satunya jalur pemilihan role oleh client)
--   5. Trigger penjaga agar client tidak bisa mengganti role sembarangan
--   6. Sinkronisasi role_verification_status dari approval_status
--   7. Constraint & index anti-duplikasi (google_id / email)
--
-- Aman dijalankan berulang (idempotent).
-- ==============================================================================

BEGIN;

-- ------------------------------------------------------------------------------
-- 1. KOLOM BARU PADA PROFIL
-- ------------------------------------------------------------------------------
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS google_id TEXT,
  ADD COLUMN IF NOT EXISTS role_verification_status TEXT;

ALTER TABLE public.profiles
  DROP CONSTRAINT IF EXISTS profiles_role_verification_status_check;
ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_role_verification_status_check
  CHECK (
    role_verification_status IS NULL
    OR role_verification_status IN ('', 'pending', 'approved', 'rejected')
  );

-- ------------------------------------------------------------------------------
-- 2. BACKFILL AKUN LAMA
--    Akun yang sudah ada sudah menentukan role-nya saat registrasi, sehingga
--    tidak boleh dipaksa membuka halaman Verifikasi Google.
-- ------------------------------------------------------------------------------
UPDATE public.profiles
SET role_verification_status = CASE
    WHEN LOWER(COALESCE(role, '')) IN ('produser', 'producer', 'promoter') THEN
      CASE LOWER(BTRIM(COALESCE(approval_status, '')))
        WHEN 'approved' THEN 'approved'
        WHEN 'disetujui' THEN 'approved'
        WHEN 'rejected' THEN 'rejected'
        WHEN 'ditolak' THEN 'rejected'
        WHEN 'nonaktif' THEN 'rejected'
        WHEN 'deactivated' THEN 'rejected'
        WHEN 'inactive' THEN 'rejected'
        ELSE 'pending'
      END
    ELSE 'approved'
  END,
  updated_at = NOW()
WHERE role_verification_status IS NULL;

-- Lengkapi google_id lama dari identitas Supabase Auth (bila ada).
UPDATE public.profiles p
SET google_id = i.provider_id,
    updated_at = NOW()
FROM auth.identities i
WHERE i.user_id = p.id
  AND LOWER(i.provider) = 'google'
  AND NULLIF(BTRIM(COALESCE(p.google_id, '')), '') IS NULL;

-- ------------------------------------------------------------------------------
-- 3. TRIGGER PEMBUATAN PROFIL
--    Akun Google baru dicatat tanpa role final (role_verification_status NULL)
--    sampai pengguna memilih sendiri di halaman Verifikasi Google.
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_raw_role TEXT;
  v_provider TEXT;
  v_is_google BOOLEAN;
  v_role TEXT;
  v_role_status TEXT;
  v_name TEXT;
  v_phone TEXT;
  v_nik TEXT;
  v_pin TEXT;
  v_bank_no TEXT;
  v_is_verified BOOLEAN := FALSE;
  v_status TEXT := 'unverified';
BEGIN
  v_provider := LOWER(COALESCE(new.raw_app_meta_data->>'provider', ''));
  v_is_google := v_provider = 'google'
    OR LOWER(COALESCE(new.raw_user_meta_data->>'iss', '')) LIKE '%accounts.google.com%';

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
    IF LENGTH(REGEXP_REPLACE(v_nik, '[^0-9]', '', 'g')) >= 16
       AND NULLIF(TRIM(v_name), '') IS NOT NULL THEN
      v_is_verified := TRUE;
      v_status := 'approved';
    END IF;
  ELSIF v_role = 'Produser' THEN
    IF NULLIF(TRIM(v_bank_no), '') IS NOT NULL
       AND NULLIF(TRIM(v_pin), '') IS NOT NULL THEN
      v_is_verified := TRUE;
      v_status := 'approved';
    END IF;
  END IF;

  IF v_is_google THEN
    -- Role Google dipilih pengguna sendiri; jangan tetapkan otomatis.
    v_role_status := NULL;
  ELSE
    v_role_status := CASE WHEN v_status = 'approved' THEN 'approved' ELSE 'pending' END;
  END IF;

  INSERT INTO public.profiles (
    id, email, name, full_name, phone, role, nik,
    is_verified, verification_status, approval_status,
    role_verification_status, updated_at
  )
  VALUES (
    new.id, new.email, v_name, v_name, v_phone, v_role, v_nik,
    v_is_verified, v_status, v_status,
    v_role_status, NOW()
  )
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    name = COALESCE(NULLIF(public.profiles.name, ''), EXCLUDED.name),
    full_name = COALESCE(NULLIF(public.profiles.full_name, ''), EXCLUDED.full_name),
    phone = COALESCE(NULLIF(public.profiles.phone, ''), EXCLUDED.phone),
    role = COALESCE(NULLIF(public.profiles.role, ''), EXCLUDED.role),
    updated_at = NOW();

  -- Akun Google tidak boleh langsung menjadi Produser terverifikasi.
  IF v_role = 'Produser' AND NOT v_is_google THEN
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

-- ------------------------------------------------------------------------------
-- 4. PEMILIHAN ROLE GOOGLE (RPC)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.select_google_role(p_role TEXT)
RETURNS public.profiles
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_role TEXT;
  v_is_google BOOLEAN;
  v_profile public.profiles;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Sesi pengguna tidak ditemukan. Silakan masuk ulang dengan Google.'
      USING ERRCODE = '28000';
  END IF;

  v_role := CASE LOWER(BTRIM(COALESCE(p_role, '')))
    WHEN 'user' THEN 'User'
    WHEN 'produser' THEN 'Produser'
    WHEN 'producer' THEN 'Produser'
    WHEN 'promoter' THEN 'Produser'
    ELSE NULL
  END;

  IF v_role IS NULL THEN
    RAISE EXCEPTION 'Role tidak valid. Pilih User atau Produser.'
      USING ERRCODE = '22023';
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM auth.identities i
    WHERE i.user_id = v_uid AND LOWER(i.provider) = 'google'
  ) INTO v_is_google;

  IF NOT v_is_google THEN
    RAISE EXCEPTION 'Pemilihan role ini hanya untuk akun Google yang sudah terautentikasi.'
      USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_profile
  FROM public.profiles
  WHERE id = v_uid;

  IF v_profile.id IS NULL THEN
    RAISE EXCEPTION 'Profil pengguna tidak ditemukan. Silakan masuk ulang dengan Google.'
      USING ERRCODE = 'P0002';
  END IF;

  -- Role hanya boleh berubah melalui jalur resmi ini.
  PERFORM set_config('livetix.allow_role_change', 'on', true);

  UPDATE public.profiles
  SET role = v_role,
      role_verification_status = 'pending',
      is_verified = FALSE,
      verification_status = 'unverified',
      updated_at = NOW()
  WHERE id = v_uid
  RETURNING * INTO v_profile;

  PERFORM set_config('livetix.allow_role_change', 'off', true);

  -- Metadata auth dilengkapi agar sesi dan routing berikutnya konsisten.
  UPDATE auth.users
  SET raw_user_meta_data =
        COALESCE(raw_user_meta_data, '{}'::jsonb)
        || jsonb_build_object(
             'role', v_role,
             'role_verification_status', 'pending'
           )
  WHERE id = v_uid;

  RETURN v_profile;
END;
$$;

GRANT EXECUTE ON FUNCTION public.select_google_role(TEXT) TO authenticated;

-- ------------------------------------------------------------------------------
-- 5. TRIGGER PENJAGA ROLE
--    RLS mengizinkan pemilik memperbarui barisnya, tetapi perubahan kolom role
--    dari client (selain Admin/RPC resmi) ditolak.
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.prevent_client_role_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NEW.role IS DISTINCT FROM OLD.role THEN
    IF auth.role() = 'service_role'
       OR public.is_admin()
       OR COALESCE(current_setting('livetix.allow_role_change', true), 'off') = 'on' THEN
      RETURN NEW;
    END IF;

    RAISE EXCEPTION
      'Role akun hanya dapat diubah melalui pemilihan role resmi atau oleh Admin.'
      USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS prevent_client_role_change_trg ON public.profiles;
CREATE TRIGGER prevent_client_role_change_trg
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.prevent_client_role_change();

-- ------------------------------------------------------------------------------
-- 6. SINKRONISASI role_verification_status
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sync_profile_role_verification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NEW.approval_status IS DISTINCT FROM OLD.approval_status
     AND NEW.role_verification_status IS NOT DISTINCT FROM OLD.role_verification_status THEN
    NEW.role_verification_status := CASE LOWER(BTRIM(COALESCE(NEW.approval_status, '')))
      WHEN 'approved' THEN 'approved'
      WHEN 'disetujui' THEN 'approved'
      WHEN 'rejected' THEN 'rejected'
      WHEN 'ditolak' THEN 'rejected'
      WHEN 'nonaktif' THEN 'rejected'
      WHEN 'deactivated' THEN 'rejected'
      WHEN 'inactive' THEN 'rejected'
      WHEN 'pending' THEN 'pending'
      ELSE NEW.role_verification_status
    END;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS role_verification_sync_trg ON public.profiles;
CREATE TRIGGER role_verification_sync_trg
  BEFORE UPDATE OF approval_status ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.sync_profile_role_verification();

CREATE OR REPLACE FUNCTION public.sync_producer_role_verification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NEW.approval_status IS DISTINCT FROM OLD.approval_status THEN
    UPDATE public.profiles
    SET role_verification_status = CASE LOWER(BTRIM(COALESCE(NEW.approval_status, '')))
          WHEN 'approved' THEN 'approved'
          WHEN 'disetujui' THEN 'approved'
          WHEN 'rejected' THEN 'rejected'
          WHEN 'ditolak' THEN 'rejected'
          WHEN 'nonaktif' THEN 'rejected'
          WHEN 'deactivated' THEN 'rejected'
          WHEN 'inactive' THEN 'rejected'
          ELSE 'pending'
        END,
        updated_at = NOW()
    WHERE id = NEW.user_id
      AND LOWER(COALESCE(role, '')) IN ('produser', 'producer', 'promoter');
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS role_verification_sync_trg ON public.promoter_profiles;
CREATE TRIGGER role_verification_sync_trg
  AFTER UPDATE OF approval_status ON public.promoter_profiles
  FOR EACH ROW EXECUTE FUNCTION public.sync_producer_role_verification();

-- ------------------------------------------------------------------------------
-- 7. ANTI-DUPLIKASI
--    UUID auth.users sudah unik (primary key). Google ID dan email juga dijaga
--    unik agar satu identitas tidak punya beberapa profil.
-- ------------------------------------------------------------------------------
CREATE UNIQUE INDEX IF NOT EXISTS profiles_google_id_unique_idx
  ON public.profiles (google_id)
  WHERE google_id IS NOT NULL AND BTRIM(google_id) <> '';

DO $$
BEGIN
  CREATE UNIQUE INDEX IF NOT EXISTS profiles_email_unique_idx
    ON public.profiles (LOWER(email))
    WHERE email IS NOT NULL AND BTRIM(email) <> '';
EXCEPTION
  WHEN unique_violation THEN
    RAISE WARNING
      'Index unik email dilewati karena masih ada email duplikat di public.profiles.';
  WHEN duplicate_table THEN
    NULL;
END $$;

CREATE INDEX IF NOT EXISTS idx_profiles_google_id
  ON public.profiles (google_id);
CREATE INDEX IF NOT EXISTS idx_profiles_role_verification
  ON public.profiles (role_verification_status);

COMMIT;
