-- ==============================================================================
-- FIX ERROR PGRST203: Could not choose the best candidate function between:
-- public.request_ticket_refund_atomic(..., p_user_id => text)
-- public.request_ticket_refund_atomic(..., p_user_id => uuid)
-- ==============================================================================

-- 1. Hapus varian overload dengan p_user_id UUID agar tidak bentrok di PostgREST
DROP FUNCTION IF EXISTS public.request_ticket_refund_atomic(text, uuid, text, text, text, text, text);

-- 2. Pastikan varian p_user_id TEXT tetap ada dan meng-handle user_id secara aman
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
    v_admin_share    := v_refund_amount - v_produser_share;
  ELSE
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
        v_produser_share := (v_refund_amount * 887) / 1000;
        v_admin_share    := v_refund_amount - v_produser_share;
      END IF;
    ELSE
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
    IF p_user_id IS NOT NULL AND p_user_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
      v_user_uuid := p_user_id::UUID;
    ELSIF v_ticket.user_id::TEXT ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
      v_user_uuid := v_ticket.user_id::UUID;
    ELSE
      v_user_uuid := auth.uid();
    END IF;
  EXCEPTION WHEN OTHERS THEN
    v_user_uuid := auth.uid();
  END;

  BEGIN
    v_prod_uuid := v_concert.producer_id::UUID;
  EXCEPTION WHEN OTHERS THEN
    v_prod_uuid := NULL;
  END;

  -- 7. Update Status Tiket menjadi 'direfund'
  UPDATE public.tickets
  SET status = 'direfund',
      updated_at = NOW()
  WHERE id::TEXT = p_ticket_id::TEXT;

  -- 8. Buat Record Refund (status 'completed' agar otomatis tersinkron dan tampil di Payer App)
  INSERT INTO public.refunds (
    id, transaction_id, order_id, ticket_id, concert_id, user_id,
    refund_amount, admin_fee_retained, destination_type, destination_provider,
    destination_account_no, destination_account_name,
    reason, status, created_at, updated_at
  ) VALUES (
    v_refund_id, v_ticket.order_id, v_ticket.order_id, v_ticket.id::TEXT, v_ticket.concert_id::TEXT, v_user_uuid,
    v_refund_amount, 0, p_dest_type, p_dest_provider,
    p_dest_account_no, p_dest_account_name,
    p_reason, 'completed', NOW(), NOW()
  );

  -- 9. Pembalikan Ledger: DEBIT Saldo Produser
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

  -- 10. Pembalikan Ledger: DEBIT Saldo Admin
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

GRANT EXECUTE ON FUNCTION public.request_ticket_refund_atomic(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT) TO authenticated, service_role, anon;

NOTIFY pgrst, 'reload schema';
