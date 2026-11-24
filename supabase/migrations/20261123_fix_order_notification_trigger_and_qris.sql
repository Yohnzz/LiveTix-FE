 -- ============================================================================
-- Migration: 20261123_fix_order_notification_trigger_and_qris.sql
-- Tujuan:
-- 1. Memperbaiki trigger `notifications_order_changes` pada tabel `orders`
--    yang menyebabkan update status 'PAID' gagal dengan error:
--    "function public.create_notification(text, text, ...) does not exist"
-- 2. Menambahkan fungsi overload `public.create_notification(p_user_id TEXT, ...)`
-- 3. Menambahkan foreign key relationship `orders.concert_id` -> `concerts.id`
-- ============================================================================

-- 1. Tambahkan fungsi overload create_notification dengan parameter TEXT untuk p_user_id
CREATE OR REPLACE FUNCTION public.create_notification(
  p_user_id TEXT,
  p_dedupe_key TEXT,
  p_title TEXT,
  p_body TEXT,
  p_type TEXT,
  p_target_type TEXT,
  p_target_id TEXT,
  p_metadata JSONB DEFAULT '{}'::jsonb
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_uuid UUID;
BEGIN
  BEGIN
    v_uuid := p_user_id::UUID;
  EXCEPTION WHEN OTHERS THEN
    v_uuid := NULL;
  END;

  IF v_uuid IS NOT NULL THEN
    RETURN public.create_notification(v_uuid, p_dedupe_key, p_title, p_body, p_type, p_target_type, p_target_id, p_metadata);
  END IF;
  RETURN NULL;
END;
$$;

-- 2. Perbaiki fungsi notify_order_changes() agar aman dari casting exception
CREATE OR REPLACE FUNCTION public.notify_order_changes()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  payment_status TEXT;
  concert_title TEXT;
  producer_id UUID;
  paid_total TEXT;
  v_user_uuid UUID;
BEGIN
  payment_status := UPPER(BTRIM(COALESCE(NEW.payment_status, '')));
  IF TG_OP = 'UPDATE' AND OLD.payment_status IS NOT DISTINCT FROM NEW.payment_status THEN
    RETURN NEW;
  END IF;

  SELECT c.title, c.producer_id
    INTO concert_title, producer_id
  FROM public.concerts c
  WHERE c.id::TEXT = NEW.concert_id::TEXT
  LIMIT 1;
  concert_title := COALESCE(NULLIF(concert_title, ''), 'Konser');
  paid_total := COALESCE(NEW.total_bayar, NEW.total_amount, 0)::TEXT;

  BEGIN
    v_user_uuid := NEW.user_id::UUID;
  EXCEPTION WHEN OTHERS THEN
    v_user_uuid := NULL;
  END;

  IF payment_status IN ('PAID', 'SETTLEMENT', 'CAPTURE') THEN
    IF v_user_uuid IS NOT NULL THEN
      BEGIN
        PERFORM public.create_notification(
          v_user_uuid,
          'order:' || NEW.id || ':paid:user',
          'Pembayaran berhasil',
          'Pembayaran tiket ' || concert_title || ' berhasil. E-tiket Anda sudah diterbitkan.',
          'ticket',
          'order',
          NEW.id,
          jsonb_build_object('concert_id', NEW.concert_id, 'order_id', NEW.id)
        );
      EXCEPTION WHEN OTHERS THEN NULL;
      END;
    END IF;

    IF producer_id IS NOT NULL THEN
      BEGIN
        PERFORM public.create_notification(
          producer_id,
          'order:' || NEW.id || ':paid:producer',
          'Tiket konser terjual',
          'Pembayaran tiket ' || concert_title || ' berhasil diterima.',
          'sales',
          'concert',
          NEW.concert_id,
          jsonb_build_object('order_id', NEW.id, 'amount', paid_total)
        );
      EXCEPTION WHEN OTHERS THEN NULL;
      END;
    END IF;

    BEGIN
      PERFORM public.create_role_notifications(
        'admin',
        'order:' || NEW.id || ':paid:admin',
        'Transaksi tiket berhasil',
        'Pembayaran tiket ' || concert_title || ' telah berhasil.',
        'sales',
        'order',
        NEW.id,
        jsonb_build_object('amount', paid_total)
      );
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
  ELSIF payment_status IN ('FAILED', 'EXPIRED', 'CANCELLED', 'CANCELED') THEN
    IF v_user_uuid IS NOT NULL THEN
      BEGIN
        PERFORM public.create_notification(
          v_user_uuid,
          'order:' || NEW.id || ':' || payment_status || ':user',
          'Pembayaran belum berhasil',
          'Pembayaran tiket ' || concert_title || ' tidak berhasil. Anda dapat mencoba memesan kembali.',
          'payment',
          'order',
          NEW.id,
          jsonb_build_object('order_id', NEW.id, 'payment_status', payment_status)
        );
      EXCEPTION WHEN OTHERS THEN NULL;
      END;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

-- 3. Foreign key relationship orders -> concerts
DO $$
BEGIN
  ALTER TABLE public.orders 
    ADD CONSTRAINT fk_orders_concerts 
    FOREIGN KEY (concert_id) 
    REFERENCES public.concerts(id) 
    ON DELETE SET NULL;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

NOTIFY pgrst, 'reload schema';
