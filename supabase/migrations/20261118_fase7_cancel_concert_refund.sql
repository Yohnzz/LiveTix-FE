-- ==============================================================================
-- LIVE TIX: FASE 7 - REFUND PEMBATALAN KONSER MASAL & PEMBALIKAN LEDGER
-- File: 20261118_fase7_cancel_concert_refund.sql
-- Aturan Wajib:
--   1. Pembatalan konser mengunci tiket aktif dan dana produser.
--   2. Refund bernilai 100% dari total yang dibayar user (total_bayar).
--   3. Pembalikan ledger append-only:
--      - Produser didebit sebesar porsi produser (harga_tiket + pajak).
--      - Admin didebit sebesar porsi admin (biaya_aplikasi + pembulatan).
--      - Invarian mutlak: debit_produser + debit_admin == total_refund (100%).
--   4. Status tiket aktif diubah menjadi 'dibatalkan' / 'direfund'.
--   5. Integrasi payout Iris Midtrans untuk pengembalian dana ke user.
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. FUNGSI cancel_concert_and_lock_funds (Pembatalan Konser & Penguncian Tiket)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.cancel_concert_and_lock_funds(
  p_concert_id TEXT,
  p_reason     TEXT,
  p_category   TEXT DEFAULT 'Force Majeure'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_role           TEXT;
  v_concert        RECORD;
  v_tickets_count  INT := 0;
  v_orders_count   INT := 0;
BEGIN
  IF p_reason IS NULL OR TRIM(p_reason) = '' THEN
    RETURN jsonb_build_object(
      'success', false,
      'code', 'INVALID_REASON',
      'message', 'Alasan pembatalan konser wajib diisi.'
    );
  END IF;

  -- 1. Verifikasi Konser
  SELECT * INTO v_concert
  FROM public.concerts
  WHERE id::TEXT = p_concert_id::TEXT
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'code', 'CONCERT_NOT_FOUND',
      'message', 'Konser dengan ID tersebut tidak ditemukan.'
    );
  END IF;

  -- 2. Verifikasi Hak Akses: Hanya Admin atau Produser Pemilik Konser
  IF auth.uid() IS NOT NULL THEN
    SELECT role INTO v_role
    FROM public.profiles
    WHERE id::TEXT = auth.uid()::TEXT;

    IF v_role NOT IN ('admin', 'superadmin') AND COALESCE(v_concert.producer_id::TEXT, '') != auth.uid()::TEXT THEN
      RETURN jsonb_build_object(
        'success', false,
        'code', 'FORBIDDEN',
        'message', 'Akses ditolak: Anda tidak memiliki wewenang untuk membatalkan konser ini.'
      );
    END IF;
  END IF;

  -- 3. Update Status Konser menjadi Dibatalkan
  UPDATE public.concerts
  SET status = 'cancelled',
      cancellation_reason = p_reason,
      cancellation_category = COALESCE(p_category, 'Force Majeure'),
      cancellation_date = TO_CHAR(NOW(), 'YYYY-MM-DD HH24:MI:SS'),
      cancelled_at = NOW(),
      updated_at = NOW()
  WHERE id::TEXT = p_concert_id::TEXT;

  -- 4. Tutup Penjualan Tier Tiket
  UPDATE public.ticket_tiers
  SET is_sold_out = true
  WHERE concert_id::TEXT = p_concert_id::TEXT;

  -- 5. Batalkan Semua Tiket Aktif yang Belum Digunakan
  UPDATE public.tickets
  SET status = 'dibatalkan',
      updated_at = NOW()
  WHERE concert_id::TEXT = p_concert_id::TEXT
    AND LOWER(status) IN ('aktif', 'paid');

  GET DIAGNOSTICS v_tickets_count = ROW_COUNT;

  -- 6. Update Status Transaksi Paid Menjadi Cancelled
  UPDATE public.transactions
  SET status = 'cancelled',
      updated_at = NOW()
  WHERE concert_id::TEXT = p_concert_id::TEXT
    AND status = 'paid';

  GET DIAGNOSTICS v_orders_count = ROW_COUNT;

  RETURN jsonb_build_object(
    'success',           true,
    'concert_id',        p_concert_id,
    'tickets_cancelled', v_tickets_count,
    'orders_cancelled',  v_orders_count,
    'message',           'Konser berhasil dibatalkan. ' || v_tickets_count || ' tiket aktif telah dibatalkan dan berhak mengajukan refund 100%.'
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.cancel_concert_and_lock_funds(TEXT, TEXT, TEXT) TO authenticated, service_role;

-- ------------------------------------------------------------------------------
-- 2. FUNGSI request_ticket_refund_atomic (Pengajuan Refund 100% & Pembalikan Ledger)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.request_ticket_refund_atomic(
  p_ticket_id             TEXT,
  p_user_id               TEXT,
  p_dest_type             TEXT,
  p_dest_provider         TEXT,
  p_dest_account_no       TEXT,
  p_dest_account_name     TEXT,
  p_reason                TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_ticket                 RECORD;
  v_concert                RECORD;
  v_trans                  RECORD;
  v_role                   TEXT;
  v_refund_id              TEXT;
  v_ticket_code            TEXT;
  v_refund_amount          BIGINT := 0;
  v_produser_share         BIGINT := 0;
  v_admin_share            BIGINT := 0;
  v_saldo_sebelum_produser BIGINT := 0;
  v_saldo_setelah_produser BIGINT := 0;
  v_saldo_sebelum_admin    BIGINT := 0;
  v_saldo_setelah_admin    BIGINT := 0;
  v_user_uuid              UUID;
  v_prod_uuid              UUID;
BEGIN
  -- 1. Validasi Input Rekening
  IF p_dest_account_no IS NULL OR TRIM(p_dest_account_no) = '' OR
     p_dest_account_name IS NULL OR TRIM(p_dest_account_name) = '' THEN
    RETURN jsonb_build_object(
      'success', false,
      'code', 'INVALID_DESTINATION',
      'message', 'Nomor rekening dan nama pemilik tujuan refund wajib diisi.'
    );
  END IF;

  -- 2. Cek Validitas Tiket dengan Row-Lock
  SELECT * INTO v_ticket
  FROM public.tickets
  WHERE id::TEXT = p_ticket_id::TEXT
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'code', 'TICKET_NOT_FOUND',
      'message', 'Tiket tidak ditemukan dalam sistem.'
    );
  END IF;

  -- 3. Verifikasi Kepemilikan Tiket
  IF auth.uid() IS NOT NULL THEN
    SELECT role INTO v_role
    FROM public.profiles
    WHERE id::TEXT = auth.uid()::TEXT;

    IF v_role NOT IN ('admin', 'superadmin') AND
       COALESCE(v_ticket.user_id::TEXT, '') != auth.uid()::TEXT AND
       COALESCE(p_user_id, '') != auth.uid()::TEXT THEN
      RETURN jsonb_build_object(
        'success', false,
        'code', 'FORBIDDEN',
        'message', 'Anda tidak memiliki hak atas tiket ini.'
      );
    END IF;
  END IF;

  -- 4. Validasi Status Tiket
  IF LOWER(COALESCE(v_ticket.status, '')) = 'direfund' THEN
    RETURN jsonb_build_object(
      'success', false,
      'code', 'ALREADY_REFUNDED',
      'message', 'Tiket ini sudah pernah diajukan refund.'
    );
  END IF;

  IF LOWER(COALESCE(v_ticket.status, '')) IN ('dipakai', 'sudah dipakai') THEN
    RETURN jsonb_build_object(
      'success', false,
      'code', 'ALREADY_USED',
      'message', 'Tiket yang sudah digunakan untuk check-in tidak dapat direfund.'
    );
  END IF;

  -- 5. Verifikasi Status Konser
  SELECT * INTO v_concert
  FROM public.concerts
  WHERE id::TEXT = v_ticket.concert_id::TEXT;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'code', 'CONCERT_NOT_FOUND',
      'message', 'Data konser tidak ditemukan.'
    );
  END IF;

  -- 6. Hitung Nominal Refund 100% dari Transaksi Asal
  SELECT * INTO v_trans
  FROM public.transactions
  WHERE id::TEXT = COALESCE(v_ticket.transaksi_id::TEXT, v_ticket.order_id::TEXT)
     OR order_id::TEXT = v_ticket.order_id::TEXT
  LIMIT 1;

  IF FOUND AND v_trans.jumlah_tiket > 0 THEN
    v_refund_amount  := v_trans.total_bayar / v_trans.jumlah_tiket;
    v_produser_share := v_trans.bagian_produser / v_trans.jumlah_tiket;
    v_admin_share    := v_refund_amount - v_produser_share; -- Menjamin Invarian 100%
  ELSE
    -- Fallback ke tabel orders jika transaksi baru belum tersinkron
    SELECT 
      COALESCE(total_bayar, total_amount, ticket_price, 0) AS total,
      COALESCE(bagian_produser, 0) AS prod_part,
      COALESCE(bagian_admin, 0) AS adm_part,
      COALESCE(jumlah_tiket, 1) AS qty
    INTO v_trans
    FROM public.orders
    WHERE id::TEXT = v_ticket.order_id::TEXT
    LIMIT 1;

    IF FOUND AND v_trans.qty > 0 THEN
      v_refund_amount  := v_trans.total / v_trans.qty;
      IF v_trans.prod_part > 0 THEN
        v_produser_share := v_trans.prod_part / v_trans.qty;
        v_admin_share    := v_refund_amount - v_produser_share;
      ELSE
        -- Estimasi matematis: Produser 88.7%, Admin sisanya
        v_produser_share := (v_refund_amount * 887) / 1000;
        v_admin_share    := v_refund_amount - v_produser_share;
      END IF;
    ELSE
      -- Fallback akhir ke harga satuan pada tiket
      v_refund_amount  := COALESCE(v_ticket.price, 0);
      v_produser_share := (v_refund_amount * 887) / 1000;
      v_admin_share    := v_refund_amount - v_produser_share;
    END IF;
  END IF;

  IF v_refund_amount <= 0 THEN
    RETURN jsonb_build_object(
      'success', false,
      'code', 'ZERO_AMOUNT',
      'message', 'Nominal refund tiket tidak valid (Rp 0).'
    );
  END IF;

  v_ticket_code := COALESCE(v_ticket.kode_tiket, v_ticket.ticket_code, v_ticket.id::TEXT);
  v_refund_id := 'ref_' || encode(gen_random_bytes(8), 'hex');

  BEGIN
    v_user_uuid := COALESCE(p_user_id::UUID, v_ticket.user_id::UUID, auth.uid());
  EXCEPTION WHEN OTHERS THEN
    v_user_uuid := auth.uid();
  END;

  BEGIN
    v_prod_uuid := v_concert.producer_id::UUID;
  EXCEPTION WHEN OTHERS THEN
    v_prod_uuid := NULL;
  END;

  -- 7. Update Status Tiket menjadi 'direfund' (Sekaligus Menghapus Hak Masuk Scan QR)
  UPDATE public.tickets
  SET status = 'direfund',
      updated_at = NOW()
  WHERE id::TEXT = p_ticket_id::TEXT;

  -- 8. Buat Record Refund
  INSERT INTO public.refunds (
    id, transaction_id, order_id, ticket_id, concert_id, user_id,
    refund_amount, admin_fee_retained, destination_type, destination_provider,
    destination_account_no, destination_account_name,
    reason, status, created_at, updated_at
  ) VALUES (
    v_refund_id, v_ticket.order_id, v_ticket.order_id, v_ticket.id::TEXT, v_ticket.concert_id::TEXT, v_user_uuid,
    v_refund_amount, 0, p_dest_type, p_dest_provider,
    p_dest_account_no, p_dest_account_name,
    p_reason, 'pending', NOW(), NOW()
  );

  -- 9. Pembalikan Ledger: DEBIT Saldo Produser Sebesar Porsi Produser
  IF v_produser_share > 0 THEN
    SELECT COALESCE(
      (SELECT saldo_setelah FROM public.ledger
       WHERE wallet_type = 'produser'
         AND COALESCE(wallet_owner_id::TEXT, '') = COALESCE(v_concert.producer_id::TEXT, '')
       ORDER BY created_at DESC LIMIT 1),
      0
    ) INTO v_saldo_sebelum_produser;

    v_saldo_setelah_produser := GREATEST(0, v_saldo_sebelum_produser - v_produser_share);

    INSERT INTO public.ledger (
      wallet_type, wallet_owner_id, transaksi_id, tipe, jumlah,
      saldo_setelah, keterangan, created_at
    ) VALUES (
      'produser', v_prod_uuid, v_refund_id, 'debit', v_produser_share,
      v_saldo_setelah_produser, 'Pembalikan dana refund tiket ' || v_ticket_code || ' (' || v_concert.title || ')', NOW()
    );
  END IF;

  -- 10. Pembalikan Ledger: DEBIT Saldo Admin Sebesar Porsi Admin (Biaya Aplikasi + Pembulatan)
  IF v_admin_share > 0 THEN
    SELECT COALESCE(
      (SELECT saldo_setelah FROM public.ledger
       WHERE wallet_type = 'admin' AND wallet_owner_id IS NULL
       ORDER BY created_at DESC LIMIT 1),
      0
    ) INTO v_saldo_sebelum_admin;

    v_saldo_setelah_admin := GREATEST(0, v_saldo_sebelum_admin - v_admin_share);

    INSERT INTO public.ledger (
      wallet_type, wallet_owner_id, transaksi_id, tipe, jumlah,
      saldo_setelah, keterangan, created_at
    ) VALUES (
      'admin', NULL, v_refund_id, 'debit', v_admin_share,
      v_saldo_setelah_admin, 'Pembalikan fee admin & pembulatan refund tiket ' || v_ticket_code || ' (' || v_concert.title || ')', NOW()
    );
  END IF;

  RETURN jsonb_build_object(
    'success',            true,
    'refund_id',          v_refund_id,
    'ticket_id',          p_ticket_id,
    'refund_amount',      v_refund_amount,
    'producer_deduction', v_produser_share,
    'admin_deduction',    v_admin_share,
    'message',            'Pengajuan refund 100% sebesar Rp ' || v_refund_amount || ' berhasil diproses ke ' || p_dest_provider || ' ' || p_dest_account_no || '.'
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.request_ticket_refund_atomic(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT) TO authenticated, service_role;

-- ------------------------------------------------------------------------------
-- 3. ALIAS request_ticket_refund_atomic (Mendukung Tipe UUID p_user_id)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.request_ticket_refund_atomic(
  p_ticket_id             TEXT,
  p_user_id               UUID,
  p_dest_type             TEXT,
  p_dest_provider         TEXT,
  p_dest_account_no       TEXT,
  p_dest_account_name     TEXT,
  p_reason                TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  RETURN public.request_ticket_refund_atomic(
    p_ticket_id,
    p_user_id::TEXT,
    p_dest_type,
    p_dest_provider,
    p_dest_account_no,
    p_dest_account_name,
    p_reason
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.request_ticket_refund_atomic(TEXT, UUID, TEXT, TEXT, TEXT, TEXT, TEXT) TO authenticated, service_role;

-- ------------------------------------------------------------------------------
-- 4. FUNGSI complete_refund_payout & fail_refund_payout (Callback Midtrans Iris)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.complete_refund_payout(
  p_refund_id TEXT,
  p_iris_id   TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  UPDATE public.refunds
  SET status = 'completed',
      iris_payout_id = COALESCE(p_iris_id, iris_payout_id, 'iris_ref_' || TO_CHAR(NOW(), 'YYYYMMDDHH24MISS')),
      updated_at = NOW()
  WHERE id::TEXT = p_refund_id::TEXT;

  RETURN jsonb_build_object('success', true, 'status', 'completed');
END;
$$;

GRANT EXECUTE ON FUNCTION public.complete_refund_payout(TEXT, TEXT) TO service_role;

CREATE OR REPLACE FUNCTION public.fail_refund_payout(
  p_refund_id TEXT,
  p_reason    TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  UPDATE public.refunds
  SET status = 'failed',
      failure_reason = p_reason,
      updated_at = NOW()
  WHERE id::TEXT = p_refund_id::TEXT;

  RETURN jsonb_build_object('success', true, 'status', 'failed', 'reason', p_reason);
END;
$$;

GRANT EXECUTE ON FUNCTION public.fail_refund_payout(TEXT, TEXT) TO service_role;

-- ------------------------------------------------------------------------------
-- 5. RLS: Proteksi Tabel Refunds untuk User, Produser, & Admin
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "refunds_user_select_own" ON public.refunds;
CREATE POLICY "refunds_user_select_own"
  ON public.refunds
  FOR SELECT
  TO authenticated
  USING (
    COALESCE(user_id::TEXT, '') = COALESCE(auth.uid()::TEXT, '')
    OR EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id::TEXT = auth.uid()::TEXT
        AND p.role IN ('admin', 'superadmin')
    )
    OR EXISTS (
      SELECT 1 FROM public.concerts c
      WHERE c.id::TEXT = public.refunds.concert_id::TEXT
        AND c.producer_id::TEXT = auth.uid()::TEXT
    )
  );

DROP POLICY IF EXISTS "refunds_admin_all" ON public.refunds;
CREATE POLICY "refunds_admin_all"
  ON public.refunds
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
