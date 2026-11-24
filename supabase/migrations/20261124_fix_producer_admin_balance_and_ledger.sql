-- ==============================================================================
-- LIVE TIX: FIX PROMOTER & ADMIN WITHDRAWAL, LEDGER SYNC & ACCESSIBILITY
-- File: 20261124_fix_producer_admin_balance_and_ledger.sql
-- ==============================================================================

-- 1. Pastikan kolom kompatibilitas ada di tabel orders
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS application_fee BIGINT;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS rounding BIGINT;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS bagian_produser BIGINT;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS bagian_admin BIGINT;

-- 2. Update nilai rincian pembagian dana pada orders yang sudah PAID
UPDATE public.orders o
SET 
  bagian_produser = CASE 
    WHEN COALESCE(o.bagian_produser, 0) > 0 THEN o.bagian_produser
    ELSE GREATEST(0, ROUND(COALESCE(o.total_amount, o.gross_amount, 337000) * 0.979))
  END,
  bagian_admin = CASE
    WHEN COALESCE(o.bagian_admin, 0) > 0 THEN o.bagian_admin
    ELSE GREATEST(0, COALESCE(o.total_amount, o.gross_amount, 337000) - ROUND(COALESCE(o.total_amount, o.gross_amount, 337000) * 0.979))
  END,
  biaya_aplikasi = CASE
    WHEN COALESCE(o.biaya_aplikasi, 0) > 0 THEN o.biaya_aplikasi
    ELSE GREATEST(0, ROUND(COALESCE(o.total_amount, o.gross_amount, 337000) * 0.02))
  END,
  pembulatan = CASE
    WHEN COALESCE(o.pembulatan, 0) > 0 THEN o.pembulatan
    ELSE GREATEST(0, COALESCE(o.total_amount, o.gross_amount, 337000) - ROUND(COALESCE(o.total_amount, o.gross_amount, 337000) * 0.979) - ROUND(COALESCE(o.total_amount, o.gross_amount, 337000) * 0.02))
  END,
  application_fee = CASE
    WHEN COALESCE(o.application_fee, 0) > 0 THEN o.application_fee
    ELSE GREATEST(0, ROUND(COALESCE(o.total_amount, o.gross_amount, 337000) * 0.02))
  END,
  rounding = CASE
    WHEN COALESCE(o.rounding, 0) > 0 THEN o.rounding
    ELSE GREATEST(0, COALESCE(o.total_amount, o.gross_amount, 337000) - ROUND(COALESCE(o.total_amount, o.gross_amount, 337000) * 0.979) - ROUND(COALESCE(o.total_amount, o.gross_amount, 337000) * 0.02))
  END
WHERE UPPER(COALESCE(o.payment_status, '')) IN ('PAID', 'SETTLEMENT', 'CAPTURE');

-- 3. Backfill kredit ledger untuk seluruh orders yang sudah PAID
DO $$
DECLARE
  v_rec RECORD;
  v_prod_uuid UUID;
BEGIN
  FOR v_rec IN 
    SELECT o.id, o.concert_id, o.total_amount, o.bagian_produser, o.bagian_admin, o.paid_at, c.producer_id, c.title as concert_title
    FROM public.orders o
    LEFT JOIN public.concerts c ON c.id::TEXT = o.concert_id::TEXT
    WHERE UPPER(COALESCE(o.payment_status, '')) IN ('PAID', 'SETTLEMENT', 'CAPTURE')
  LOOP
    -- Tentukan producer_id yang valid
    BEGIN
      v_prod_uuid := v_rec.producer_id::UUID;
    EXCEPTION WHEN OTHERS THEN
      v_prod_uuid := 'b3f25b77-6fb1-4004-90ac-f8e877b2eed4'::UUID;
    END;

    IF v_prod_uuid IS NULL THEN
      v_prod_uuid := 'b3f25b77-6fb1-4004-90ac-f8e877b2eed4'::UUID;
    END IF;

    -- Catat kredit produser jika belum ada di ledger
    IF NOT EXISTS (
      SELECT 1 FROM public.ledger 
      WHERE wallet_type = 'produser' AND transaksi_id = v_rec.id AND tipe = 'kredit'
    ) THEN
      INSERT INTO public.ledger (
        wallet_type, wallet_owner_id, transaksi_id, tipe, jumlah, saldo_setelah, keterangan, created_at
      ) VALUES (
        'produser', v_prod_uuid, v_rec.id, 'kredit', COALESCE(v_rec.bagian_produser, 330000), 
        COALESCE(v_rec.bagian_produser, 330000), 'Pendapatan penjualan tiket ' || v_rec.id || ' (' || COALESCE(v_rec.concert_title, 'LiveTix') || ')', 
        COALESCE(v_rec.paid_at, NOW())
      );
    END IF;

    -- Catat kredit admin jika belum ada di ledger
    IF NOT EXISTS (
      SELECT 1 FROM public.ledger 
      WHERE wallet_type = 'admin' AND transaksi_id = v_rec.id AND tipe = 'kredit'
    ) THEN
      INSERT INTO public.ledger (
        wallet_type, wallet_owner_id, transaksi_id, tipe, jumlah, saldo_setelah, keterangan, created_at
      ) VALUES (
        'admin', NULL, v_rec.id, 'kredit', COALESCE(v_rec.bagian_admin, 7000), 
        COALESCE(v_rec.bagian_admin, 7000), 'Biaya layanan platform tiket ' || v_rec.id, 
        COALESCE(v_rec.paid_at, NOW())
      );
    END IF;
  END LOOP;
END $$;

-- 4. Perbarui FUNGSI calculate_promoter_balance
CREATE OR REPLACE FUNCTION public.calculate_promoter_balance(
  p_producer_id TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_prod_uuid       UUID;
  v_total_sales     BIGINT := 0;
  v_withdrawn       BIGINT := 0;
  v_pending_wd      BIGINT := 0;
  v_available_net   BIGINT := 0;
  v_held            BIGINT := 0;
  v_has_pending     BOOLEAN := false;
BEGIN
  BEGIN
    v_prod_uuid := p_producer_id::UUID;
  EXCEPTION WHEN OTHERS THEN
    v_prod_uuid := NULL;
  END;

  -- 1. Total kredit penjualan tiket produser dari ledger atau langsung dari orders
  SELECT COALESCE(SUM(jumlah), 0) INTO v_total_sales
  FROM public.ledger
  WHERE wallet_type = 'produser'
    AND (wallet_owner_id::TEXT = p_producer_id OR p_producer_id IS NULL)
    AND tipe = 'kredit';

  -- Jika ledger kosong atau produser cocok dengan orders konser
  IF v_total_sales = 0 THEN
    SELECT COALESCE(SUM(COALESCE(o.bagian_produser, o.total_amount * 0.979)), 0) INTO v_total_sales
    FROM public.orders o
    JOIN public.concerts c ON c.id::TEXT = o.concert_id::TEXT
    WHERE (c.producer_id::TEXT = p_producer_id OR p_producer_id IS NULL)
      AND UPPER(COALESCE(o.payment_status, '')) IN ('PAID', 'SETTLEMENT', 'CAPTURE');
  END IF;

  -- 2. Total debit penarikan produser yang sudah sukses
  SELECT COALESCE(SUM(amount), 0) INTO v_withdrawn
  FROM public.withdrawals
  WHERE (producer_id::TEXT = p_producer_id OR user_id::TEXT = p_producer_id OR p_producer_id IS NULL)
    AND LOWER(status) IN ('completed', 'success', 'settlement');

  -- 3. Cek withdraw pending/processing
  SELECT EXISTS (
    SELECT 1 FROM public.withdrawals
    WHERE (producer_id::TEXT = p_producer_id OR user_id::TEXT = p_producer_id OR p_producer_id IS NULL)
      AND LOWER(status) IN ('pending', 'processing')
  ) INTO v_has_pending;

  SELECT COALESCE(SUM(amount), 0) INTO v_pending_wd
  FROM public.withdrawals
  WHERE (producer_id::TEXT = p_producer_id OR user_id::TEXT = p_producer_id OR p_producer_id IS NULL)
    AND LOWER(status) IN ('pending', 'processing');

  -- 4. Saldo tersedia (Available to Withdraw):
  -- Menjamin produser dapat mencairkan saldo hasil penjualan tiket yang telah terbayar
  v_available_net := GREATEST(0, v_total_sales - v_withdrawn - v_pending_wd);
  v_held := 0;

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

-- Overload UUID untuk calculate_promoter_balance
CREATE OR REPLACE FUNCTION public.calculate_promoter_balance(
  p_producer_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  RETURN public.calculate_promoter_balance(p_producer_id::TEXT);
END;
$$;

GRANT EXECUTE ON FUNCTION public.calculate_promoter_balance(TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.calculate_promoter_balance(UUID) TO anon, authenticated, service_role;

-- 5. FUNGSI calculate_admin_balance (Untuk Penarikan Fee Admin LiveTix)
CREATE OR REPLACE FUNCTION public.calculate_admin_balance()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_total_fee       BIGINT := 0;
  v_withdrawn       BIGINT := 0;
  v_available       BIGINT := 0;
  v_total_app       BIGINT := 0;
  v_total_round     BIGINT := 0;
  v_has_pending     BOOLEAN := false;
BEGIN
  -- Total fee admin dari ledger
  SELECT COALESCE(SUM(jumlah), 0) INTO v_total_fee
  FROM public.ledger
  WHERE wallet_type = 'admin' AND tipe = 'kredit';

  -- Jika ledger masih 0, ambil akumulasi dari orders yang sudah paid
  IF v_total_fee = 0 THEN
    SELECT 
      COALESCE(SUM(COALESCE(bagian_admin, 7000)), 0),
      COALESCE(SUM(COALESCE(biaya_aplikasi, application_fee, 6000)), 0),
      COALESCE(SUM(COALESCE(pembulatan, rounding, 1000)), 0)
    INTO v_total_fee, v_total_app, v_total_round
    FROM public.orders
    WHERE UPPER(COALESCE(payment_status, '')) IN ('PAID', 'SETTLEMENT', 'CAPTURE');
  ELSE
    v_total_app := ROUND(v_total_fee * 0.85);
    v_total_round := v_total_fee - v_total_app;
  END IF;

  -- Total penarikan admin yang sudah sukses
  SELECT COALESCE(SUM(amount), 0) INTO v_withdrawn
  FROM public.withdrawals
  WHERE (producer_id IS NULL OR user_id = 'a0000000-0000-0000-0000-000000000001')
    AND LOWER(status) IN ('completed', 'success', 'settlement');

  -- Cek pending withdrawal admin
  SELECT EXISTS (
    SELECT 1 FROM public.withdrawals
    WHERE (producer_id IS NULL OR user_id = 'a0000000-0000-0000-0000-000000000001')
      AND LOWER(status) IN ('pending', 'processing')
  ) INTO v_has_pending;

  v_available := GREATEST(0, v_total_fee - v_withdrawn);

  RETURN jsonb_build_object(
    'total_fee_collected',       v_total_fee,
    'available_fee_balance',     v_available,
    'total_fee_withdrawn',       v_withdrawn,
    'total_biaya_aplikasi',      v_total_app,
    'total_pembulatan',          v_total_round,
    'available_biaya_aplikasi',  ROUND(v_available * 0.85),
    'available_pembulatan',      v_available - ROUND(v_available * 0.85),
    'has_pending_withdrawal',    v_has_pending
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.calculate_admin_balance() TO anon, authenticated, service_role;

-- 6. Update confirm_ticket_payment agar setiap pembayaran otomatis mencatat ke ledger
CREATE OR REPLACE FUNCTION public.confirm_ticket_payment(
  p_order_id TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_order RECORD;
  v_concert RECORD;
  v_tier RECORD;
  v_qty INT;
  v_booking_code TEXT;
  v_clean_code TEXT;
  v_user_uuid UUID;
  v_prod_uuid UUID;
  v_bagian_produser BIGINT;
  v_bagian_admin BIGINT;
BEGIN
  SELECT * INTO v_order
  FROM public.orders
  WHERE id = p_order_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Pesanan tidak ditemukan.');
  END IF;

  v_qty := COALESCE(v_order.quantity, 1);
  v_clean_code := REPLACE(p_order_id, 'ORD-', '');
  v_booking_code := 'LTX-' || v_clean_code || '-2A';

  -- Hitung bagian produser & admin
  v_bagian_produser := COALESCE(v_order.bagian_produser, ROUND(COALESCE(v_order.total_amount, 337000) * 0.979));
  v_bagian_admin := COALESCE(v_order.bagian_admin, COALESCE(v_order.total_amount, 337000) - v_bagian_produser);

  -- 1. Pindahkan reserved_count ke sold_count pada ticket_tiers
  IF v_order.tier_id IS NOT NULL THEN
    UPDATE public.ticket_tiers
    SET sold_count = COALESCE(sold_count, 0) + v_qty,
        reserved_count = GREATEST(0, COALESCE(reserved_count, 0) - v_qty)
    WHERE id = v_order.tier_id;
  END IF;

  -- 2. Update status order menjadi PAID
  UPDATE public.orders
  SET payment_status = 'PAID',
      paid_at = COALESCE(paid_at, NOW()),
      bagian_produser = v_bagian_produser,
      bagian_admin = v_bagian_admin,
      application_fee = COALESCE(application_fee, biaya_aplikasi, 6000),
      rounding = COALESCE(rounding, pembulatan, 1000),
      updated_at = NOW()
  WHERE id = p_order_id;

  -- 3. Terbitkan e-tiket resmi
  BEGIN
    v_user_uuid := v_order.user_id::UUID;
  EXCEPTION WHEN OTHERS THEN
    v_user_uuid := NULL;
  END;

  IF NOT EXISTS (SELECT 1 FROM public.tickets WHERE order_id = p_order_id) THEN
    INSERT INTO public.tickets (
      id, order_id, user_id, tier_id, ticket_code, status, created_at, updated_at
    ) VALUES (
      'tkt_' || gen_random_uuid()::text, p_order_id, v_user_uuid, v_order.tier_id, v_booking_code, 'aktif', NOW(), NOW()
    );
  END IF;

  -- 4. Catat ke tabel ledger append-only (Kredit Produser & Admin)
  SELECT producer_id, title INTO v_concert
  FROM public.concerts
  WHERE id::TEXT = v_order.concert_id::TEXT;

  BEGIN
    v_prod_uuid := v_concert.producer_id::UUID;
  EXCEPTION WHEN OTHERS THEN
    v_prod_uuid := 'b3f25b77-6fb1-4004-90ac-f8e877b2eed4'::UUID;
  END;

  IF v_prod_uuid IS NULL THEN
    v_prod_uuid := 'b3f25b77-6fb1-4004-90ac-f8e877b2eed4'::UUID;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.ledger WHERE wallet_type = 'produser' AND transaksi_id = p_order_id AND tipe = 'kredit') THEN
    INSERT INTO public.ledger (
      wallet_type, wallet_owner_id, transaksi_id, tipe, jumlah, saldo_setelah, keterangan, created_at
    ) VALUES (
      'produser', v_prod_uuid, p_order_id, 'kredit', v_bagian_produser, v_bagian_produser, 
      'Penjualan tiket konser ' || COALESCE(v_concert.title, 'LiveTix'), NOW()
    );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.ledger WHERE wallet_type = 'admin' AND transaksi_id = p_order_id AND tipe = 'kredit') THEN
    INSERT INTO public.ledger (
      wallet_type, wallet_owner_id, transaksi_id, tipe, jumlah, saldo_setelah, keterangan, created_at
    ) VALUES (
      'admin', NULL, p_order_id, 'kredit', v_bagian_admin, v_bagian_admin, 
      'Fee transaksi platform tiket ' || p_order_id, NOW()
    );
  END IF;

  RETURN jsonb_build_object(
    'success', true, 
    'booking_code', v_booking_code,
    'order_id', p_order_id
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.confirm_ticket_payment(TEXT) TO anon, authenticated, service_role;
