-- ==============================================================================
-- LIVE TIX: FASE 3 - PAYMENT INTEGRATION (MIDTRANS SNAP SANDBOX)
-- File: 20261117_fase3_payment_integration.sql
-- Komponen:
--   1. Kolom snap_token & snap_redirect_url di orders (kompatibilitas Snap)
--   2. Kolom concert_id (TEXT) & venue di tickets
--   3. RPC increment_tier_sold_count (dipakai midtrans-webhook fallback)
--   4. Perbaikan confirm_ticket_payment: buat ledger jika belum ada + fix chk_ticket_status
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. KOLOM SNAP DI TABEL ORDERS
-- ------------------------------------------------------------------------------
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS snap_token TEXT;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS snap_redirect_url TEXT;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS paid_at TIMESTAMPTZ;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS midtrans_transaction_id TEXT;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS customer_nik TEXT;

-- ------------------------------------------------------------------------------
-- 2. KOLOM TAMBAHAN DI TABEL TICKETS
-- ------------------------------------------------------------------------------
ALTER TABLE public.tickets ADD COLUMN IF NOT EXISTS concert_title TEXT;
ALTER TABLE public.tickets ADD COLUMN IF NOT EXISTS concert_date TEXT;
ALTER TABLE public.tickets ADD COLUMN IF NOT EXISTS concert_time TEXT;
ALTER TABLE public.tickets ADD COLUMN IF NOT EXISTS venue TEXT;
ALTER TABLE public.tickets ADD COLUMN IF NOT EXISTS secret_hmac TEXT;
ALTER TABLE public.tickets ADD COLUMN IF NOT EXISTS issued_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE public.tickets ADD COLUMN IF NOT EXISTS qr_scans_used INT DEFAULT 0;

-- Longgarkan constraint status tiket agar kompatibel antara kode baru & lama
ALTER TABLE public.tickets DROP CONSTRAINT IF EXISTS chk_ticket_status;
ALTER TABLE public.tickets ADD CONSTRAINT chk_ticket_status
  CHECK (
    LOWER(status) IN (
      'aktif', 'active',
      'dipakai', 'sudah dipakai', 'used',
      'dibatalkan', 'cancelled', 'direfund', 'refunded'
    )
  );

-- ------------------------------------------------------------------------------
-- 3. RPC increment_tier_sold_count (Webhook fallback jika confirm_ticket_payment gagal)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.increment_tier_sold_count(
  p_tier_id UUID,
  p_qty INT DEFAULT 1
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  UPDATE public.ticket_tiers
  SET
    sold_count = COALESCE(sold_count, 0) + p_qty,
    is_sold_out = (COALESCE(sold_count, 0) + p_qty >= COALESCE(total_quota, quota, 100))
  WHERE id = p_tier_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.increment_tier_sold_count(UUID, INT) TO service_role;

-- ------------------------------------------------------------------------------
-- 4. RPC calculate_promoter_balance (Dipakai Fase 5)
-- Hitung saldo produser dari ledger append-only
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.calculate_promoter_balance(
  p_producer_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_pending   BIGINT;
  v_available BIGINT;
  v_total     BIGINT;
  v_withdrawn BIGINT;
BEGIN
  -- Total kredit ledger produser (semua penjualan tiket)
  SELECT COALESCE(SUM(jumlah), 0) INTO v_total
  FROM public.ledger
  WHERE wallet_type = 'produser'
    AND wallet_owner_id = p_producer_id
    AND tipe = 'kredit';

  -- Total debit ledger produser (penarikan yang sudah diproses)
  SELECT COALESCE(SUM(jumlah), 0) INTO v_withdrawn
  FROM public.ledger
  WHERE wallet_type = 'produser'
    AND wallet_owner_id = p_producer_id
    AND tipe = 'debit';

  -- Saldo tersedia: konser sudah dimulai dan tidak dibatalkan
  SELECT COALESCE(SUM(l.jumlah), 0) INTO v_available
  FROM public.ledger l
  JOIN public.transactions t ON t.id = l.transaksi_id
  JOIN public.concerts c ON c.id::TEXT = t.concert_id
  WHERE l.wallet_type = 'produser'
    AND l.wallet_owner_id = p_producer_id
    AND l.tipe = 'kredit'
    AND c.start_time <= NOW()
    AND LOWER(COALESCE(c.status, '')) NOT IN ('cancelled', 'dibatalkan');

  -- Saldo tertahan = total - tersedia
  v_pending := GREATEST(0, v_total - v_available - v_withdrawn);
  v_available := GREATEST(0, v_available - v_withdrawn);

  RETURN jsonb_build_object(
    'pending_balance',    v_pending,
    'available_balance',  v_available,
    'total_sales',        v_total,
    'total_withdrawn',    v_withdrawn
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.calculate_promoter_balance(UUID) TO authenticated, service_role;

-- ------------------------------------------------------------------------------
-- 5. RPC calculate_admin_balance (Dipakai Fase 6)
-- Hitung saldo admin dari ledger
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.calculate_admin_balance()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_total     BIGINT;
  v_withdrawn BIGINT;
  v_available BIGINT;
BEGIN
  SELECT COALESCE(SUM(jumlah), 0) INTO v_total
  FROM public.ledger
  WHERE wallet_type = 'admin' AND tipe = 'kredit';

  SELECT COALESCE(SUM(jumlah), 0) INTO v_withdrawn
  FROM public.ledger
  WHERE wallet_type = 'admin' AND tipe = 'debit';

  v_available := GREATEST(0, v_total - v_withdrawn);

  RETURN jsonb_build_object(
    'total_fee_collected',   v_total,
    'available_fee_balance', v_available,
    'total_fee_withdrawn',   v_withdrawn
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.calculate_admin_balance() TO authenticated, service_role;

-- ------------------------------------------------------------------------------
-- 6. INDEX TAMBAHAN UNTUK PERFORMA QUERY LEDGER
-- ------------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_ledger_wallet_kredit
  ON public.ledger(wallet_type, wallet_owner_id, tipe, created_at);

CREATE INDEX IF NOT EXISTS idx_tickets_order ON public.tickets(order_id);
CREATE INDEX IF NOT EXISTS idx_tickets_user  ON public.tickets(user_id);
CREATE INDEX IF NOT EXISTS idx_orders_snap   ON public.orders(snap_token);

-- ------------------------------------------------------------------------------
-- 7. GRANT ke service_role untuk Edge Functions
-- ------------------------------------------------------------------------------
GRANT INSERT ON public.ledger TO service_role;
GRANT SELECT, UPDATE ON public.orders TO service_role;
GRANT SELECT, UPDATE ON public.transactions TO service_role;
GRANT INSERT ON public.tickets TO service_role;
GRANT SELECT, UPDATE ON public.ticket_tiers TO service_role;

-- Pastikan sequence / gen_random_uuid bisa dipakai
GRANT USAGE ON SCHEMA public TO service_role;
