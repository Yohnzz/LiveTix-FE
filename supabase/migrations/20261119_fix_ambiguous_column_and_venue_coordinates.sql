-- 1. Tambahkan kolom koordinat venue jika belum ada
ALTER TABLE public.concerts
  ADD COLUMN IF NOT EXISTS venue_latitude DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS venue_longitude DOUBLE PRECISION;

-- 2. Perbaiki fungsi trigger status konser agar tidak terjadi ambiguitas nama kolom (concert_title -> v_concert_title)
CREATE OR REPLACE FUNCTION public.notify_concert_status_changes()
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
      'producer',
      event_key || ':approved',
      'Konser disetujui',
      v_concert_title || ' telah disetujui oleh Super Admin.',
      'approval',
      'concert',
      NEW.id::TEXT,
      jsonb_build_object('starts_at', NEW.starts_at)
    );

    IF old_publication_status IS DISTINCT FROM 'published' AND
       LOWER(COALESCE(NEW.status, '')) = 'published' THEN
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

  IF TG_OP = 'UPDATE' AND old_status IS DISTINCT FROM new_status
     AND new_status IN ('rejected', 'ditolak') THEN
    PERFORM public.create_notification(
      NEW.producer_id,
      event_key || ':rejected:' || COALESCE(NEW.rejected_at::TEXT, NOW()::TEXT),
      'Pengajuan konser ditolak',
      v_concert_title || ' ditolak. Alasan: ' ||
        COALESCE(NULLIF(NEW.rejection_reason, ''), 'Tidak ada catatan perbaikan.'),
      'approval',
      'concert',
      NEW.id::TEXT,
      jsonb_build_object('reason', NEW.rejection_reason)
    );
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

-- 3. Muat ulang cache skema PostgREST Supabase
NOTIFY pgrst, 'reload schema';
