-- ==============================================================================
-- FIX ERROR 42703: record "v_ticket" has no field "transaksi_id"
-- & Sinkronisasi Data Refund dengan Payer App
-- ==============================================================================

-- 1. Pastikan kolom pendukung di tabel public.refunds tersedia lengkap
ALTER TABLE public.refunds ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE public.refunds ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE public.refunds ADD COLUMN IF NOT EXISTS amount BIGINT;
ALTER TABLE public.refunds ADD COLUMN IF NOT EXISTS refund_amount BIGINT;
ALTER TABLE public.refunds ADD COLUMN IF NOT EXISTS destination_provider TEXT;
ALTER TABLE public.refunds ADD COLUMN IF NOT EXISTS bank_name TEXT;
ALTER TABLE public.refunds ADD COLUMN IF NOT EXISTS destination_account_no TEXT;
ALTER TABLE public.refunds ADD COLUMN IF NOT EXISTS account_number TEXT;
ALTER TABLE public.refunds ADD COLUMN IF NOT EXISTS destination_account_name TEXT;
ALTER TABLE public.refunds ADD COLUMN IF NOT EXISTS account_holder_name TEXT;
ALTER TABLE public.refunds ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'completed';

-- 2. Hapus varian overload UUID jika masih ada agar tidak terjadi PGRST203
DROP FUNCTION IF EXISTS public.request_ticket_refund_atomic(text, uuid, text, text, text, text, text);

-- 3. Update Fungsi Kanonikal request_ticket_refund_atomic tanpa akses field transaksi_id pada v_ticket
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

  -- 6. Hitung Nominal Refund 100% dari Orders / Tiers (Bukan dari v_ticket.transaksi_id)
  SELECT * INTO v_trans
  FROM public.orders
  WHERE id::TEXT = v_ticket.order_id::TEXT
  LIMIT 1;

  IF FOUND AND COALESCE(v_trans.quantity, v_trans.jumlah_tiket, 1) > 0 THEN
    v_refund_amount  := COALESCE(v_trans.total_amount, v_trans.total_bayar, v_trans.gross_amount, 0) / COALESCE(v_trans.quantity, v_trans.jumlah_tiket, 1);
    IF COALESCE(v_trans.bagian_produser, 0) > 0 THEN
      v_produser_share := v_trans.bagian_produser / COALESCE(v_trans.quantity, v_trans.jumlah_tiket, 1);
      v_admin_share    := v_refund_amount - v_produser_share;
    ELSE
      v_produser_share := ROUND(v_refund_amount * 0.979);
      v_admin_share    := v_refund_amount - v_produser_share;
    END IF;
  ELSE
    SELECT COALESCE(price, 0) INTO v_refund_amount
    FROM public.ticket_tiers
    WHERE id::TEXT = v_ticket.tier_id::TEXT;

    IF v_refund_amount IS NULL OR v_refund_amount <= 0 THEN
      SELECT COALESCE(price, 0) INTO v_refund_amount
      FROM public.ticket_tiers
      WHERE concert_id::TEXT = v_ticket.concert_id::TEXT
      ORDER BY price ASC
      LIMIT 1;
    END IF;

    IF v_refund_amount IS NULL OR v_refund_amount <= 0 THEN
      v_refund_amount := 100000;
    END IF;

    v_produser_share := ROUND(v_refund_amount * 0.979);
    v_admin_share    := v_refund_amount - v_produser_share;
  END IF;

  v_ticket_code := COALESCE(v_ticket.kode_tiket, v_ticket.ticket_code, v_ticket.id::TEXT);
  v_refund_id := 'RFD-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || UPPER(SUBSTRING(COALESCE(v_ticket_code, 'TIX') FROM 1 FOR 8));

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
    id,
    order_id,
    ticket_id,
    concert_id,
    user_id,
    amount,
    refund_amount,
    admin_fee_retained,
    destination_type,
    destination_provider,
    bank_name,
    destination_account_no,
    account_number,
    destination_account_name,
    account_holder_name,
    reason,
    status,
    requested_at,
    created_at,
    updated_at
  ) VALUES (
    v_refund_id,
    v_ticket.order_id,
    v_ticket.id,
    v_ticket.concert_id::TEXT,
    v_user_uuid,
    v_refund_amount,
    v_refund_amount,
    0,
    p_dest_type,
    p_dest_provider,
    p_dest_provider,
    p_dest_account_no,
    p_dest_account_no,
    p_dest_account_name,
    p_dest_account_name,
    p_reason,
    'completed',
    NOW(),
    NOW(),
    NOW()
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
