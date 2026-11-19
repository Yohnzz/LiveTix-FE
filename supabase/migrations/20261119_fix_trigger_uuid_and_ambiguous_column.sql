-- ==============================================================================
-- FIX TRIGGER FUNCTIONS: UUID TYPE CASTING & AMBIGUOUS CONCERT_TITLE
-- ==============================================================================

BEGIN;

-- 1. Perbaiki notify_promoter_status_changes
-- Masalah sebelumnya: COALESCE(NEW.user_id, '') gagal karena user_id bertipe UUID,
-- sehingga Postgres memunculkan error 42804 (uuid vs text) dan 22P02 (invalid input syntax for type uuid: "")
CREATE OR REPLACE FUNCTION public.notify_promoter_status_changes()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  recipient_id UUID;
  new_status TEXT;
  old_status TEXT;
  producer_name TEXT;
BEGIN
  recipient_id := COALESCE(NEW.user_id, NEW.id);
  new_status := LOWER(BTRIM(COALESCE(NEW.approval_status, '')));
  old_status := CASE WHEN TG_OP = 'UPDATE'
    THEN LOWER(BTRIM(COALESCE(OLD.approval_status, '')))
    ELSE ''
  END;
  producer_name := COALESCE(NULLIF(NEW.company_name, ''), 'Produser');

  IF TG_OP = 'INSERT' AND new_status IN ('pending', 'unverified') THEN
    PERFORM public.create_role_notifications(
      'admin',
      'producer-application:' || NEW.id::TEXT,
      'Pengajuan produser baru',
      producer_name || ' mengajukan verifikasi akun produser.',
      'approval',
      'producer',
      NEW.id::TEXT
    );
  END IF;

  IF new_status IN ('approved', 'rejected', 'nonaktif')
     AND old_status IS DISTINCT FROM new_status THEN
    PERFORM public.create_notification(
      recipient_id,
      'producer-status:' || NEW.id::TEXT || ':' || new_status || ':' ||
        COALESCE(NEW.updated_at::TEXT, NOW()::TEXT),
      CASE new_status
        WHEN 'approved' THEN 'Akun produser disetujui'
        WHEN 'rejected' THEN 'Pengajuan produser ditolak'
        ELSE 'Akun produser dinonaktifkan'
      END,
      CASE new_status
        WHEN 'approved' THEN 'Akun produser Anda telah disetujui.'
        WHEN 'rejected' THEN COALESCE(NULLIF(NEW.rejection_reason, ''), 'Silakan periksa kembali data pengajuan Anda.')
        ELSE COALESCE(NULLIF(NEW.deactivation_reason, ''), 'Silakan hubungi Admin untuk informasi lebih lanjut.')
      END,
      'approval',
      'producer',
      NEW.id::TEXT
    );
  END IF;

  RETURN NEW;
END;
$$;

-- 2. Perbaiki notify_concert_changes
-- Masalah sebelumnya: variabel concert_title bentrok dengan kolom/query (ambiguous 42702)
CREATE OR REPLACE FUNCTION public.notify_concert_changes()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  new_status TEXT;
  old_status TEXT;
  request_status TEXT;
  old_request_status TEXT;
  old_publication_status TEXT;
  event_key TEXT;
  v_concert_title TEXT;
BEGIN
  new_status := LOWER(BTRIM(COALESCE(NEW.approval_status, NEW.status, '')));
  old_status := CASE WHEN TG_OP = 'UPDATE'
    THEN LOWER(BTRIM(COALESCE(OLD.approval_status, OLD.status, '')))
    ELSE ''
  END;
  old_publication_status := CASE WHEN TG_OP = 'UPDATE'
    THEN LOWER(BTRIM(COALESCE(OLD.status, '')))
    ELSE ''
  END;
  request_status := LOWER(BTRIM(COALESCE(NEW.cancellation_status, '')));
  old_request_status := CASE WHEN TG_OP = 'UPDATE'
    THEN LOWER(BTRIM(COALESCE(OLD.cancellation_status, '')))
    ELSE ''
  END;
  v_concert_title := COALESCE(NULLIF(NEW.title, ''), 'Konser');
  event_key := 'concert:' || NEW.id::TEXT;

  IF TG_OP = 'INSERT' AND new_status IN ('pending', 'pending_create') THEN
    PERFORM public.create_role_notifications(
      'admin',
      event_key || ':submitted',
      'Pengajuan konser baru',
      v_concert_title || ' menunggu persetujuan Admin.',
      'approval',
      'concert',
      NEW.id::TEXT
    );
  END IF;

  IF (TG_OP = 'INSERT' AND
      (new_status IN ('approved', 'published') OR LOWER(COALESCE(NEW.status, '')) = 'published'))
     OR (TG_OP = 'UPDATE' AND
      ((old_status NOT IN ('approved', 'published') AND new_status IN ('approved', 'published'))
       OR (old_publication_status <> 'published'
           AND LOWER(COALESCE(NEW.status, '')) = 'published'))) THEN
    PERFORM public.create_role_notifications(
      'user',
      event_key || ':new-concert',
      'Konser baru di LiveTix',
      v_concert_title || ' baru saja ditambahkan. Lihat detail konser dan tiketnya.',
      'concert',
      'concert',
      NEW.id::TEXT,
      jsonb_build_object('starts_at', NEW.starts_at)
    );
  END IF;

  IF TG_OP = 'UPDATE' AND old_status IS DISTINCT FROM new_status
     AND new_status IN ('approved', 'published', 'rejected', 'ditolak') THEN
    PERFORM public.create_notification(
      NEW.producer_id,
      event_key || ':status:' || new_status,
      CASE WHEN new_status IN ('approved', 'published')
        THEN 'Konser disetujui'
        ELSE 'Pengajuan konser ditolak'
      END,
      CASE WHEN new_status IN ('approved', 'published')
        THEN v_concert_title || ' telah disetujui dan siap dipublikasikan.'
        ELSE v_concert_title || ' ditolak. Periksa catatan pada detail konser.'
      END,
      'approval',
      'concert',
      NEW.id::TEXT
    );
    IF new_status IN ('approved', 'published') THEN
      PERFORM public.create_role_notifications(
        'user',
        event_key || ':new-concert',
        'Konser baru di LiveTix',
        v_concert_title || ' baru saja ditambahkan. Lihat detail konser dan tiketnya.',
        'concert',
        'concert',
        NEW.id::TEXT,
        jsonb_build_object('starts_at', NEW.starts_at)
      );
    END IF;
  END IF;

  IF TG_OP = 'UPDATE' AND request_status = 'pending'
     AND old_request_status IS DISTINCT FROM request_status THEN
    PERFORM public.create_role_notifications(
      'admin',
      event_key || ':cancellation-request',
      'Pengajuan pembatalan konser',
      v_concert_title || ' menunggu persetujuan pembatalan.',
      'approval',
      'concert',
      NEW.id::TEXT
    );
  END IF;

  IF TG_OP = 'UPDATE' AND LOWER(COALESCE(NEW.status, '')) = 'cancelled'
     AND LOWER(COALESCE(OLD.status, '')) IS DISTINCT FROM 'cancelled' THEN
    INSERT INTO public.notifications (
      user_id, title, body, category, target_kind, target_id, data, dedupe_key
    )
    SELECT
      t.user_id,
      'Konser dibatalkan',
      v_concert_title || ' dibatalkan. Tiket ' ||
        COALESCE(NULLIF(t.ticket_code, ''), t.id::TEXT) ||
        ' dapat diajukan refund.',
      'ticket',
      'ticket',
      t.id::TEXT,
      jsonb_build_object(
        'action', 'request_refund',
        'ticket_id', t.id::TEXT,
        'concert_id', NEW.id::TEXT
      ),
      'concert:' || NEW.id::TEXT || ':cancelled:ticket:' || t.id::TEXT
    FROM public.tickets t
    WHERE t.concert_id::TEXT = NEW.id::TEXT
      AND t.user_id IS NOT NULL
      AND LOWER(COALESCE(t.status, '')) IN (
        'aktif', 'active', 'paid', 'dibatalkan', 'cancelled', 'canceled'
      )
    ON CONFLICT (dedupe_key) DO NOTHING;
  END IF;

  RETURN NEW;
END;
$$;

-- 3. Perbaiki process_scheduled_notifications
CREATE OR REPLACE FUNCTION public.process_scheduled_notifications()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  -- Notifikasi 1: Tiket hangus karena tidak dipakai
  INSERT INTO public.notifications (
    user_id, title, body, category, target_kind, target_id, data, dedupe_key
  )
  SELECT
    t.user_id,
    'Tiket telah hangus',
    'Tiket ' || COALESCE(NULLIF(t.ticket_code, ''), t.id::TEXT) ||
      ' untuk ' || COALESCE(NULLIF(t.concert_title, ''), 'konser ini') ||
      ' telah hangus karena tidak digunakan dalam 1 hari setelah konser dimulai.',
    'ticket',
    'ticket',
    t.id::TEXT,
    jsonb_build_object('ticket_id', t.id::TEXT, 'concert_id', t.concert_id),
    'ticket:' || t.id::TEXT || ':expired'
  FROM public.tickets t
  WHERE t.concert_starts_at IS NOT NULL
    AND t.concert_starts_at + INTERVAL '1 day' <= NOW()
    AND LOWER(COALESCE(t.status, '')) IN ('aktif', 'active', 'paid')
    AND t.qr_scans_used = 0
  ON CONFLICT (dedupe_key) DO NOTHING;

  UPDATE public.tickets
  SET status = 'hangus',
      updated_at = NOW()
  WHERE concert_starts_at IS NOT NULL
    AND concert_starts_at + INTERVAL '1 day' <= NOW()
    AND LOWER(COALESCE(status, '')) IN ('aktif', 'active', 'paid')
    AND qr_scans_used = 0;

  -- Notifikasi 2: Produser dapat mengajukan ulang konser setelah 24 jam penolakan
  INSERT INTO public.notifications (
    user_id, title, body, category, target_kind, target_id, data, dedupe_key
  )
  SELECT
    COALESCE(pp.user_id, pp.id),
    'Anda sudah dapat mengajukan ulang',
    'Masa jeda 24 jam setelah penolakan konser ' ||
      COALESCE(NULLIF(c.title, ''), 'Anda') ||
      ' telah selesai. Perbaiki pengajuan lalu kirim kembali.',
    'approval',
    'concert',
    c.id::TEXT,
    jsonb_build_object(
      'action', 'resubmit_concert',
      'concert_id', c.id::TEXT,
      'available_at', COALESCE(c.rejected_at, c.updated_at, c.created_at) + INTERVAL '24 hours'
    ),
    'concert:' || c.id::TEXT || ':resubmit-available:' ||
      COALESCE(c.rejected_at, c.updated_at, c.created_at)::TEXT
  FROM public.concerts c
  JOIN public.promoter_profiles pp
    ON pp.id::TEXT = c.producer_id::TEXT OR pp.user_id::TEXT = c.producer_id::TEXT
  WHERE LOWER(COALESCE(c.approval_status, c.status, '')) IN ('rejected', 'ditolak')
    AND COALESCE(c.rejected_at, c.updated_at, c.created_at) + INTERVAL '24 hours' <= NOW()
  ON CONFLICT (dedupe_key) DO NOTHING;

  -- Notifikasi 3: Produser dapat mengajukan ulang akun setelah 24 jam penolakan
  INSERT INTO public.notifications (
    user_id, title, body, category, target_kind, target_id, data, dedupe_key
  )
  SELECT
    COALESCE(pp.user_id, pp.id),
    'Anda sudah dapat mengajukan ulang',
    'Masa jeda 24 jam setelah penolakan akun produser Anda telah selesai. Perbaiki pengajuan lalu kirim kembali.',
    'approval',
    'producer',
    pp.id::TEXT,
    jsonb_build_object(
      'action', 'resubmit_producer',
      'available_at', COALESCE(pp.rejected_at, pp.updated_at, pp.created_at) + INTERVAL '24 hours'
    ),
    'producer:' || pp.id::TEXT || ':resubmit-available:' ||
      COALESCE(pp.rejected_at, pp.updated_at, pp.created_at)::TEXT
  FROM public.promoter_profiles pp
  WHERE LOWER(COALESCE(pp.approval_status, '')) IN ('rejected', 'ditolak')
    AND COALESCE(pp.rejected_at, pp.updated_at, pp.created_at) + INTERVAL '24 hours' <= NOW()
  ON CONFLICT (dedupe_key) DO NOTHING;
END;
$$;

COMMIT;

NOTIFY pgrst, 'reload schema';
