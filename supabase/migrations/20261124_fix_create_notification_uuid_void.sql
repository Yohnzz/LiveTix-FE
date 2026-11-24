-- ==============================================================================
-- FIX ERROR 22P02: invalid input syntax for type uuid: ""
-- Pada create_notification(text, ...) dan perbaiki logika notify_concert_changes
-- ==============================================================================

-- 1. Hapus varian create_notification bertipe return UUID yang menyebabkan error cast void ke UUID
DROP FUNCTION IF EXISTS public.create_notification(text, text, text, text, text, text, text, jsonb);

-- 2. Buat ulang create_notification(text, ...) dengan RETURNS VOID
CREATE OR REPLACE FUNCTION public.create_notification(
  p_user_id text,
  p_dedupe_key text,
  p_title text,
  p_body text,
  p_type text,
  p_target_type text DEFAULT NULL::text,
  p_target_id text DEFAULT NULL::text,
  p_metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uuid UUID;
BEGIN
  IF p_user_id IS NULL OR BTRIM(p_user_id) = '' THEN
    RETURN;
  END IF;

  IF p_user_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
    v_uuid := p_user_id::UUID;
    PERFORM public.create_notification(
      v_uuid,
      p_dedupe_key,
      p_title,
      p_body,
      p_type,
      p_target_type,
      p_target_id,
      p_metadata
    );
  END IF;
END;
$$;

-- Berikan permission
GRANT EXECUTE ON FUNCTION public.create_notification(text, text, text, text, text, text, text, jsonb) TO authenticated, service_role, anon;

-- 3. Perbaiki notify_concert_changes agar membedakan approval konser baru vs approval pembatalan konser
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
  event_key TEXT;
  v_concert_title TEXT;
  is_cancellation BOOLEAN;
BEGIN
  v_concert_title := COALESCE(NULLIF(NEW.title, ''), 'Konser');
  event_key := 'concert:' || NEW.id::TEXT;

  -- Cek apakah perubahan ini berkaitan dengan pembatalan konser
  is_cancellation := LOWER(COALESCE(NEW.status, '')) = 'cancelled'
                     OR LOWER(COALESCE(NEW.cancellation_status, '')) IN ('approved', 'disetujui');

  -- 1. Notifikasi ke Pemegang Tiket saat konser dibatalkan
  IF TG_OP = 'UPDATE' AND LOWER(COALESCE(NEW.status, '')) = 'cancelled'
     AND LOWER(COALESCE(OLD.status, '')) IS DISTINCT FROM 'cancelled' THEN
    
    -- Notifikasi ke tiket holders
    INSERT INTO public.notifications (
      user_id, title, body, category, target_kind, target_id, data, dedupe_key
    )
    SELECT
      t.user_id::UUID,
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
      AND t.user_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      AND LOWER(COALESCE(t.status, '')) IN (
        'aktif', 'active', 'paid', 'dibatalkan', 'cancelled', 'canceled'
      )
    ON CONFLICT (dedupe_key) DO NOTHING;

    -- Notifikasi konfirmasi ke Produser bahwa pembatalan telah disetujui
    IF NEW.producer_id IS NOT NULL THEN
      PERFORM public.create_notification(
        NEW.producer_id::TEXT,
        event_key || ':cancellation:approved',
        'Pembatalan konser disetujui',
        'Pengajuan pembatalan untuk ' || v_concert_title || ' telah disetujui oleh Admin.',
        'approval',
        'concert',
        NEW.id::TEXT
      );
    END IF;

    RETURN NEW;
  END IF;

  -- 2. Jika bukan pembatalan konser, proses alur konser biasa (pending, approved, published, rejected)
  new_status := LOWER(BTRIM(COALESCE(NEW.approval_status, NEW.status, '')));
  old_status := CASE WHEN TG_OP = 'UPDATE'
    THEN LOWER(BTRIM(COALESCE(OLD.approval_status, OLD.status, '')))
    ELSE ''
  END;
  request_status := LOWER(BTRIM(COALESCE(NEW.cancellation_status, '')));
  old_request_status := CASE WHEN TG_OP = 'UPDATE'
    THEN LOWER(BTRIM(COALESCE(OLD.cancellation_status, '')))
    ELSE ''
  END;

  -- Notifikasi pengajuan konser baru ke Admin
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

  -- Notifikasi ke user saat konser baru dipublikasikan
  IF NOT is_cancellation THEN
    IF (TG_OP = 'INSERT' AND
        (new_status IN ('approved', 'published') OR LOWER(COALESCE(NEW.status, '')) = 'published'))
       OR (TG_OP = 'UPDATE' AND
        ((old_status NOT IN ('approved', 'published') AND new_status IN ('approved', 'published'))
         OR (LOWER(COALESCE(OLD.status, '')) <> 'published'
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

    -- Notifikasi ke Produser saat konser baru disetujui / ditolak
    IF TG_OP = 'UPDATE' AND old_status IS DISTINCT FROM new_status
       AND new_status IN ('approved', 'published', 'rejected', 'ditolak') THEN
      IF NEW.producer_id IS NOT NULL THEN
        PERFORM public.create_notification(
          NEW.producer_id::TEXT,
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
      END IF;
    END IF;
  END IF;

  -- Notifikasi pengajuan pembatalan konser oleh Produser ke Admin
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

  -- Notifikasi penolakan pembatalan konser oleh Admin ke Produser
  IF TG_OP = 'UPDATE' AND request_status IN ('rejected', 'ditolak')
     AND old_request_status IS DISTINCT FROM request_status THEN
    IF NEW.producer_id IS NOT NULL THEN
      PERFORM public.create_notification(
        NEW.producer_id::TEXT,
        event_key || ':cancellation:rejected',
        'Pengajuan pembatalan konser ditolak',
        'Pengajuan pembatalan untuk ' || v_concert_title || ' ditolak oleh Admin. Konser tetap berjalan.',
        'approval',
        'concert',
        NEW.id::TEXT
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

NOTIFY pgrst, 'reload schema';
