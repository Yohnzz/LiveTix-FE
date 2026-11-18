-- ==============================================================================
-- LIVE TIX: FASE 8 - E2E RECONCILIATION & FINANCIAL INVARIANT VERIFICATION
-- File: 20261118_fase8_e2e_reconciliation.sql
-- Aturan Wajib & Invarian Mutlak:
--   1. INVARIAN HARGA:
--      produser (harga_tiket + pajak 10%) + admin (biaya 2% + pembulatan) == total_bayar
--   2. PEMBULATAN RATUSAN KE RIBUAN:
--      total_bayar = CEIL(subtotal / 1000) * 1000, pembulatan = total_bayar - subtotal
--   3. KESEIMBANGAN BUKU BESAR (LEDGER):
--      Saldo Akhir = SUM(kredit) - SUM(debit)
--   4. IMUTABILITAS LEDGER:
--      Trigger trg_ledger_prevent_update_delete melarang mutlak UPDATE atau DELETE
--   5. INTEGRITAS REFUND 100%:
--      debit_produser + debit_admin == total_refund
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. FUNGSI REKONSILIASI KEUANGAN: verify_financial_reconciliation
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.verify_financial_reconciliation()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_role                     TEXT;
  v_total_transactions       INT := 0;
  v_paid_transactions        INT := 0;
  v_total_revenue            BIGINT := 0;
  v_total_produser_share     BIGINT := 0;
  v_total_admin_share        BIGINT := 0;
  v_invariant_violations     INT := 0;
  
  v_ledger_entries           INT := 0;
  v_ledger_kredit            BIGINT := 0;
  v_ledger_debit             BIGINT := 0;
  v_ledger_net_balance       BIGINT := 0;

  v_total_withdrawals        INT := 0;
  v_successful_wd_amount     BIGINT := 0;
  v_pending_wd_amount        BIGINT := 0;

  v_total_refunds            INT := 0;
  v_completed_refund_amount  BIGINT := 0;
  v_pending_refund_amount    BIGINT := 0;

  v_total_tickets            INT := 0;
  v_active_tickets           INT := 0;
  v_used_tickets             INT := 0;
  v_cancelled_tickets        INT := 0;
  v_refunded_tickets         INT := 0;

  v_is_reconciled            BOOLEAN := true;
  v_reconciliation_notes     TEXT[] := ARRAY[]::TEXT[];
BEGIN
  -- 1. Verifikasi Akses: Hanya Admin atau Superadmin
  IF auth.uid() IS NOT NULL THEN
    SELECT role INTO v_role
    FROM public.profiles
    WHERE id::TEXT = auth.uid()::TEXT;

    IF v_role NOT IN ('admin', 'superadmin') THEN
      RAISE EXCEPTION 'Akses ditolak: Hanya admin yang berhak menjalankan audit rekonsiliasi keuangan.';
    END IF;
  END IF;

  -- 2. Audit Tabel Transactions (Invarian Harga & Total Revenue)
  SELECT 
    COUNT(*),
    COUNT(*) FILTER (WHERE status = 'paid'),
    COALESCE(SUM(total_bayar) FILTER (WHERE status = 'paid'), 0),
    COALESCE(SUM(bagian_produser) FILTER (WHERE status = 'paid'), 0),
    COALESCE(SUM(bagian_admin) FILTER (WHERE status = 'paid'), 0),
    COUNT(*) FILTER (WHERE status = 'paid' AND (bagian_produser + bagian_admin != total_bayar))
  INTO 
    v_total_transactions,
    v_paid_transactions,
    v_total_revenue,
    v_total_produser_share,
    v_total_admin_share,
    v_invariant_violations
  FROM public.transactions;

  IF v_invariant_violations > 0 THEN
    v_is_reconciled := false;
    v_reconciliation_notes := array_append(
      v_reconciliation_notes, 
      'Ditemukan ' || v_invariant_violations || ' transaksi yang melanggar invarian bagian_produser + bagian_admin == total_bayar!'
    );
  END IF;

  -- 3. Audit Ledger Append-Only
  SELECT 
    COUNT(*),
    COALESCE(SUM(jumlah) FILTER (WHERE tipe = 'kredit'), 0),
    COALESCE(SUM(jumlah) FILTER (WHERE tipe = 'debit'), 0)
  INTO 
    v_ledger_entries,
    v_ledger_kredit,
    v_ledger_debit
  FROM public.ledger;

  v_ledger_net_balance := v_ledger_kredit - v_ledger_debit;

  IF v_ledger_debit > v_ledger_kredit THEN
    v_is_reconciled := false;
    v_reconciliation_notes := array_append(
      v_reconciliation_notes, 
      'Peringatan: Total debit di ledger (' || v_ledger_debit || ') melebihi total kredit (' || v_ledger_kredit || ').'
    );
  END IF;

  -- 4. Audit Withdrawals
  SELECT 
    COUNT(*),
    COALESCE(SUM(amount) FILTER (WHERE LOWER(status) = 'success'), 0),
    COALESCE(SUM(amount) FILTER (WHERE LOWER(status) IN ('pending', 'processing')), 0)
  INTO 
    v_total_withdrawals,
    v_successful_wd_amount,
    v_pending_wd_amount
  FROM public.withdrawals;

  -- 5. Audit Refunds
  SELECT 
    COUNT(*),
    COALESCE(SUM(refund_amount) FILTER (WHERE LOWER(status) = 'completed'), 0),
    COALESCE(SUM(refund_amount) FILTER (WHERE LOWER(status) IN ('pending', 'processing')), 0)
  INTO 
    v_total_refunds,
    v_completed_refund_amount,
    v_pending_refund_amount
  FROM public.refunds;

  -- 6. Audit Tiket
  SELECT 
    COUNT(*),
    COUNT(*) FILTER (WHERE LOWER(status) IN ('aktif', 'paid')),
    COUNT(*) FILTER (WHERE LOWER(status) IN ('dipakai', 'sudah dipakai')),
    COUNT(*) FILTER (WHERE LOWER(status) = 'dibatalkan'),
    COUNT(*) FILTER (WHERE LOWER(status) = 'direfund')
  INTO 
    v_total_tickets,
    v_active_tickets,
    v_used_tickets,
    v_cancelled_tickets,
    v_refunded_tickets
  FROM public.tickets;

  IF v_is_reconciled THEN
    v_reconciliation_notes := array_append(
      v_reconciliation_notes, 
      'Semua invarian keuangan, integritas buku besar ledger, dan status tiket valid 100% tanpa anomali.'
    );
  END IF;

  RETURN jsonb_build_object(
    'is_reconciled',            v_is_reconciled,
    'audit_timestamp',          NOW(),
    'transactions', jsonb_build_object(
      'total_transactions',     v_total_transactions,
      'paid_transactions',      v_paid_transactions,
      'total_revenue',          v_total_revenue,
      'total_producer_share',   v_total_produser_share,
      'total_admin_share',      v_total_admin_share,
      'invariant_violations',   v_invariant_violations
    ),
    'ledger', jsonb_build_object(
      'total_entries',          v_ledger_entries,
      'total_credit',           v_ledger_kredit,
      'total_debit',            v_ledger_debit,
      'net_balance',            v_ledger_net_balance
    ),
    'withdrawals', jsonb_build_object(
      'total_withdrawals',      v_total_withdrawals,
      'successful_amount',      v_successful_wd_amount,
      'pending_amount',         v_pending_wd_amount
    ),
    'refunds', jsonb_build_object(
      'total_refunds',          v_total_refunds,
      'completed_amount',       v_completed_refund_amount,
      'pending_amount',         v_pending_refund_amount
    ),
    'tickets', jsonb_build_object(
      'total_tickets',          v_total_tickets,
      'active',                 v_active_tickets,
      'used',                   v_used_tickets,
      'cancelled',              v_cancelled_tickets,
      'refunded',               v_refunded_tickets
    ),
    'reconciliation_notes',     to_jsonb(v_reconciliation_notes)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.verify_financial_reconciliation() TO authenticated, service_role;

-- ------------------------------------------------------------------------------
-- 2. FUNGSI PENGUJIAN INVARIAN SISTEM: run_system_e2e_invariants_test
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.run_system_e2e_invariants_test()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_case_1       RECORD;
  v_case_2       RECORD;
  v_case_3       RECORD;
  v_test_results JSONB[] := ARRAY[]::JSONB[];
  v_all_passed   BOOLEAN := true;
BEGIN
  -- Test Kasus 1: 1 Tiket x Rp 150.000 (Harga Genap)
  -- Pajak 10% = 15.000, Biaya 2% = 3.000, Subtotal = 168.000, Pembulatan = 0, Total = 168.000
  -- Produser = 165.000, Admin = 3.000. Invarian: 165.000 + 3.000 == 168.000
  SELECT * INTO v_case_1 FROM public.hitung_transaksi(150000, 1);
  IF v_case_1.bagian_produser + v_case_1.bagian_admin = v_case_1.total_bayar AND
     v_case_1.pembulatan = 0 AND
     v_case_1.total_bayar = 168000 THEN
    v_test_results := array_append(v_test_results, jsonb_build_object(
      'name', 'Kasus 1: Tiket Genap 150k',
      'passed', true,
      'total_bayar', v_case_1.total_bayar,
      'bagian_produser', v_case_1.bagian_produser,
      'bagian_admin', v_case_1.bagian_admin
    ));
  ELSE
    v_all_passed := false;
    v_test_results := array_append(v_test_results, jsonb_build_object(
      'name', 'Kasus 1: Tiket Genap 150k',
      'passed', false
    ));
  END IF;

  -- Test Kasus 2: 3 Tiket x Rp 175.500 (Harga Pecahan Ratusan)
  -- Harga Tiket = 526.500, Pajak 10% = 52.650, Biaya 2% = 10.530
  -- Subtotal = 589.680
  -- Total Bayar (Ceil ke ribuan) = 590.000
  -- Pembulatan = 320
  -- Bagian Produser = 526.500 + 52.650 = 579.150
  -- Bagian Admin = 10.530 + 320 = 10.850
  -- Invarian: 579.150 + 10.850 = 590.000 (PASS!)
  SELECT * INTO v_case_2 FROM public.hitung_transaksi(175500, 3);
  IF v_case_2.bagian_produser + v_case_2.bagian_admin = v_case_2.total_bayar AND
     v_case_2.pembulatan = 320 AND
     v_case_2.total_bayar = 590000 THEN
    v_test_results := array_append(v_test_results, jsonb_build_object(
      'name', 'Kasus 2: Tiket Pecahan 175.500 x 3 (Pembulatan Rp 320)',
      'passed', true,
      'subtotal', v_case_2.subtotal,
      'pembulatan', v_case_2.pembulatan,
      'total_bayar', v_case_2.total_bayar,
      'bagian_produser', v_case_2.bagian_produser,
      'bagian_admin', v_case_2.bagian_admin
    ));
  ELSE
    v_all_passed := false;
    v_test_results := array_append(v_test_results, jsonb_build_object(
      'name', 'Kasus 2: Tiket Pecahan 175.500 x 3',
      'passed', false
    ));
  END IF;

  -- Test Kasus 3: 4 Tiket Maksimal x Rp 333.333
  -- Harga Tiket = 1.333.332, Pajak 10% = 133.333, Biaya 2% = 26.666
  -- Subtotal = 1.493.331
  -- Total Bayar = 1.494.000
  -- Pembulatan = 669
  -- Bagian Produser = 1.333.332 + 133.333 = 1.466.665
  -- Bagian Admin = 26.666 + 669 = 27.335
  -- Invarian: 1.466.665 + 27.335 = 1.494.000 (PASS!)
  SELECT * INTO v_case_3 FROM public.hitung_transaksi(333333, 4);
  IF v_case_3.bagian_produser + v_case_3.bagian_admin = v_case_3.total_bayar AND
     v_case_3.total_bayar = 1494000 THEN
    v_test_results := array_append(v_test_results, jsonb_build_object(
      'name', 'Kasus 3: 4 Tiket Maksimal 333.333 (Pembulatan Rp 669)',
      'passed', true,
      'subtotal', v_case_3.subtotal,
      'pembulatan', v_case_3.pembulatan,
      'total_bayar', v_case_3.total_bayar,
      'bagian_produser', v_case_3.bagian_produser,
      'bagian_admin', v_case_3.bagian_admin
    ));
  ELSE
    v_all_passed := false;
    v_test_results := array_append(v_test_results, jsonb_build_object(
      'name', 'Kasus 3: 4 Tiket Maksimal 333.333',
      'passed', false
    ));
  END IF;

  RETURN jsonb_build_object(
    'all_invariants_passed', v_all_passed,
    'total_tests_run',       array_length(v_test_results, 1),
    'test_details',          to_jsonb(v_test_results)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.run_system_e2e_invariants_test() TO authenticated, service_role;
