-- ==============================================================================
-- LIVE TIX: FASE 9 - BATAS WAKTU PEMBAYARAN 15 MENIT
-- File: 20261118_fase9_payment_expiry_15_minutes.sql
-- Komponen:
-- 1. Konfigurasi `payment_expiry_menit` di app_config (default 15 menit)
-- 2. reserve_ticket_stock: fallback `expires_at` memakai konfigurasi tersebut
--    (sebelumnya hardcoded INTERVAL '1 hour')
--
-- Catatan:
-- `expires_at` yang dikirim client / Edge Function `create-payment` tetap
-- menjadi nilai utama. Blok ini hanya jaring pengaman bila order belum
-- memiliki expires_at, supaya tidak pernah kembali ke 1 jam.
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. KONFIGURASI BATAS WAKTU PEMBAYARAN
-- ------------------------------------------------------------------------------
INSERT INTO public.app_config (key, value, description)
VALUES ('payment_expiry_menit', '15', 'Batas waktu pembayaran tiket dalam menit (default 15)')
ON CONFLICT (key) DO UPDATE SET
  value = EXCLUDED.value,
  description = EXCLUDED.description,
  updated_at = NOW();

-- ------------------------------------------------------------------------------
-- 2. RESERVASI STOK TIKET (PENDING PAYMENT 15 MENIT)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.reserve_ticket_stock(
  p_tier_id TEXT,
  p_quantity INT,
  p_order_id TEXT,
  p_user_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_tier RECORD;
  v_order RECORD;
  v_total_quota INT;
  v_sold INT;
  v_reserved INT;
  v_available INT;
  v_expires_at TIMESTAMPTZ;
  v_expiry_menit INT;
BEGIN
  IF p_quantity IS NULL OR p_quantity <= 0 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Jumlah tiket tidak valid.'
    );
  END IF;

  -- Batas waktu pembayaran: ambil dari app_config, default 15 menit.
  -- Nilai non-numerik diabaikan agar fungsi tidak pernah gagal karena config.
  SELECT CASE WHEN value ~ '^[0-9]+$' THEN value::INT END
    INTO v_expiry_menit
  FROM public.app_config
  WHERE key = 'payment_expiry_menit';

  IF v_expiry_menit IS NULL OR v_expiry_menit <= 0 THEN
    v_expiry_menit := 15;
  END IF;

  -- 0. Kunci order terlebih dahulu untuk menjamin idempotensi
  SELECT * INTO v_order
  FROM public.orders
  WHERE id = p_order_id
  FOR UPDATE;

  IF FOUND AND UPPER(COALESCE(v_order.payment_status, '')) = 'PENDING'
     AND COALESCE(v_order.is_stock_reserved, FALSE) = TRUE THEN
    RETURN jsonb_build_object(
      'success', true,
      'already_reserved', true,
      'reserved_quantity', v_order.quantity,
      'expires_at', COALESCE(
        v_order.expires_at,
        NOW() + make_interval(mins => v_expiry_menit)
      )
    );
  END IF;

  -- 1. Kunci baris tier untuk mencegah race condition (Concurrency Lock)
  SELECT * INTO v_tier
  FROM public.ticket_tiers
  WHERE id::text = p_tier_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Kategori tiket tidak ditemukan.'
    );
  END IF;

  v_total_quota := COALESCE(v_tier.total_quota, v_tier.quota, 0);
  v_sold := COALESCE(v_tier.sold_count, 0);
  v_reserved := COALESCE(v_tier.reserved_count, 0);
  v_available := v_total_quota - (v_sold + v_reserved);

  -- 2. Validasi stok tersedia terhadap jumlah yang diminta
  IF v_available < p_quantity THEN
    RETURN jsonb_build_object(
      'success', false,
      'available_stock', GREATEST(0, v_available),
      'error', format('Maaf, tiket yang tersedia saat ini hanya tersisa %s tiket. Silakan kurangi jumlah pembelian.', GREATEST(0, v_available))
    );
  END IF;

  -- 3. Tambahkan ke reserved_count pada ticket_tiers
  UPDATE public.ticket_tiers
  SET reserved_count = v_reserved + p_quantity,
      is_sold_out = (v_sold + v_reserved + p_quantity >= v_total_quota)
  WHERE id = v_tier.id;

  v_expires_at := COALESCE(
    v_order.expires_at,
    NOW() + make_interval(mins => v_expiry_menit)
  );

  -- 4. Update pesanan dengan status PENDING, flag reservasi, dan batas waktu
  UPDATE public.orders
  SET payment_status = 'PENDING',
      is_stock_reserved = TRUE,
      expires_at = v_expires_at,
      updated_at = NOW()
  WHERE id = p_order_id;

  RETURN jsonb_build_object(
    'success', true,
    'reserved_quantity', p_quantity,
    'remaining_stock', GREATEST(0, v_available - p_quantity),
    'expires_at', v_expires_at
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.reserve_ticket_stock(TEXT, INT, TEXT, UUID)
  TO anon, authenticated, service_role;

-- ------------------------------------------------------------------------------
-- 3. VERIFIKASI
-- ------------------------------------------------------------------------------
DO $$
DECLARE
  v_menit INT;
  v_def TEXT;
BEGIN
  SELECT value::INT INTO v_menit
  FROM public.app_config
  WHERE key = 'payment_expiry_menit';

  IF v_menit IS NULL OR v_menit <> 15 THEN
    RAISE EXCEPTION 'Konfigurasi payment_expiry_menit harus 15, ditemukan: %', v_menit;
  END IF;

  v_def := pg_get_functiondef('public.reserve_ticket_stock(TEXT,INT,TEXT,UUID)'::regprocedure);
  IF position('make_interval' IN v_def) = 0 THEN
    RAISE EXCEPTION 'reserve_ticket_stock belum memakai batas waktu dari app_config';
  END IF;

  RAISE NOTICE 'Fase 9 OK: batas waktu pembayaran % menit', v_menit;
END;
$$;
