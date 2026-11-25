-- ============================================================================
-- Migration: 20261125_remove_producer_ticket_sold_notification.sql
-- Tujuan:
-- Menghapus pengiriman notifikasi 'Tiket konser terjual' / pembayaran berhasil
-- ke akun produser agar tidak membanjiri daftar notifikasi produser.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.notify_order_changes()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  payment_status TEXT;
  concert_title TEXT;
  paid_total TEXT;
  v_user_uuid UUID;
BEGIN
  payment_status := UPPER(BTRIM(COALESCE(NEW.payment_status, '')));
  IF TG_OP = 'UPDATE' AND OLD.payment_status IS NOT DISTINCT FROM NEW.payment_status THEN
    RETURN NEW;
  END IF;

  SELECT c.title
    INTO concert_title
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

    -- Notifikasi ke Producer sengaja ditiadakan sesuai instruksi:
    -- "notifikasi pembayaran berhasil diterima di produser itu gak perlu, nanti pasti memenuhi notifikasi jadi di hapus untuk notif itu"

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

-- Hapus notifikasi lama dari database jika ada yang sudah tersimpan untuk produser
DELETE FROM public.notifications
WHERE dedupe_key LIKE 'order:%:paid:producer'
   OR (title ILIKE '%tiket%terjual%' AND type = 'sales');
