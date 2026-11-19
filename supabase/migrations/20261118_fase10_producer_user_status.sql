-- ==============================================================================
-- LIVE TIX: FASE 10 - STATUS AKUN PRODUSER & USER
-- File: 20261118_fase10_producer_user_status.sql
--
-- Satu-satunya penamaan status akun yang dipakai setelah migrasi ini:
--   pending | approved | rejected | nonaktif
--
-- Nilai lama yang dinormalisasi otomatis:
--   unverified, pending_create, ''      -> pending   (produser)
--   unverified, disetujui, ''           -> approved  (user; "unverified" = belum
--                                         verifikasi identitas, bukan akun mati)
--   ditolak                             -> rejected
--   deactivated, inactive               -> nonaktif
--
-- Komponen:
--   1. Kolom deactivation_reason (produser & user) + kolom pendukung
--   2. Normalisasi nilai status lama
--   3. Migrasi produser `pending` + rejection_reason -> `rejected`
--   4. Sinkronisasi status produser ke public.profiles
--   5. Check constraint 4 status
--   6. Helper normalize_account_status / current_account_status / is_admin_user
--   7. Trigger validasi (alasan wajib, approved membersihkan alasan)
--   8. Trigger penjaga (hanya admin boleh mengubah status & alasan)
--   9. RLS: akun rejected/nonaktif tidak bisa menulis data produser
--  10. Index + realtime publication
-- ==============================================================================

BEGIN;

-- ------------------------------------------------------------------------------
-- 1. KOLOM PENDUKUNG
-- ------------------------------------------------------------------------------
ALTER TABLE public.promoter_profiles
  ADD COLUMN IF NOT EXISTS deactivation_reason TEXT,
  ADD COLUMN IF NOT EXISTS rejected_at TIMESTAMPTZ;

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS deactivation_reason TEXT,
  ADD COLUMN IF NOT EXISTS rejection_reason TEXT,
  ADD COLUMN IF NOT EXISTS rejected_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- ------------------------------------------------------------------------------
-- 2. NORMALISASI NILAI STATUS LAMA
-- ------------------------------------------------------------------------------
UPDATE public.promoter_profiles
SET approval_status = CASE lower(btrim(COALESCE(approval_status, '')))
    WHEN 'approved'    THEN 'approved'
    WHEN 'disetujui'   THEN 'approved'
    WHEN 'rejected'    THEN 'rejected'
    WHEN 'ditolak'     THEN 'rejected'
    WHEN 'nonaktif'    THEN 'nonaktif'
    WHEN 'deactivated' THEN 'nonaktif'
    WHEN 'inactive'    THEN 'nonaktif'
    ELSE 'pending'
  END
WHERE approval_status IS DISTINCT FROM CASE lower(btrim(COALESCE(approval_status, '')))
    WHEN 'approved'    THEN 'approved'
    WHEN 'disetujui'   THEN 'approved'
    WHEN 'rejected'    THEN 'rejected'
    WHEN 'ditolak'     THEN 'rejected'
    WHEN 'nonaktif'    THEN 'nonaktif'
    WHEN 'deactivated' THEN 'nonaktif'
    WHEN 'inactive'    THEN 'nonaktif'
    ELSE 'pending'
  END;

UPDATE public.profiles
SET approval_status = CASE lower(btrim(COALESCE(approval_status, '')))
    WHEN 'rejected'    THEN 'rejected'
    WHEN 'ditolak'     THEN 'rejected'
    WHEN 'nonaktif'    THEN 'nonaktif'
    WHEN 'deactivated' THEN 'nonaktif'
    WHEN 'inactive'    THEN 'nonaktif'
    WHEN 'pending'     THEN 'pending'
    WHEN 'pending_create' THEN 'pending'
    ELSE 'approved'
  END
WHERE approval_status IS DISTINCT FROM CASE lower(btrim(COALESCE(approval_status, '')))
    WHEN 'rejected'    THEN 'rejected'
    WHEN 'ditolak'     THEN 'rejected'
    WHEN 'nonaktif'    THEN 'nonaktif'
    WHEN 'deactivated' THEN 'nonaktif'
    WHEN 'inactive'    THEN 'nonaktif'
    WHEN 'pending'     THEN 'pending'
    WHEN 'pending_create' THEN 'pending'
    ELSE 'approved'
  END;

-- ------------------------------------------------------------------------------
-- 3. MIGRASI DATA: pending + rejection_reason terisi = rejected
-- ------------------------------------------------------------------------------
UPDATE public.promoter_profiles
SET approval_status = 'rejected',
    rejected_at = COALESCE(rejected_at, NOW()),
    updated_at = NOW()
WHERE approval_status = 'pending'
  AND NULLIF(btrim(COALESCE(rejection_reason, '')), '') IS NOT NULL;

-- ------------------------------------------------------------------------------
-- 4. SINKRONISASI STATUS PRODUSER KE public.profiles (dipakai routing login)
-- ------------------------------------------------------------------------------
UPDATE public.profiles p
SET approval_status = pp.approval_status,
    verification_status = pp.approval_status,
    rejected_at = COALESCE(pp.rejected_at, p.rejected_at),
    deactivation_reason = pp.deactivation_reason,
    updated_at = NOW()
FROM public.promoter_profiles pp
WHERE (pp.user_id = p.id OR pp.id::text = p.id::text)
  AND p.approval_status IS DISTINCT FROM pp.approval_status;

-- ------------------------------------------------------------------------------
-- 5. ALASAN WAJIB UNTUK AKUN NONAKTIF LAMA
-- ------------------------------------------------------------------------------
UPDATE public.promoter_profiles
SET deactivation_reason = COALESCE(
      NULLIF(btrim(COALESCE(deactivation_reason, '')), ''),
      NULLIF(btrim(COALESCE(rejection_reason, '')), ''),
      'Dinonaktifkan oleh Admin LiveTix'
    )
WHERE approval_status = 'nonaktif'
  AND NULLIF(btrim(COALESCE(deactivation_reason, '')), '') IS NULL;

UPDATE public.profiles
SET deactivation_reason = COALESCE(
      NULLIF(btrim(COALESCE(deactivation_reason, '')), ''),
      NULLIF(btrim(COALESCE(rejection_reason, '')), ''),
      'Dinonaktifkan oleh Admin LiveTix'
    )
WHERE approval_status = 'nonaktif'
  AND NULLIF(btrim(COALESCE(deactivation_reason, '')), '') IS NULL;

-- ------------------------------------------------------------------------------
-- 6. CHECK CONSTRAINT: HANYA 4 STATUS
-- ------------------------------------------------------------------------------
ALTER TABLE public.promoter_profiles
  DROP CONSTRAINT IF EXISTS promoter_profiles_approval_status_check;
ALTER TABLE public.promoter_profiles
  ADD CONSTRAINT promoter_profiles_approval_status_check
  CHECK (approval_status IN ('pending', 'approved', 'rejected', 'nonaktif'));

ALTER TABLE public.profiles
  DROP CONSTRAINT IF EXISTS profiles_approval_status_check;
ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_approval_status_check
  CHECK (approval_status IS NULL
         OR approval_status IN ('pending', 'approved', 'rejected', 'nonaktif'));

-- ------------------------------------------------------------------------------
-- 7. HELPER: NORMALISASI, STATUS AKUN, DAN ROLE ADMIN
-- ------------------------------------------------------------------------------
-- is_producer = TRUE -> nilai tak dikenal dianggap 'pending' (belum disetujui)
-- is_producer = FALSE -> nilai tak dikenal dianggap 'approved' (akun user aktif,
--                       karena 'unverified' hanya berarti NIK belum diverifikasi)
CREATE OR REPLACE FUNCTION public.normalize_account_status(
  p_status TEXT,
  p_is_producer BOOLEAN
)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE lower(btrim(COALESCE(p_status, '')))
    WHEN 'approved'       THEN 'approved'
    WHEN 'disetujui'      THEN 'approved'
    WHEN 'rejected'       THEN 'rejected'
    WHEN 'ditolak'        THEN 'rejected'
    WHEN 'nonaktif'       THEN 'nonaktif'
    WHEN 'deactivated'    THEN 'nonaktif'
    WHEN 'inactive'       THEN 'nonaktif'
    WHEN 'pending'        THEN 'pending'
    WHEN 'pending_create' THEN 'pending'
    WHEN 'unverified'     THEN CASE WHEN p_is_producer THEN 'pending' ELSE 'approved' END
    ELSE CASE WHEN p_is_producer THEN 'pending' ELSE 'approved' END
  END;
$$;

CREATE OR REPLACE FUNCTION public.is_admin_user()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.profiles
    WHERE id = auth.uid()
      AND lower(btrim(COALESCE(role, ''))) IN ('admin', 'super admin')
  );
$$;

CREATE OR REPLACE FUNCTION public.current_account_status()
RETURNS TEXT
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT COALESCE(
    (SELECT pp.approval_status
       FROM public.promoter_profiles pp
      WHERE pp.user_id = auth.uid()
         OR pp.id::text = auth.uid()::text
      LIMIT 1),
    (SELECT p.approval_status FROM public.profiles p WHERE p.id = auth.uid()),
    'approved'
  );
$$;

GRANT EXECUTE ON FUNCTION public.normalize_account_status(TEXT, BOOLEAN)
  TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.is_admin_user()
  TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.current_account_status()
  TO anon, authenticated, service_role;

-- ------------------------------------------------------------------------------
-- 8. TRIGGER VALIDASI STATUS
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.account_status_validate()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_is_producer BOOLEAN := TG_TABLE_NAME = 'promoter_profiles';
BEGIN
  NEW.approval_status := public.normalize_account_status(
    NEW.approval_status, v_is_producer
  );

  IF NEW.approval_status = 'nonaktif' THEN
    IF NULLIF(btrim(COALESCE(NEW.deactivation_reason, '')), '') IS NULL THEN
      RAISE EXCEPTION
        'Status nonaktif wajib memiliki deactivation_reason yang tidak kosong.'
        USING ERRCODE = '23514';
    END IF;
  END IF;

  IF NEW.approval_status = 'rejected' THEN
    IF NULLIF(btrim(COALESCE(NEW.rejection_reason, '')), '') IS NULL THEN
      RAISE EXCEPTION
        'Status rejected wajib memiliki rejection_reason yang tidak kosong.'
        USING ERRCODE = '23514';
    END IF;
  END IF;

  IF NEW.approval_status = 'approved' THEN
    NEW.deactivation_reason := NULL;
    NEW.rejected_at := NULL;
  END IF;

  NEW.updated_at := NOW();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS account_status_validate_trg ON public.promoter_profiles;
CREATE TRIGGER account_status_validate_trg
  BEFORE INSERT OR UPDATE ON public.promoter_profiles
  FOR EACH ROW EXECUTE FUNCTION public.account_status_validate();

DROP TRIGGER IF EXISTS account_status_validate_trg ON public.profiles;
CREATE TRIGGER account_status_validate_trg
  BEFORE INSERT OR UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.account_status_validate();

-- ------------------------------------------------------------------------------
-- 9. TRIGGER PENJAGA: HANYA ADMIN YANG BOLEH MENGUBAH STATUS & ALASAN
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.account_status_guard()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_is_producer BOOLEAN := TG_TABLE_NAME = 'promoter_profiles';
  v_old_status TEXT := public.normalize_account_status(OLD.approval_status, v_is_producer);
  v_new_status TEXT := public.normalize_account_status(NEW.approval_status, v_is_producer);
  -- session_user (bukan current_user) karena SECURITY DEFINER mengganti
  -- current_user menjadi pemilik fungsi.
  v_is_privileged BOOLEAN :=
       auth.role() = 'service_role'
    OR public.is_admin_user()
    OR session_user IN ('postgres', 'supabase_admin', 'supabase_auth_admin');
BEGIN
  IF v_is_privileged THEN
    RETURN NEW;
  END IF;

  -- Pemilik akun hanya boleh mengajukan ulang (status -> pending).
  IF v_new_status IS DISTINCT FROM v_old_status
     AND v_new_status <> 'pending' THEN
    RAISE EXCEPTION
      'Hanya admin yang boleh mengubah status akun menjadi %.', v_new_status
      USING ERRCODE = '42501';
  END IF;

  IF v_is_producer THEN
    IF NEW.deactivation_reason IS DISTINCT FROM OLD.deactivation_reason THEN
      RAISE EXCEPTION
        'Hanya admin yang boleh mengubah alasan penonaktifan akun.'
        USING ERRCODE = '42501';
    END IF;

    IF NEW.rejection_reason IS DISTINCT FROM OLD.rejection_reason
       AND v_new_status <> 'pending' THEN
      RAISE EXCEPTION
        'Hanya admin yang boleh mengubah alasan penolakan akun.'
        USING ERRCODE = '42501';
    END IF;
  ELSE
    -- public.profiles: kunci alasan penonaktifan dan status terminal.
    -- Transisi pending -> approved tetap diizinkan untuk verifikasi identitas.
    IF NEW.deactivation_reason IS DISTINCT FROM OLD.deactivation_reason THEN
      RAISE EXCEPTION
        'Hanya admin yang boleh mengubah alasan penonaktifan akun.'
        USING ERRCODE = '42501';
    END IF;

    IF v_old_status IN ('rejected', 'nonaktif')
       AND v_new_status IS DISTINCT FROM v_old_status THEN
      RAISE EXCEPTION
        'Akun rejected/nonaktif hanya dapat diaktifkan oleh admin.'
        USING ERRCODE = '42501';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS account_status_guard_trg ON public.promoter_profiles;
CREATE TRIGGER account_status_guard_trg
  BEFORE UPDATE ON public.promoter_profiles
  FOR EACH ROW EXECUTE FUNCTION public.account_status_guard();

DROP TRIGGER IF EXISTS account_status_guard_trg ON public.profiles;
CREATE TRIGGER account_status_guard_trg
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.account_status_guard();

-- ------------------------------------------------------------------------------
-- 10. RLS: AKUN rejected/nonaktif TIDAK BOLEH MENULIS DATA PRODUSER
--     Catatan: SELECT konser publik tetap dibuka agar akun nonaktif masih bisa
--     menjelajah katalog. Yang diblokir adalah aksi tulis (kelola konser,
--     penarikan dana) dan baca buku besar keuangan.
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "Active producer can insert concerts" ON public.concerts;
CREATE POLICY "Active producer can insert concerts"
  ON public.concerts
  AS RESTRICTIVE
  FOR INSERT
  TO authenticated
  WITH CHECK (public.is_admin_user() OR public.current_account_status() = 'approved');

DROP POLICY IF EXISTS "Active producer can update concerts" ON public.concerts;
CREATE POLICY "Active producer can update concerts"
  ON public.concerts
  AS RESTRICTIVE
  FOR UPDATE
  TO authenticated
  USING (public.is_admin_user() OR public.current_account_status() = 'approved')
  WITH CHECK (public.is_admin_user() OR public.current_account_status() = 'approved');

DROP POLICY IF EXISTS "Active producer can delete concerts" ON public.concerts;
CREATE POLICY "Active producer can delete concerts"
  ON public.concerts
  AS RESTRICTIVE
  FOR DELETE
  TO authenticated
  USING (public.is_admin_user() OR public.current_account_status() = 'approved');

DO $$
BEGIN
  IF to_regclass('public.withdrawals') IS NOT NULL THEN
    DROP POLICY IF EXISTS "Active producer can insert withdrawals" ON public.withdrawals;
    CREATE POLICY "Active producer can insert withdrawals"
      ON public.withdrawals
      AS RESTRICTIVE
      FOR INSERT
      TO authenticated
      WITH CHECK (public.is_admin_user() OR public.current_account_status() = 'approved');
  END IF;

  IF to_regclass('public.ledger_mutations') IS NOT NULL THEN
    DROP POLICY IF EXISTS "Active account can read ledger" ON public.ledger_mutations;
    CREATE POLICY "Active account can read ledger"
      ON public.ledger_mutations
      AS RESTRICTIVE
      FOR SELECT
      TO authenticated
      USING (public.is_admin_user() OR public.current_account_status() = 'approved');
  END IF;
END;
$$;

-- ------------------------------------------------------------------------------
-- 11. INDEX & REALTIME
-- ------------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_promoter_profiles_status
  ON public.promoter_profiles (approval_status);
CREATE INDEX IF NOT EXISTS idx_profiles_status
  ON public.profiles (approval_status);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'promoter_profiles'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.promoter_profiles;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'profiles'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.profiles;
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'Realtime publication tidak diubah: %', SQLERRM;
END;
$$;

-- ------------------------------------------------------------------------------
-- 12. VERIFIKASI
-- ------------------------------------------------------------------------------
DO $$
DECLARE
  v_bad INT;
BEGIN
  SELECT COUNT(*) INTO v_bad
  FROM public.promoter_profiles
  WHERE approval_status NOT IN ('pending', 'approved', 'rejected', 'nonaktif');
  IF v_bad > 0 THEN
    RAISE EXCEPTION 'Masih ada % produser dengan status di luar 4 status final.', v_bad;
  END IF;

  SELECT COUNT(*) INTO v_bad
  FROM public.profiles
  WHERE approval_status IS NOT NULL
    AND approval_status NOT IN ('pending', 'approved', 'rejected', 'nonaktif');
  IF v_bad > 0 THEN
    RAISE EXCEPTION 'Masih ada % profil dengan status di luar 4 status final.', v_bad;
  END IF;

  SELECT COUNT(*) INTO v_bad
  FROM public.promoter_profiles
  WHERE approval_status = 'pending'
    AND NULLIF(btrim(COALESCE(rejection_reason, '')), '') IS NOT NULL;
  IF v_bad > 0 THEN
    RAISE EXCEPTION '% produser pending masih menyimpan rejection_reason.', v_bad;
  END IF;

  SELECT COUNT(*) INTO v_bad
  FROM public.promoter_profiles
  WHERE approval_status = 'nonaktif'
    AND NULLIF(btrim(COALESCE(deactivation_reason, '')), '') IS NULL;
  IF v_bad > 0 THEN
    RAISE EXCEPTION '% produser nonaktif belum punya deactivation_reason.', v_bad;
  END IF;

  SELECT COUNT(*) INTO v_bad
  FROM public.promoter_profiles
  WHERE approval_status = 'rejected'
    AND NULLIF(btrim(COALESCE(rejection_reason, '')), '') IS NULL;
  IF v_bad > 0 THEN
    RAISE EXCEPTION '% produser rejected belum punya rejection_reason.', v_bad;
  END IF;

  RAISE NOTICE 'Fase 10 OK: status akun = pending/approved/rejected/nonaktif';
END;
$$;

COMMIT;

-- ==============================================================================
-- QUERY VERIFIKASI MANUAL (jalankan terpisah setelah migrasi)
-- ==============================================================================
-- 1. Rekap status produser:
--    SELECT approval_status, COUNT(*) FROM public.promoter_profiles
--    GROUP BY approval_status ORDER BY approval_status;
--
-- 2. Rekap status user:
--    SELECT approval_status, COUNT(*) FROM public.profiles
--    GROUP BY approval_status ORDER BY approval_status;
--
-- 3. Produser nonaktif + alasan:
--    SELECT id, company_name, approval_status, deactivation_reason, updated_at
--    FROM public.promoter_profiles WHERE approval_status = 'nonaktif';
--
-- 4. Produser ditolak + alasan:
--    SELECT id, company_name, approval_status, rejection_reason, rejected_at
--    FROM public.promoter_profiles WHERE approval_status = 'rejected';
--
-- 5. Pastikan produser & profil sinkron:
--    SELECT p.id, p.approval_status AS profil, pp.approval_status AS produser
--    FROM public.profiles p
--    JOIN public.promoter_profiles pp ON pp.user_id = p.id OR pp.id::text = p.id::text
--    WHERE p.approval_status IS DISTINCT FROM pp.approval_status;
--
-- 6. Uji trigger (harus gagal: nonaktif tanpa alasan):
--    UPDATE public.promoter_profiles SET approval_status = 'nonaktif'
--    WHERE id = '<id-produser>';
--
-- 7. Uji trigger (harus gagal: rejected tanpa alasan):
--    UPDATE public.promoter_profiles SET approval_status = 'rejected'
--    WHERE id = '<id-produser>';
--
-- 8. Uji aktifkan kembali (harus sukses, alasan jadi NULL):
--    UPDATE public.promoter_profiles
--    SET approval_status = 'approved' WHERE id = '<id-produser>';
--    SELECT id, approval_status, deactivation_reason
--    FROM public.promoter_profiles WHERE id = '<id-produser>';
-- ==============================================================================
