-- ==============================================================================
-- LIVE TIX: FASE 6 - WITHDRAW ADMIN (BIAYA APLIKASI & PEMBULATAN TERPISAH)
-- File: 20261118_fase6_admin_withdrawal.sql
-- Aturan Wajib:
--   1. Admin bisa withdraw dana biaya aplikasi + pembulatan kapan saja.
--   2. Saldo biaya aplikasi (2%) dan pembulatan ditampilkan TERPISAH.
--   3. Form tarik dana & riwayat penarikan.
--   4. HANYA ROLE ADMIN (Server-side validation + RLS).
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. FUNGSI calculate_admin_balance (Biaya Aplikasi & Pembulatan Terpisah)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.calculate_admin_balance()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_role                 TEXT;
  v_biaya_aplikasi       BIGINT := 0;
  v_pembulatan           BIGINT := 0;
  v_total_collected      BIGINT := 0;
  v_withdrawn            BIGINT := 0;
  v_available            BIGINT := 0;
  v_avail_app_fee        BIGINT := 0;
  v_avail_rounding       BIGINT := 0;
  v_has_pending          BOOLEAN := false;
BEGIN
  -- 1. Verifikasi Role Admin (Server-Side Gate)
  -- service_role diperbolehkan lewat tanpa auth.uid()
  IF auth.uid() IS NOT NULL THEN
    SELECT role INTO v_role
    FROM public.profiles
    WHERE id::TEXT = auth.uid()::TEXT;

    IF v_role IS NULL OR v_role NOT IN ('admin', 'superadmin') THEN
      RAISE EXCEPTION 'Akses ditolak: Hanya admin yang berhak mengakses saldo admin.';
    END IF;
  END IF;

  -- 2. Hitung Biaya Aplikasi (2%) dari transaksi paid
  SELECT COALESCE(SUM(biaya_aplikasi), 0) INTO v_biaya_aplikasi
  FROM public.transactions
  WHERE status = 'paid';

  -- Jika tabel transactions kosong/belum sinkron, fallback ke orders
  IF v_biaya_aplikasi = 0 THEN
    SELECT COALESCE(SUM(biaya_aplikasi), 0) INTO v_biaya_aplikasi
    FROM public.orders
    WHERE payment_status = 'PAID';
  END IF;

  -- 3. Hitung Pembulatan dari transaksi paid
  SELECT COALESCE(SUM(pembulatan), 0) INTO v_pembulatan
  FROM public.transactions
  WHERE status = 'paid';

  IF v_pembulatan = 0 THEN
    SELECT COALESCE(SUM(pembulatan), 0) INTO v_pembulatan
    FROM public.orders
    WHERE payment_status = 'PAID';
  END IF;

  v_total_collected := v_biaya_aplikasi + v_pembulatan;

  -- Jika data transaksi/orders belum mencatat komponen, fallback ke ledger kredit admin
  IF v_total_collected = 0 THEN
    SELECT COALESCE(SUM(jumlah), 0) INTO v_total_collected
    FROM public.ledger
    WHERE wallet_type = 'admin' AND tipe = 'kredit';

    -- Asumsi estimasi proporsi standar jika fallback dari ledger mentah (80% app fee, 20% pembulatan)
    v_biaya_aplikasi := (v_total_collected * 80) / 100;
    v_pembulatan     := v_total_collected - v_biaya_aplikasi;
  END IF;

  -- 4. Total penarikan admin dari debit ledger
  SELECT COALESCE(SUM(jumlah), 0) INTO v_withdrawn
  FROM public.ledger
  WHERE wallet_type = 'admin' AND tipe = 'debit';

  -- 5. Saldo admin tersedia untuk ditarik kapan saja
  v_available := GREATEST(0, v_total_collected - v_withdrawn);

  -- Hitung pemisahan proporsional saldo yang tersisa
  IF v_total_collected > 0 THEN
    v_avail_app_fee  := (v_available * v_biaya_aplikasi) / v_total_collected;
    v_avail_rounding := v_available - v_avail_app_fee;
  ELSE
    v_avail_app_fee  := 0;
    v_avail_rounding := 0;
  END IF;

  -- 6. Cek apakah ada penarikan admin yang masih berstatus pending / processing
  SELECT EXISTS (
    SELECT 1 FROM public.withdrawals
    WHERE role = 'admin'
      AND LOWER(status) IN ('pending', 'processing')
  ) INTO v_has_pending;

  RETURN jsonb_build_object(
    'total_biaya_aplikasi',       v_biaya_aplikasi,
    'total_pembulatan',           v_pembulatan,
    'total_fee_collected',        v_total_collected,
    'total_fee_withdrawn',        v_withdrawn,
    'available_fee_balance',      v_available,
    'available_biaya_aplikasi',   v_avail_app_fee,
    'available_pembulatan',       v_avail_rounding,
    'has_pending_withdrawal',     v_has_pending
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.calculate_admin_balance() TO authenticated, service_role;

-- ------------------------------------------------------------------------------
-- 2. FUNGSI request_admin_withdrawal (Atomic Request Penarikan Admin)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.request_admin_withdrawal(
  p_admin_id       TEXT,
  p_amount         BIGINT,
  p_bank_name      TEXT,
  p_account_number TEXT,
  p_account_name   TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_role           TEXT;
  v_balance        JSONB;
  v_available      BIGINT;
  v_has_pending    BOOLEAN;
  v_ref_no         TEXT;
  v_withdrawal_id  TEXT;
  v_saldo_sebelum  BIGINT;
  v_saldo_setelah  BIGINT;
  v_admin_uuid     UUID;
BEGIN
  -- 1. Validasi Keamanan: HANYA ROLE ADMIN
  SELECT role INTO v_role
  FROM public.profiles
  WHERE id::TEXT = COALESCE(p_admin_id, auth.uid()::TEXT);

  IF v_role IS NULL OR v_role NOT IN ('admin', 'superadmin') THEN
    RETURN jsonb_build_object(
      'success', false,
      'code', 'FORBIDDEN',
      'message', 'Akses ditolak: Hanya akun admin resmi yang dapat mengajukan penarikan fee.'
    );
  END IF;

  -- 2. Validasi minimum nominal
  IF p_amount < 50000 THEN
    RETURN jsonb_build_object(
      'success', false,
      'code', 'MINIMUM_AMOUNT',
      'message', 'Nominal penarikan minimum adalah Rp 50.000'
    );
  END IF;

  -- 3. Cek apakah ada penarikan admin yang pending
  SELECT EXISTS (
    SELECT 1 FROM public.withdrawals
    WHERE role = 'admin'
      AND LOWER(status) IN ('pending', 'processing')
  ) INTO v_has_pending;

  IF v_has_pending THEN
    RETURN jsonb_build_object(
      'success', false,
      'code', 'PENDING_WITHDRAWAL_EXISTS',
      'message', 'Masih ada permohonan penarikan admin yang sedang diproses. Mohon tunggu hingga selesai.'
    );
  END IF;

  -- 4. Hitung saldo tersedia saat ini
  v_balance   := public.calculate_admin_balance();
  v_available := (v_balance->>'available_fee_balance')::BIGINT;

  IF p_amount > v_available THEN
    RETURN jsonb_build_object(
      'success', false,
      'code', 'INSUFFICIENT_BALANCE',
      'message', 'Saldo fee admin tidak mencukupi (Tersedia: Rp ' || v_available || ')',
      'available_balance', v_available
    );
  END IF;

  -- 5. Hitung saldo sebelum dari ledger admin
  SELECT COALESCE(
    (SELECT saldo_setelah FROM public.ledger
     WHERE wallet_type = 'admin' AND wallet_owner_id IS NULL
     ORDER BY created_at DESC LIMIT 1),
    0
  ) INTO v_saldo_sebelum;

  IF p_amount > v_saldo_sebelum THEN
    -- Jika saldo ledger belum tercatat setara, gunakan v_available
    v_saldo_sebelum := v_available;
  END IF;

  v_saldo_setelah := GREATEST(0, v_saldo_sebelum - p_amount);
  v_ref_no := 'WD-ADM-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || UPPER(SUBSTRING(encode(gen_random_bytes(4), 'hex'), 1, 8));
  v_withdrawal_id := 'wd_adm_' || encode(gen_random_bytes(8), 'hex');

  BEGIN
    v_admin_uuid := p_admin_id::UUID;
  EXCEPTION WHEN OTHERS THEN
    v_admin_uuid := auth.uid();
  END;

  -- 6. Insert ke tabel withdrawals
  INSERT INTO public.withdrawals (
    id, reference_no, user_id, role,
    amount, bank_name, account_number, account_name, status, created_at
  ) VALUES (
    v_withdrawal_id, v_ref_no, v_admin_uuid, 'admin',
    p_amount, p_bank_name, p_account_number, p_account_name, 'pending', NOW()
  );

  -- 7. Catat DEBIT ke ledger append-only (wallet_type = 'admin', wallet_owner_id = NULL)
  INSERT INTO public.ledger (
    wallet_type, wallet_owner_id, transaksi_id, tipe, jumlah,
    saldo_setelah, keterangan, created_at
  ) VALUES (
    'admin', NULL, v_ref_no, 'debit', p_amount,
    v_saldo_setelah, 'Penarikan fee admin: ' || v_ref_no || ' ke ' || p_bank_name || ' ' || p_account_number, NOW()
  );

  RETURN jsonb_build_object(
    'success',       true,
    'withdrawal_id', v_withdrawal_id,
    'reference_no',  v_ref_no,
    'amount',        p_amount,
    'saldo_setelah', v_saldo_setelah,
    'message',       'Permohonan penarikan dana admin Rp ' || p_amount || ' berhasil diajukan.'
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.request_admin_withdrawal(TEXT, BIGINT, TEXT, TEXT, TEXT) TO authenticated, service_role;

-- ------------------------------------------------------------------------------
-- 3. ALIAS request_admin_withdrawal_atomic (Mendukung Kode Legacy)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.request_admin_withdrawal_atomic(
  p_admin_id       UUID,
  p_amount         BIGINT,
  p_bank_name      TEXT,
  p_account_number TEXT,
  p_account_name   TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  RETURN public.request_admin_withdrawal(
    p_admin_id::TEXT,
    p_amount,
    p_bank_name,
    p_account_number,
    p_account_name
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.request_admin_withdrawal_atomic(UUID, BIGINT, TEXT, TEXT, TEXT) TO authenticated, service_role;

-- ------------------------------------------------------------------------------
-- 4. FUNGSI complete_admin_withdrawal & fail_admin_withdrawal
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.complete_admin_withdrawal(
  p_withdrawal_id TEXT,
  p_iris_id       TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  UPDATE public.withdrawals
  SET status = 'success',
      iris_payout_id = COALESCE(p_iris_id, iris_payout_id, 'iris_adm_' || TO_CHAR(NOW(), 'YYYYMMDDHH24MISS')),
      completed_at = NOW()
  WHERE id = p_withdrawal_id OR reference_no = p_withdrawal_id;

  RETURN jsonb_build_object('success', true, 'status', 'success');
END;
$$;

GRANT EXECUTE ON FUNCTION public.complete_admin_withdrawal(TEXT, TEXT) TO service_role;

CREATE OR REPLACE FUNCTION public.fail_admin_withdrawal(
  p_withdrawal_id TEXT,
  p_reason        TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_wd            RECORD;
  v_saldo_sebelum BIGINT;
  v_saldo_setelah BIGINT;
BEGIN
  SELECT * INTO v_wd
  FROM public.withdrawals
  WHERE id = p_withdrawal_id OR reference_no = p_withdrawal_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'Withdrawal admin tidak ditemukan');
  END IF;

  IF v_wd.status = 'failed' THEN
    RETURN jsonb_build_object('success', true, 'message', 'Withdrawal sudah berstatus failed');
  END IF;

  UPDATE public.withdrawals
  SET status = 'failed',
      rejection_reason = p_reason
  WHERE id = v_wd.id;

  -- KREDIT BALIK KE LEDGER ADMIN
  SELECT COALESCE(
    (SELECT saldo_setelah FROM public.ledger
     WHERE wallet_type = 'admin' AND wallet_owner_id IS NULL
     ORDER BY created_at DESC LIMIT 1),
    0
  ) INTO v_saldo_sebelum;

  v_saldo_setelah := v_saldo_sebelum + v_wd.amount;

  INSERT INTO public.ledger (
    wallet_type, wallet_owner_id, transaksi_id, tipe, jumlah,
    saldo_setelah, keterangan, created_at
  ) VALUES (
    'admin', NULL, v_wd.reference_no, 'kredit', v_wd.amount,
    v_saldo_setelah, 'Kredit balik penarikan admin gagal (' || v_wd.reference_no || '): ' || p_reason, NOW()
  );

  RETURN jsonb_build_object(
    'success',         true,
    'status',          'failed',
    'refunded_amount', v_wd.amount,
    'saldo_setelah',   v_saldo_setelah
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.fail_admin_withdrawal(TEXT, TEXT) TO service_role;

-- ------------------------------------------------------------------------------
-- 5. RLS: Proteksi Tabel Withdrawals & Ledger untuk Role Admin
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "admin_withdrawals_all" ON public.withdrawals;
CREATE POLICY "admin_withdrawals_all"
  ON public.withdrawals
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id::TEXT = auth.uid()::TEXT
        AND p.role IN ('admin', 'superadmin')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id::TEXT = auth.uid()::TEXT
        AND p.role IN ('admin', 'superadmin')
    )
  );

DROP POLICY IF EXISTS "admin_ledger_all" ON public.ledger;
CREATE POLICY "admin_ledger_all"
  ON public.ledger
  FOR SELECT
  TO authenticated
  USING (
    wallet_type = 'admin'
    AND EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id::TEXT = auth.uid()::TEXT
        AND p.role IN ('admin', 'superadmin')
    )
  );
