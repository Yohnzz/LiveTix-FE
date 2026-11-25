-- ==============================================================================
-- LIVE TIX: FIX PAYMENT EXPIRY - PAKSA 15 MENIT
-- File: 20261125_fix_payment_expiry_to_15_minutes.sql
--
-- Masalah:
--   Versi lama reserve_ticket_stock di 20261111_livetix_core_realtime_and_features.sql
--   menggunakan INTERVAL '1 hour'. Meski sudah di-override oleh fase9, ada kemungkinan
--   order lama yang sudah PENDING mempunyai expires_at = created_at + 1 jam.
--   Selain itu, beberapa order baru mungkin masih mewarisi logika 1 jam jika RPC
--   dipanggil sebelum migrasi fase9 diterapkan.
--
-- Fix:
--   1. Perbaiki semua order PENDING yang expires_at > created_at + 16 menit
--      (toleransi 1 menit dari 15 menit batas normal) → ubah ke created_at + 15 menit
--   2. Pastikan fungsi reserve_ticket_stock terbaru konsisten memakai 15 menit
--   3. Tambahkan kolom payment_started_at agar frontend bisa tracking realtime
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. PERBAIKI ORDER PENDING YANG MASIH PUNYA expires_at LEBIH DARI 16 MENIT
--    dari created_at (artinya masih memakai interval lama 1 jam)
-- ------------------------------------------------------------------------------
UPDATE public.orders
SET
  expires_at = created_at + INTERVAL '15 minutes',
  updated_at = NOW()
WHERE
  payment_status = 'PENDING'
  AND is_stock_reserved = TRUE
  AND expires_at IS NOT NULL
  -- Hanya perbaiki yang intervalnya lebih dari 16 menit (batas normalnya 15 menit)
  AND (expires_at - created_at) > INTERVAL '16 minutes'
  -- Jangan sentuh yang sudah expired
  AND expires_at > NOW();

-- ------------------------------------------------------------------------------
-- 2. TAMBAHKAN KOLOM payment_started_at JIKA BELUM ADA
--    Kolom ini memungkinkan frontend menghitung progress timer dengan tepat
-- ------------------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'orders'
      AND column_name = 'payment_started_at'
  ) THEN
    ALTER TABLE public.orders
      ADD COLUMN payment_started_at TIMESTAMPTZ DEFAULT NULL;

    -- Isi dari created_at untuk order yang sudah ada
    UPDATE public.orders
    SET payment_started_at = created_at
    WHERE payment_started_at IS NULL;

    RAISE NOTICE 'Kolom payment_started_at berhasil ditambahkan ke tabel orders';
  ELSE
    RAISE NOTICE 'Kolom payment_started_at sudah ada, dilewati';
  END IF;
END;
$$;

-- ------------------------------------------------------------------------------
-- 3. OVERRIDE FUNGSI reserve_ticket_stock - PAKSA 15 MENIT, TULIS payment_started_at
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
  v_started_at TIMESTAMPTZ;
  -- Hardcoded 15 menit sebagai single source of truth
  v_expiry_menit INT := 15;
BEGIN
  IF p_quantity IS NULL OR p_quantity <= 0 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Jumlah tiket tidak valid.'
    );
  END IF;

  -- Batas waktu dari app_config jika ada (dengan validasi)
  SELECT CASE WHEN value ~ '^[0-9]+$' THEN LEAST(value::INT, 60) END
    INTO v_expiry_menit
  FROM public.app_config
  WHERE key = 'payment_expiry_menit';

  -- Default 15 menit jika config tidak ada atau tidak valid
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
    -- Order sudah direservasi, kembalikan expires_at yang ada
    -- TAPI: pastikan expires_at tidak lebih dari 15 menit dari sekarang jika order baru dibuat
    -- Jika interval yang tersimpan > 16 menit, perbaiki sekarang juga
    IF v_order.expires_at IS NOT NULL AND (v_order.expires_at - COALESCE(v_order.created_at, NOW())) > INTERVAL '16 minutes' THEN
      UPDATE public.orders
      SET expires_at = COALESCE(v_order.created_at, NOW()) + make_interval(mins => v_expiry_menit),
          payment_started_at = COALESCE(v_order.payment_started_at, v_order.created_at, NOW()),
          updated_at = NOW()
      WHERE id = p_order_id;

      RETURN jsonb_build_object(
        'success', true,
        'already_reserved', true,
        'reserved_quantity', v_order.quantity,
        'expires_at', COALESCE(v_order.created_at, NOW()) + make_interval(mins => v_expiry_menit),
        'payment_started_at', COALESCE(v_order.payment_started_at, v_order.created_at, NOW())
      );
    END IF;

    RETURN jsonb_build_object(
      'success', true,
      'already_reserved', true,
      'reserved_quantity', v_order.quantity,
      'expires_at', COALESCE(
        v_order.expires_at,
        NOW() + make_interval(mins => v_expiry_menit)
      ),
      'payment_started_at', COALESCE(v_order.payment_started_at, v_order.created_at, NOW())
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

  -- Waktu mulai pembayaran = sekarang
  v_started_at := NOW();
  -- expires_at = sekarang + 15 menit (dari config)
  -- Jika order sudah punya expires_at yang masuk akal (<= 16 menit), pakai itu
  v_expires_at := CASE
    WHEN v_order.expires_at IS NOT NULL
         AND (v_order.expires_at - COALESCE(v_order.created_at, NOW())) <= INTERVAL '16 minutes'
         AND v_order.expires_at > NOW()
    THEN v_order.expires_at
    ELSE NOW() + make_interval(mins => v_expiry_menit)
  END;

  -- 4. Update pesanan dengan status PENDING, flag reservasi, dan batas waktu 15 menit
  UPDATE public.orders
  SET payment_status = 'PENDING',
      is_stock_reserved = TRUE,
      expires_at = v_expires_at,
      payment_started_at = v_started_at,
      updated_at = NOW()
  WHERE id = p_order_id;

  RETURN jsonb_build_object(
    'success', true,
    'reserved_quantity', p_quantity,
    'remaining_stock', GREATEST(0, v_available - p_quantity),
    'expires_at', v_expires_at,
    'payment_started_at', v_started_at
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.reserve_ticket_stock(TEXT, INT, TEXT, UUID)
  TO anon, authenticated, service_role;

-- ------------------------------------------------------------------------------
-- 4. VERIFIKASI
-- ------------------------------------------------------------------------------
DO $$
DECLARE
  v_pending_1hr INT;
  v_menit INT;
BEGIN
  -- Cek apakah masih ada order PENDING dengan interval > 16 menit
  SELECT COUNT(*) INTO v_pending_1hr
  FROM public.orders
  WHERE payment_status = 'PENDING'
    AND expires_at IS NOT NULL
    AND (expires_at - created_at) > INTERVAL '16 minutes'
    AND expires_at > NOW();

  IF v_pending_1hr > 0 THEN
    RAISE WARNING 'Masih ada % order PENDING dengan expires_at > 16 menit dari created_at', v_pending_1hr;
  ELSE
    RAISE NOTICE 'Semua order PENDING sudah menggunakan batas waktu <= 15 menit';
  END IF;

  -- Verifikasi konfigurasi
  SELECT value::INT INTO v_menit
  FROM public.app_config
  WHERE key = 'payment_expiry_menit';

  RAISE NOTICE 'Fix payment expiry selesai: batas waktu % menit', COALESCE(v_menit, 15);
END;
$$;
