-- 1. Sync tickets_sold & gross_revenue on concerts from actual PAID orders
UPDATE public.concerts c
SET 
  tickets_sold = COALESCE(sub.total_qty, 0),
  gross_revenue = COALESCE(sub.total_gross, 0),
  updated_at = NOW()
FROM (
  SELECT 
    concert_id,
    COUNT(id) AS total_qty,
    SUM(gross_amount) AS total_gross
  FROM public.orders
  WHERE payment_status = 'PAID'
  GROUP BY concert_id
) sub
WHERE c.id::TEXT = sub.concert_id::TEXT;

-- 2. Update confirm_ticket_payment so future orders automatically increment concerts
CREATE OR REPLACE FUNCTION public.confirm_ticket_payment(p_order_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
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

  -- 3. Update agregasi penjualan pada tabel concerts
  UPDATE public.concerts
  SET tickets_sold = COALESCE(tickets_sold, 0) + v_qty,
      gross_revenue = COALESCE(gross_revenue, 0) + COALESCE(v_order.gross_amount, v_order.total_amount, 0),
      updated_at = NOW()
  WHERE id::TEXT = v_order.concert_id::TEXT;

  -- 4. Terbitkan e-tiket resmi
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

  -- 5. Catat ke tabel ledger append-only (Kredit Produser & Admin)
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
$function$;

-- 3. Update calculate_promoter_balance agar mengunci saldo konser yang dibatalkan / pending batal
CREATE OR REPLACE FUNCTION public.calculate_promoter_balance(p_producer_id TEXT)
RETURNS TABLE (
    total_sales_gross BIGINT,
    total_sales BIGINT,
    total_producer_portion BIGINT,
    total_withdrawn BIGINT,
    available_balance BIGINT,
    held_balance BIGINT,
    pending_balance BIGINT,
    has_pending_withdrawal BOOLEAN
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_available_gross BIGINT := 0;
    v_held_gross BIGINT := 0;
    v_total_sales BIGINT := 0;
    v_total_withdrawn BIGINT := 0;
    v_has_pending BOOLEAN := FALSE;
    v_available_balance BIGINT := 0;
BEGIN
    -- 1. Hitung saldo tersedia (Gross dari konser yang SUDAH DIMULAI / SELESAI dan TIDAK DIBATALKAN)
    SELECT COALESCE(SUM(COALESCE(o.bagian_produser, o.gross_amount)), 0)
    INTO v_available_gross
    FROM public.orders o
    JOIN public.concerts c ON c.id = o.concert_id
    WHERE (c.producer_id::TEXT = p_producer_id)
      AND o.payment_status = 'PAID'
      AND (COALESCE(c.starts_at, c.start_time) <= NOW() OR COALESCE(c.is_completed, false) = true)
      AND LOWER(COALESCE(c.status, '')) NOT IN ('cancelled', 'cancellation_pending')
      AND LOWER(COALESCE(c.cancellation_status, 'none')) NOT IN ('pending', 'approved', 'menungguadmin');

    -- 2. Hitung saldo tertahan (Konser belum dimulai ATAU konser yang sedang dalam proses pembatalan/dibatalkan untuk refund)
    SELECT COALESCE(SUM(COALESCE(o.bagian_produser, o.gross_amount)), 0)
    INTO v_held_gross
    FROM public.orders o
    JOIN public.concerts c ON c.id = o.concert_id
    WHERE (c.producer_id::TEXT = p_producer_id)
      AND o.payment_status = 'PAID'
      AND (
        (COALESCE(c.starts_at, c.start_time) > NOW() AND COALESCE(c.is_completed, false) = false)
        OR LOWER(COALESCE(c.status, '')) IN ('cancelled', 'cancellation_pending')
        OR LOWER(COALESCE(c.cancellation_status, 'none')) IN ('pending', 'approved', 'menungguadmin')
      );

    -- 3. Hitung total yang sudah ditarik oleh produser (status 'completed' atau 'SUCCESS')
    SELECT COALESCE(SUM(amount), 0)
    INTO v_total_withdrawn
    FROM public.withdrawals
    WHERE (producer_id::TEXT = p_producer_id)
      AND status IN ('completed', 'SUCCESS');

    -- 4. Cek apakah ada penarikan yang sedang pending / processing
    SELECT EXISTS (
        SELECT 1 
        FROM public.withdrawals 
        WHERE (producer_id::TEXT = p_producer_id)
          AND status IN ('pending', 'processing')
    ) INTO v_has_pending;

    -- 5. Hitung total sales dan net available balance
    v_total_sales := v_available_gross + v_held_gross;
    v_available_balance := v_available_gross - v_total_withdrawn;
    IF v_available_balance < 0 THEN
        v_available_balance := 0;
    END IF;

    RETURN QUERY SELECT 
        v_total_sales,
        v_total_sales,
        v_total_sales,
        v_total_withdrawn,
        v_available_balance,
        v_held_gross,
        v_held_gross,
        v_has_pending;
END;
$$;

GRANT EXECUTE ON FUNCTION public.calculate_promoter_balance(TEXT) TO anon, authenticated, service_role;

-- 4. Update request_producer_withdrawal agar mengunci saldo konser yang dibatalkan / pending batal
CREATE OR REPLACE FUNCTION public.request_producer_withdrawal(
  p_producer_id   TEXT,
  p_amount        BIGINT,
  p_bank_name     TEXT,
  p_account_number TEXT,
  p_account_name  TEXT,
  p_concert_id    TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_available      BIGINT;
  v_held_balance   BIGINT;
  v_has_pending    BOOLEAN;
  v_ref_no         TEXT;
  v_withdrawal_id  TEXT;
  v_saldo_sebelum  BIGINT;
  v_saldo_setelah  BIGINT;
  v_prod_uuid      UUID;
BEGIN
  IF p_amount < 50000 THEN
    RETURN jsonb_build_object(
      'success', false,
      'code', 'MINIMUM_AMOUNT',
      'message', 'Nominal penarikan minimum adalah Rp 50.000'
    );
  END IF;

  -- Anti withdraw pending ganda
  SELECT EXISTS (
    SELECT 1 FROM public.withdrawals
    WHERE (producer_id::TEXT = p_producer_id OR user_id::TEXT = p_producer_id)
      AND LOWER(status) IN ('pending', 'processing')
  ) INTO v_has_pending;

  IF v_has_pending THEN
    RETURN jsonb_build_object(
      'success', false,
      'code', 'PENDING_WITHDRAWAL_EXISTS',
      'message', 'Masih ada penarikan dana yang sedang diproses. Mohon tunggu hingga selesai.'
    );
  END IF;

  -- Saldo tersedia HANYA dari konser yang aktif, sudah dimulai, dan TIDAK dibatalkan/pending cancel
  SELECT COALESCE(SUM(COALESCE(o.bagian_produser, o.gross_amount)), 0)
  INTO v_available
  FROM public.orders o
  JOIN public.concerts c ON c.id = o.concert_id
  WHERE c.producer_id::TEXT = p_producer_id
    AND o.payment_status = 'PAID'
    AND (COALESCE(c.starts_at, c.start_time) <= NOW() OR COALESCE(c.is_completed, false) = true)
    AND LOWER(COALESCE(c.status, '')) NOT IN ('cancelled', 'cancellation_pending')
    AND LOWER(COALESCE(c.cancellation_status, 'none')) NOT IN ('pending', 'approved', 'menungguadmin');

  DECLARE
    v_already_withdrawn BIGINT := 0;
  BEGIN
    SELECT COALESCE(SUM(amount), 0)
    INTO v_already_withdrawn
    FROM public.withdrawals
    WHERE producer_id::TEXT = p_producer_id
      AND status IN ('completed', 'SUCCESS');
    v_available := v_available - v_already_withdrawn;
    IF v_available < 0 THEN v_available := 0; END IF;
  END;

  SELECT COALESCE(SUM(COALESCE(o.bagian_produser, o.gross_amount)), 0)
  INTO v_held_balance
  FROM public.orders o
  JOIN public.concerts c ON c.id = o.concert_id
  WHERE c.producer_id::TEXT = p_producer_id
    AND o.payment_status = 'PAID'
    AND (
      (COALESCE(c.starts_at, c.start_time) > NOW() AND COALESCE(c.is_completed, false) = false)
      OR LOWER(COALESCE(c.status, '')) IN ('cancelled', 'cancellation_pending')
      OR LOWER(COALESCE(c.cancellation_status, 'none')) IN ('pending', 'approved', 'menungguadmin')
    );

  IF p_amount > v_available THEN
    RETURN jsonb_build_object(
      'success', false,
      'code', 'INSUFFICIENT_AVAILABLE_BALANCE',
      'message', 'Saldo tersedia tidak mencukupi (Tersedia: Rp ' || v_available || '). Saldo konser yang belum dimulai atau sedang dibatalkan dikunci untuk perlindungan refund penonton.',
      'available_balance', v_available,
      'pending_balance', v_held_balance
    );
  END IF;

  BEGIN
    v_prod_uuid := p_producer_id::UUID;
  EXCEPTION WHEN OTHERS THEN
    v_prod_uuid := NULL;
  END;

  SELECT COALESCE(
    (SELECT saldo_setelah FROM public.ledger
     WHERE wallet_type = 'produser'
       AND wallet_owner_id = v_prod_uuid
     ORDER BY created_at DESC LIMIT 1),
    v_available
  ) INTO v_saldo_sebelum;

  IF v_saldo_sebelum < p_amount THEN
    v_saldo_sebelum := v_available;
  END IF;

  v_saldo_setelah := v_saldo_sebelum - p_amount;
  v_ref_no := 'WD-PRD-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || UPPER(SUBSTRING(md5(random()::TEXT || NOW()::TEXT), 1, 8));
  v_withdrawal_id := 'wd_' || LOWER(REPLACE(md5(random()::TEXT || clock_timestamp()::TEXT), '-', ''));

  -- Status langsung 'completed'
  INSERT INTO public.withdrawals (
    id, reference_no, user_id, producer_id, role, concert_id,
    amount, bank_name, account_number, account_name, status, created_at, completed_at
  ) VALUES (
    v_withdrawal_id, v_ref_no, v_prod_uuid, v_prod_uuid, 'produser', p_concert_id,
    p_amount, p_bank_name, p_account_number, p_account_name, 'completed', NOW(), NOW()
  );

  IF v_prod_uuid IS NOT NULL THEN
    INSERT INTO public.ledger (
      wallet_type, wallet_owner_id, transaksi_id, tipe, jumlah,
      saldo_setelah, keterangan, created_at
    ) VALUES (
      'produser', v_prod_uuid, v_ref_no, 'debit', p_amount,
      v_saldo_setelah, 'Penarikan dana produser: ' || v_ref_no || ' ke ' || p_bank_name || ' ' || p_account_number, NOW()
    );
  END IF;

  RETURN jsonb_build_object(
    'success',       true,
    'withdrawal_id', v_withdrawal_id,
    'reference_no',  v_ref_no,
    'amount',        p_amount,
    'saldo_setelah', v_saldo_setelah,
    'message',       'Penarikan dana Rp ' || p_amount || ' berhasil dan akan segera ditransfer ke rekening ' || p_bank_name || ' ' || p_account_number || '.'
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.request_producer_withdrawal(TEXT, BIGINT, TEXT, TEXT, TEXT, TEXT) TO anon, authenticated, service_role;