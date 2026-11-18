-- ==============================================================================
-- LIVE TIX: FASE 5 - WITHDRAW PRODUSER (SALDO TERTAHAN VS TERSEDIA)
-- File: 20261118_fase5_producer_withdrawal.sql
-- Aturan Wajib:
--   1. Produser TIDAK bisa withdraw sebelum waktu mulai konser (dicek di server).
--      Sebelum itu saldo berstatus "tertahan" dan tidak bisa ditarik.
--   2. Konser yang dibatalkan: tidak ada penarikan untuk dana tiket yang direfund.
--   3. Validasi: minimal Rp50.000, jumlah <= saldo tersedia, TIDAK ADA withdraw pending ganda.
--   4. Alur: request -> debit ledger -> payout sandbox -> sukses / gagal (kredit balik).
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. FUNGSI calculate_promoter_balance (Pembeda Saldo Tertahan vs Saldo Tersedia)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.calculate_promoter_balance(
  p_producer_id TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_total_sales     BIGINT := 0;
  v_withdrawn       BIGINT := 0;
  v_pending_wd      BIGINT := 0;
  v_available_gross BIGINT := 0;
  v_available_net   BIGINT := 0;
  v_held            BIGINT := 0;
  v_has_pending     BOOLEAN := false;
BEGIN
  -- 1. Total kredit penjualan tiket produser dari ledger
  SELECT COALESCE(SUM(jumlah), 0) INTO v_total_sales
  FROM public.ledger
  WHERE wallet_type = 'produser'
    AND COALESCE(wallet_owner_id::TEXT, '') = p_producer_id
    AND tipe = 'kredit';

  -- 2. Total debit penarikan produser yang sudah tercatat di ledger
  SELECT COALESCE(SUM(jumlah), 0) INTO v_withdrawn
  FROM public.ledger
  WHERE wallet_type = 'produser'
    AND COALESCE(wallet_owner_id::TEXT, '') = p_producer_id
    AND tipe = 'debit';

  -- 3. Cek apakah ada penarikan yang sedang pending / processing (anti withdraw ganda)
  SELECT EXISTS (
    SELECT 1 FROM public.withdrawals
    WHERE COALESCE(producer_id::TEXT, user_id::TEXT, '') = p_producer_id
      AND LOWER(status) IN ('pending', 'processing')
  ) INTO v_has_pending;

  SELECT COALESCE(SUM(amount), 0) INTO v_pending_wd
  FROM public.withdrawals
  WHERE COALESCE(producer_id::TEXT, user_id::TEXT, '') = p_producer_id
    AND LOWER(status) IN ('pending', 'processing');

  -- 4. Hitung dana dari konser yang SUDAH DIMULAI dan TIDAK DIBATALKAN
  --    Aturan: start_time <= NOW() atau date < CURRENT_DATE
  SELECT COALESCE(SUM(l.jumlah), 0) INTO v_available_gross
  FROM public.ledger l
  LEFT JOIN public.transactions t ON (t.id = l.transaksi_id OR t.order_id = l.transaksi_id)
  LEFT JOIN public.orders o ON o.id::TEXT = l.transaksi_id
  LEFT JOIN public.concerts c ON (c.id::TEXT = t.concert_id::TEXT OR c.id::TEXT = o.concert_id::TEXT)
  WHERE l.wallet_type = 'produser'
    AND COALESCE(l.wallet_owner_id::TEXT, '') = p_producer_id
    AND l.tipe = 'kredit'
    AND (
      (c.start_time IS NOT NULL AND c.start_time <= NOW())
      OR
      (c.start_time IS NULL AND c.date IS NOT NULL AND c.date < CURRENT_DATE)
    )
    AND LOWER(COALESCE(c.status, '')) NOT IN ('cancelled', 'dibatalkan');

  -- Saldo tersedia = dana konser yang sudah mulai dikurangi total penarikan
  v_available_net := GREATEST(0, v_available_gross - v_withdrawn);

  -- Saldo tertahan = sisa total penjualan dari konser yang belum mulai
  v_held := GREATEST(0, v_total_sales - v_available_gross);

  RETURN jsonb_build_object(
    'total_sales',                v_total_sales,
    'total_withdrawn',            v_withdrawn,
    'available_balance',          v_available_net,
    'pending_balance',            v_held,
    'has_pending_withdrawal',      v_has_pending,
    'pending_withdrawal_amount',  v_pending_wd
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.calculate_promoter_balance(TEXT) TO authenticated, service_role;

-- ------------------------------------------------------------------------------
-- 2. FUNGSI request_producer_withdrawal (Atomic Request & Debit Ledger)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.request_producer_withdrawal(
  p_producer_id    TEXT,
  p_amount         BIGINT,
  p_bank_name      TEXT,
  p_account_number TEXT,
  p_account_name   TEXT,
  p_concert_id     TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_balance        JSONB;
  v_available      BIGINT;
  v_has_pending    BOOLEAN;
  v_ref_no         TEXT;
  v_withdrawal_id  TEXT;
  v_saldo_sebelum  BIGINT;
  v_saldo_setelah  BIGINT;
  v_prod_uuid      UUID;
BEGIN
  -- 1. Validasi minimum nominal
  IF p_amount < 50000 THEN
    RETURN jsonb_build_object(
      'success', false,
      'code', 'MINIMUM_AMOUNT',
      'message', 'Nominal penarikan minimum adalah Rp 50.000'
    );
  END IF;

  -- 2. Anti withdraw pending ganda: cek apakah masih ada yang status pending/processing
  SELECT EXISTS (
    SELECT 1 FROM public.withdrawals
    WHERE COALESCE(producer_id::TEXT, user_id::TEXT, '') = p_producer_id
      AND LOWER(status) IN ('pending', 'processing')
  ) INTO v_has_pending;

  IF v_has_pending THEN
    RETURN jsonb_build_object(
      'success', false,
      'code', 'PENDING_WITHDRAWAL_EXISTS',
      'message', 'Masih ada penarikan dana yang sedang diproses. Mohon tunggu hingga selesai.'
    );
  END IF;

  -- 3. Hitung saldo tersedia saat ini dari ledger
  v_balance   := public.calculate_promoter_balance(p_producer_id);
  v_available := (v_balance->>'available_balance')::BIGINT;

  IF p_amount > v_available THEN
    RETURN jsonb_build_object(
      'success', false,
      'code', 'INSUFFICIENT_AVAILABLE_BALANCE',
      'message', 'Saldo tersedia tidak mencukupi (Tersedia: Rp ' || v_available || '). Saldo konser yang belum dimulai berstatus tertahan.',
      'available_balance', v_available,
      'pending_balance', (v_balance->>'pending_balance')::BIGINT
    );
  END IF;

  -- 4. Ambil saldo terakhir dari ledger produser
  SELECT COALESCE(
    (SELECT saldo_setelah FROM public.ledger
     WHERE wallet_type = 'produser' AND COALESCE(wallet_owner_id::TEXT, '') = p_producer_id
     ORDER BY created_at DESC LIMIT 1),
    0
  ) INTO v_saldo_sebelum;

  IF p_amount > v_saldo_sebelum THEN
    RETURN jsonb_build_object(
      'success', false,
      'code', 'INSUFFICIENT_LEDGER_BALANCE',
      'message', 'Saldo buku besar produser tidak mencukupi.'
    );
  END IF;

  v_saldo_setelah := v_saldo_sebelum - p_amount;
  v_ref_no := 'WD-PRD-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || UPPER(SUBSTRING(encode(gen_random_bytes(4), 'hex'), 1, 8));
  v_withdrawal_id := 'wd_' || encode(gen_random_bytes(8), 'hex');

  -- Parse UUID producer jika valid
  BEGIN
    v_prod_uuid := p_producer_id::UUID;
  EXCEPTION WHEN OTHERS THEN
    v_prod_uuid := NULL;
  END;

  -- 5. Insert ke tabel withdrawals
  INSERT INTO public.withdrawals (
    id, reference_no, user_id, producer_id, role, concert_id,
    amount, bank_name, account_number, account_name, status, created_at
  ) VALUES (
    v_withdrawal_id, v_ref_no, v_prod_uuid, v_prod_uuid, 'produser', p_concert_id,
    p_amount, p_bank_name, p_account_number, p_account_name, 'pending', NOW()
  );

  -- 6. Tulis DEBIT ke ledger append-only
  INSERT INTO public.ledger (
    wallet_type, wallet_owner_id, transaksi_id, tipe, jumlah,
    saldo_setelah, keterangan, created_at
  ) VALUES (
    'produser', v_prod_uuid, v_ref_no, 'debit', p_amount,
    v_saldo_setelah, 'Penarikan dana produser: ' || v_ref_no || ' ke ' || p_bank_name || ' ' || p_account_number, NOW()
  );

  RETURN jsonb_build_object(
    'success',       true,
    'withdrawal_id', v_withdrawal_id,
    'reference_no',  v_ref_no,
    'amount',        p_amount,
    'saldo_setelah', v_saldo_setelah,
    'message',       'Permohonan penarikan dana Rp ' || p_amount || ' berhasil dibuat dan sedang diproses.'
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.request_producer_withdrawal(TEXT, BIGINT, TEXT, TEXT, TEXT, TEXT) TO authenticated, service_role;

-- ------------------------------------------------------------------------------
-- 3. FUNGSI complete_producer_withdrawal (Payout Berhasil)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.complete_producer_withdrawal(
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
      iris_payout_id = COALESCE(p_iris_id, iris_payout_id, 'iris_' || TO_CHAR(NOW(), 'YYYYMMDDHH24MISS')),
      completed_at = NOW()
  WHERE id = p_withdrawal_id OR reference_no = p_withdrawal_id;

  RETURN jsonb_build_object('success', true, 'status', 'success');
END;
$$;

GRANT EXECUTE ON FUNCTION public.complete_producer_withdrawal(TEXT, TEXT) TO service_role;

-- ------------------------------------------------------------------------------
-- 4. FUNGSI fail_producer_withdrawal (Payout Gagal -> Kredit Balik Ledger)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fail_producer_withdrawal(
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
    RETURN jsonb_build_object('success', false, 'message', 'Withdrawal tidak ditemukan');
  END IF;

  IF v_wd.status = 'failed' THEN
    RETURN jsonb_build_object('success', true, 'message', 'Withdrawal sudah dibatalkan sebelumnya');
  END IF;

  -- 1. Tandai failed pada tabel withdrawals
  UPDATE public.withdrawals
  SET status = 'failed',
      rejection_reason = p_reason
  WHERE id = v_wd.id;

  -- 2. Ambil saldo terakhir untuk rekonsiliasi kredit balik
  SELECT COALESCE(
    (SELECT saldo_setelah FROM public.ledger
     WHERE wallet_type = 'produser' AND wallet_owner_id = v_wd.producer_id
     ORDER BY created_at DESC LIMIT 1),
    0
  ) INTO v_saldo_sebelum;

  v_saldo_setelah := v_saldo_sebelum + v_wd.amount;

  -- 3. Tulis KREDIT BALIK ke ledger append-only
  INSERT INTO public.ledger (
    wallet_type, wallet_owner_id, transaksi_id, tipe, jumlah,
    saldo_setelah, keterangan, created_at
  ) VALUES (
    'produser', v_wd.producer_id, v_wd.reference_no, 'kredit', v_wd.amount,
    v_saldo_setelah, 'Kredit balik penarikan gagal (' || v_wd.reference_no || '): ' || p_reason, NOW()
  );

  RETURN jsonb_build_object(
    'success',         true,
    'status',          'failed',
    'refunded_amount', v_wd.amount,
    'saldo_setelah',   v_saldo_setelah
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.fail_producer_withdrawal(TEXT, TEXT) TO service_role;

-- ------------------------------------------------------------------------------
-- 5. RLS: Produser Membaca dan Membuat Withdrawal Miliknya Sendiri
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "withdrawals_select_policy" ON public.withdrawals;
CREATE POLICY "withdrawals_select_policy"
  ON public.withdrawals
  FOR SELECT
  TO authenticated
  USING (
    COALESCE(producer_id::TEXT, user_id::TEXT, '') = auth.uid()::TEXT
    OR
    EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id::TEXT = auth.uid()::TEXT
        AND p.role IN ('admin', 'superadmin')
    )
  );
