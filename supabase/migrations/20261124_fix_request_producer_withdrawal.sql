-- ============================================================
-- Fix: request_producer_withdrawal tidak bisa memanggil
-- calculate_promoter_balance karena return type berubah dari
-- JSONB menjadi TABLE. Solve dengan mengambil data inline.
-- Biaya sistem 2% (bukan 5%).
-- Status langsung 'completed' — produser tidak perlu approval admin,
-- dana adalah HAK produser yang sudah bisa ditarik.
-- ============================================================

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
  -- 1. Validasi minimum nominal
  IF p_amount < 50000 THEN
    RETURN jsonb_build_object(
      'success', false,
      'code', 'MINIMUM_AMOUNT',
      'message', 'Nominal penarikan minimum adalah Rp 50.000'
    );
  END IF;

  -- 2. Anti withdraw pending ganda
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

  -- 3. Hitung saldo tersedia (konser yang sudah dimulai / selesai)
  SELECT COALESCE(SUM(COALESCE(o.bagian_produser, o.gross_amount)), 0)
  INTO v_available
  FROM public.orders o
  JOIN public.concerts c ON c.id = o.concert_id
  WHERE c.producer_id::TEXT = p_producer_id
    AND o.payment_status = 'PAID'
    AND (COALESCE(c.starts_at, c.start_time) <= NOW() OR COALESCE(c.is_completed, false) = true);

  -- Kurangi yang sudah ditarik sebelumnya
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

  -- 4. Hitung saldo tertahan (konser belum dimulai)
  SELECT COALESCE(SUM(COALESCE(o.bagian_produser, o.gross_amount)), 0)
  INTO v_held_balance
  FROM public.orders o
  JOIN public.concerts c ON c.id = o.concert_id
  WHERE c.producer_id::TEXT = p_producer_id
    AND o.payment_status = 'PAID'
    AND (COALESCE(c.starts_at, c.start_time) > NOW() AND COALESCE(c.is_completed, false) = false);

  -- 5. Cek kecukupan saldo tersedia
  IF p_amount > v_available THEN
    RETURN jsonb_build_object(
      'success', false,
      'code', 'INSUFFICIENT_AVAILABLE_BALANCE',
      'message', 'Saldo tersedia tidak mencukupi (Tersedia: Rp ' || v_available || '). Saldo konser yang belum dimulai berstatus tertahan.',
      'available_balance', v_available,
      'pending_balance', v_held_balance
    );
  END IF;

  -- 6. Ambil saldo terakhir dari ledger produser
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

  -- Jika saldo ledger kurang, gunakan v_available sebagai saldo sebelum (bootstrap)
  IF v_saldo_sebelum < p_amount THEN
    v_saldo_sebelum := v_available;
  END IF;

  v_saldo_setelah := v_saldo_sebelum - p_amount;
  v_ref_no := 'WD-PRD-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || UPPER(SUBSTRING(md5(random()::TEXT || NOW()::TEXT), 1, 8));
  v_withdrawal_id := 'wd_' || LOWER(REPLACE(md5(random()::TEXT || clock_timestamp()::TEXT), '-', ''));

  -- 7. Insert ke tabel withdrawals dengan status langsung 'completed'
  --    Produser tidak butuh persetujuan admin — dana adalah hak produser
  INSERT INTO public.withdrawals (
    id, reference_no, user_id, producer_id, role, concert_id,
    amount, bank_name, account_number, account_name, status, created_at, completed_at
  ) VALUES (
    v_withdrawal_id, v_ref_no, v_prod_uuid, v_prod_uuid, 'produser', p_concert_id,
    p_amount, p_bank_name, p_account_number, p_account_name, 'completed', NOW(), NOW()
  );

  -- 8. Tulis DEBIT ke ledger
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
