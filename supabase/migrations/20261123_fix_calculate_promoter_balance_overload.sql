-- ==============================================================================
-- LIVE TIX: FIX OVERLOADED RPC calculate_promoter_balance (PGRST203 & 42703)
-- File: 20261123_fix_calculate_promoter_balance_overload.sql
-- ==============================================================================

-- 1. Pastikan kolom start_time ada pada tabel concerts agar tidak error 42703
ALTER TABLE public.concerts ADD COLUMN IF NOT EXISTS start_time TIMESTAMPTZ;

-- 2. Hapus kedua varian overload (UUID dan TEXT) agar tidak ada konflik PostgREST (PGRST203)
DROP FUNCTION IF EXISTS public.calculate_promoter_balance(UUID);
DROP FUNCTION IF EXISTS public.calculate_promoter_balance(TEXT);

-- 3. Buat kembali satu fungsi tunggal definitif dengan parameter TEXT
--    Parameter TEXT dapat menerima UUID string maupun text ID apa pun.
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

  -- 4. Hitung dana dari konser yang SUDAH DIMULAI / SELESAI dan TIDAK DIBATALKAN
  --    Aturan: start_time <= NOW(), atau status completed/selesai, atau tanggal sudah lewat
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
      (LOWER(COALESCE(c.status, '')) IN ('completed', 'selesai'))
      OR
      (c.date ~ '^\d{4}-\d{2}-\d{2}' AND c.date::date <= CURRENT_DATE)
      OR
      (c.id IS NULL)
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

-- 4. Berikan hak akses execute
GRANT EXECUTE ON FUNCTION public.calculate_promoter_balance(TEXT) TO authenticated, service_role, anon;

-- 5. Reload PostgREST schema cache agar overloading & column cache segera bersih
NOTIFY pgrst, 'reload schema';
