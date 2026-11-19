BEGIN;

CREATE TABLE IF NOT EXISTS public.notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  category TEXT NOT NULL DEFAULT 'general',
  target_kind TEXT,
  target_id TEXT,
  data JSONB NOT NULL DEFAULT '{}'::jsonb,
  dedupe_key TEXT NOT NULL UNIQUE,
  is_read BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user_created
  ON public.notifications (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread
  ON public.notifications (user_id, is_read)
  WHERE is_read = FALSE;

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.notifications FROM anon, authenticated;
GRANT SELECT ON public.notifications TO authenticated;
GRANT UPDATE (is_read) ON public.notifications TO authenticated;
GRANT ALL ON public.notifications TO service_role;

DROP POLICY IF EXISTS "Users read their notifications" ON public.notifications;
CREATE POLICY "Users read their notifications"
  ON public.notifications FOR SELECT TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users mark their notifications read" ON public.notifications;
CREATE POLICY "Users mark their notifications read"
  ON public.notifications FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE TABLE IF NOT EXISTS public.user_fcm_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  fcm_token TEXT NOT NULL UNIQUE,
  platform TEXT NOT NULL CHECK (platform IN ('android', 'ios')),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_user_fcm_tokens_user
  ON public.user_fcm_tokens (user_id);

ALTER TABLE public.user_fcm_tokens ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.user_fcm_tokens FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.user_fcm_tokens TO authenticated;
GRANT ALL ON public.user_fcm_tokens TO service_role;

DROP POLICY IF EXISTS "Users manage their FCM tokens" ON public.user_fcm_tokens;
CREATE POLICY "Users manage their FCM tokens"
  ON public.user_fcm_tokens FOR ALL TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE OR REPLACE FUNCTION public.create_notification(
  p_user_id UUID,
  p_dedupe_key TEXT,
  p_title TEXT,
  p_body TEXT,
  p_category TEXT,
  p_target_kind TEXT DEFAULT NULL,
  p_target_id TEXT DEFAULT NULL,
  p_data JSONB DEFAULT '{}'::jsonb
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF p_user_id IS NULL OR NULLIF(BTRIM(p_title), '') IS NULL THEN
    RETURN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = p_user_id) THEN
    RETURN;
  END IF;

  INSERT INTO public.notifications (
    user_id, title, body, category, target_kind, target_id, data, dedupe_key
  )
  VALUES (
    p_user_id,
    p_title,
    p_body,
    COALESCE(NULLIF(p_category, ''), 'general'),
    p_target_kind,
    p_target_id,
    COALESCE(p_data, '{}'::jsonb),
    p_dedupe_key
  )
  ON CONFLICT (dedupe_key) DO NOTHING;
END;
$$;

CREATE OR REPLACE FUNCTION public.create_role_notifications(
  p_role TEXT,
  p_event_key TEXT,
  p_title TEXT,
  p_body TEXT,
  p_category TEXT,
  p_target_kind TEXT DEFAULT NULL,
  p_target_id TEXT DEFAULT NULL,
  p_data JSONB DEFAULT '{}'::jsonb
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  recipient RECORD;
BEGIN
  FOR recipient IN
    SELECT id
    FROM public.profiles
    WHERE CASE
      WHEN LOWER(BTRIM(COALESCE(role, ''))) IN ('admin', 'super admin', 'superadmin')
        THEN 'admin'
      WHEN LOWER(BTRIM(COALESCE(role, ''))) IN ('produser', 'producer', 'promoter')
        THEN 'producer'
      WHEN LOWER(BTRIM(COALESCE(role, ''))) IN ('gatecrew', 'gate_crew', 'crew')
        THEN 'gatecrew'
      ELSE 'user'
    END = LOWER(BTRIM(p_role))
      AND LOWER(COALESCE(approval_status, 'approved')) = 'approved'
  LOOP
    PERFORM public.create_notification(
      recipient.id,
      p_event_key || ':' || recipient.id::TEXT,
      p_title,
      p_body,
      p_category,
      p_target_kind,
      p_target_id,
      p_data
    );
  END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION public.notify_profile_changes()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  normalized_role TEXT;
  new_status TEXT;
  old_status TEXT;
  display_name TEXT;
BEGIN
  normalized_role := CASE
    WHEN LOWER(BTRIM(COALESCE(NEW.role, ''))) IN ('produser', 'producer', 'promoter')
      THEN 'producer'
    WHEN LOWER(BTRIM(COALESCE(NEW.role, ''))) IN ('gatecrew', 'gate_crew', 'crew')
      THEN 'gatecrew'
    ELSE 'user'
  END;
  new_status := LOWER(BTRIM(COALESCE(NEW.approval_status, '')));
  old_status := CASE WHEN TG_OP = 'UPDATE'
    THEN LOWER(BTRIM(COALESCE(OLD.approval_status, '')))
    ELSE ''
  END;
  display_name := COALESCE(NULLIF(NEW.name, ''), NULLIF(NEW.full_name, ''), NEW.email, 'Akun');

  IF TG_OP = 'INSERT' OR (TG_OP = 'UPDATE' AND OLD.role IS DISTINCT FROM NEW.role) THEN
    IF normalized_role = 'gatecrew' THEN
      PERFORM public.create_role_notifications(
        'admin',
        'profile:' || NEW.id::TEXT || ':' || normalized_role,
        CASE WHEN normalized_role = 'producer'
          THEN 'Pendaftaran produser baru'
          ELSE 'Pendaftaran Gate Crew baru'
        END,
        display_name || ' mendaftar sebagai ' ||
          CASE WHEN normalized_role = 'producer' THEN 'produser.' ELSE 'Gate Crew.' END,
        'approval',
        'profile',
        NEW.id::TEXT
      );
    END IF;
  END IF;

  IF normalized_role = 'gatecrew'
     AND new_status IN ('approved', 'rejected', 'nonaktif')
     AND old_status IS DISTINCT FROM new_status THEN
    PERFORM public.create_notification(
      NEW.id,
      'profile-status:' || NEW.id::TEXT || ':' || new_status || ':' ||
        COALESCE(NEW.updated_at::TEXT, NOW()::TEXT),
      CASE new_status
        WHEN 'approved' THEN 'Akun disetujui'
        WHEN 'rejected' THEN 'Pengajuan akun ditolak'
        ELSE 'Status akun berubah'
      END,
      CASE new_status
        WHEN 'approved' THEN 'Akun Anda telah disetujui dan fitur sudah dapat digunakan.'
        WHEN 'rejected' THEN 'Pengajuan akun Anda ditolak. Silakan periksa alasan pada profil.'
        ELSE 'Status akun Anda berubah. Periksa informasi terbaru di profil.'
      END,
      'approval',
      'profile',
      NEW.id::TEXT
    );
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS notifications_profile_changes ON public.profiles;
CREATE TRIGGER notifications_profile_changes
  AFTER INSERT OR UPDATE OF role, approval_status ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.notify_profile_changes();

ALTER TABLE public.promoter_profiles
  ADD COLUMN IF NOT EXISTS rejection_reason TEXT,
  ADD COLUMN IF NOT EXISTS deactivation_reason TEXT;

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
  recipient_id := NEW.id;
  IF COALESCE(NEW.user_id, '') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
    recipient_id := NEW.user_id::UUID;
  END IF;
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

DROP TRIGGER IF EXISTS notifications_promoter_status_changes ON public.promoter_profiles;
CREATE TRIGGER notifications_promoter_status_changes
  AFTER INSERT OR UPDATE OF approval_status, rejection_reason, deactivation_reason
  ON public.promoter_profiles
  FOR EACH ROW EXECUTE FUNCTION public.notify_promoter_status_changes();

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
  concert_title TEXT;
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
  concert_title := COALESCE(NULLIF(NEW.title, ''), 'Konser');
  event_key := 'concert:' || NEW.id::TEXT;

  IF TG_OP = 'INSERT' AND new_status IN ('pending', 'pending_create') THEN
    PERFORM public.create_role_notifications(
      'admin',
      event_key || ':submitted',
      'Pengajuan konser baru',
      concert_title || ' menunggu persetujuan Admin.',
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
      concert_title || ' baru saja ditambahkan. Lihat detail konser dan tiketnya.',
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
        THEN concert_title || ' telah disetujui dan siap dipublikasikan.'
        ELSE concert_title || ' ditolak. Periksa catatan pada detail konser.'
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
        concert_title || ' baru saja ditambahkan. Lihat detail konser dan tiketnya.',
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
      concert_title || ' menunggu persetujuan pembatalan.',
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
      concert_title || ' dibatalkan. Tiket ' ||
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

ALTER TABLE public.concerts
  ADD COLUMN IF NOT EXISTS starts_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS rejected_at TIMESTAMPTZ;

CREATE OR REPLACE FUNCTION public.parse_livetix_concert_start(
  p_date TEXT,
  p_time TEXT DEFAULT NULL
)
RETURNS TIMESTAMPTZ
LANGUAGE plpgsql
IMMUTABLE
SET search_path = public, pg_temp
AS $$
DECLARE
  date_parts TEXT[];
  time_parts TEXT[];
  year_value INT;
  month_value INT;
  day_value INT;
  hour_value INT;
  minute_value INT;
  month_name TEXT;
  date_text TEXT := COALESCE(p_date, '');
  time_text TEXT := COALESCE(p_time, '');
BEGIN
  date_parts := regexp_match(date_text, '([0-9]{4})-([0-9]{1,2})-([0-9]{1,2})');
  IF date_parts IS NOT NULL THEN
    year_value := date_parts[1]::INT;
    month_value := date_parts[2]::INT;
    day_value := date_parts[3]::INT;
  ELSE
    date_parts := regexp_match(
      date_text,
      '([0-9]{1,2})[[:space:]]+([[:alpha:]]+)[[:space:]]+([0-9]{4})'
    );
    IF date_parts IS NULL THEN
      RETURN NULL;
    END IF;
    day_value := date_parts[1]::INT;
    month_name := LOWER(date_parts[2]);
    year_value := date_parts[3]::INT;
    month_value := CASE month_name
      WHEN 'januari' THEN 1 WHEN 'january' THEN 1 WHEN 'jan' THEN 1
      WHEN 'februari' THEN 2 WHEN 'february' THEN 2 WHEN 'feb' THEN 2
      WHEN 'maret' THEN 3 WHEN 'march' THEN 3 WHEN 'mar' THEN 3
      WHEN 'april' THEN 4 WHEN 'apr' THEN 4
      WHEN 'mei' THEN 5 WHEN 'may' THEN 5
      WHEN 'juni' THEN 6 WHEN 'june' THEN 6 WHEN 'jun' THEN 6
      WHEN 'juli' THEN 7 WHEN 'july' THEN 7 WHEN 'jul' THEN 7
      WHEN 'agustus' THEN 8 WHEN 'august' THEN 8 WHEN 'agu' THEN 8 WHEN 'aug' THEN 8
      WHEN 'september' THEN 9 WHEN 'sep' THEN 9
      WHEN 'oktober' THEN 10 WHEN 'october' THEN 10 WHEN 'okt' THEN 10 WHEN 'oct' THEN 10
      WHEN 'november' THEN 11 WHEN 'nov' THEN 11
      WHEN 'desember' THEN 12 WHEN 'december' THEN 12 WHEN 'des' THEN 12 WHEN 'dec' THEN 12
      ELSE NULL
    END;
  END IF;

  IF month_value IS NULL OR month_value NOT BETWEEN 1 AND 12
     OR day_value NOT BETWEEN 1 AND 31 THEN
    RETURN NULL;
  END IF;

  time_parts := regexp_match(date_text, '(?i)mulai[[:space:]]*([0-9]{1,2})[.:]([0-9]{2})');
  IF time_parts IS NULL THEN
    time_parts := regexp_match(date_text, '([0-9]{1,2})[:.]([0-9]{2})');
  END IF;
  IF time_parts IS NULL THEN
    time_parts := regexp_match(time_text, '(?i)mulai[[:space:]]*([0-9]{1,2})[.:]([0-9]{2})');
  END IF;
  IF time_parts IS NULL THEN
    time_parts := regexp_match(time_text, '([0-9]{1,2})[:.]([0-9]{2})');
  END IF;
  IF time_parts IS NULL THEN
    RETURN NULL;
  END IF;

  hour_value := time_parts[1]::INT;
  minute_value := time_parts[2]::INT;
  IF hour_value NOT BETWEEN 0 AND 23 OR minute_value NOT BETWEEN 0 AND 59 THEN
    RETURN NULL;
  END IF;

  RETURN make_timestamptz(
    year_value, month_value, day_value, hour_value, minute_value, 0, 'Asia/Jakarta'
  );
EXCEPTION
  WHEN datetime_field_overflow OR invalid_datetime_format THEN
    RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION public.set_concert_starts_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.starts_at := public.parse_livetix_concert_start(NEW.date, NEW.time);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS set_concert_starts_at ON public.concerts;
CREATE TRIGGER set_concert_starts_at
  BEFORE INSERT OR UPDATE OF date, time ON public.concerts
  FOR EACH ROW EXECUTE FUNCTION public.set_concert_starts_at();

UPDATE public.concerts
SET starts_at = public.parse_livetix_concert_start(date, time)
WHERE starts_at IS NULL;

DROP TRIGGER IF EXISTS notifications_concert_changes ON public.concerts;
CREATE TRIGGER notifications_concert_changes
  AFTER INSERT OR UPDATE OF approval_status, status, cancellation_status
  ON public.concerts
  FOR EACH ROW EXECUTE FUNCTION public.notify_concert_changes();

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

  IF payment_status = 'PAID' THEN
    PERFORM public.create_notification(
      NEW.user_id,
      'order:' || NEW.id || ':paid:user',
      'Pembayaran berhasil',
      'Pembayaran tiket ' || concert_title || ' berhasil. E-tiket Anda sudah diterbitkan.',
      'ticket',
      'order',
      NEW.id,
      jsonb_build_object('concert_id', NEW.concert_id, 'order_id', NEW.id)
    );

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
  ELSIF payment_status IN ('FAILED', 'EXPIRED', 'CANCELLED', 'CANCELED') THEN
    PERFORM public.create_notification(
      NEW.user_id,
      'order:' || NEW.id || ':' || payment_status || ':user',
      'Pembayaran belum berhasil',
      'Pembayaran tiket ' || concert_title || ' tidak berhasil. Anda dapat mencoba memesan kembali.',
      'payment',
      'order',
      NEW.id,
      jsonb_build_object('order_id', NEW.id, 'payment_status', payment_status)
    );
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS notifications_order_changes ON public.orders;
CREATE TRIGGER notifications_order_changes
  AFTER INSERT OR UPDATE OF payment_status ON public.orders
  FOR EACH ROW EXECUTE FUNCTION public.notify_order_changes();

CREATE OR REPLACE FUNCTION public.notify_gate_crew_assignment()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  recipient_id UUID;
  old_recipient_id UUID;
  concert_title TEXT;
BEGIN
  IF TG_OP <> 'DELETE' THEN
    recipient_id := COALESCE(
      NEW.crew_user_id,
      CASE
        WHEN COALESCE(NEW.crew_id::TEXT, '') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        THEN NEW.crew_id::TEXT::UUID
        ELSE NULL
      END
    );
  END IF;
  IF TG_OP <> 'INSERT' THEN
    old_recipient_id := COALESCE(
      OLD.crew_user_id,
    CASE
      WHEN COALESCE(OLD.crew_id::TEXT, '') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      THEN OLD.crew_id::TEXT::UUID
      ELSE NULL
    END
    );
  END IF;
  IF recipient_id IS NULL AND TG_OP <> 'DELETE' AND NULLIF(NEW.crew_email, '') IS NOT NULL THEN
    SELECT id INTO recipient_id
    FROM public.profiles
    WHERE LOWER(email) = LOWER(NEW.crew_email)
    LIMIT 1;
  END IF;
  IF old_recipient_id IS NULL AND TG_OP <> 'INSERT' AND NULLIF(OLD.crew_email, '') IS NOT NULL THEN
    SELECT id INTO old_recipient_id
    FROM public.profiles
    WHERE LOWER(email) = LOWER(OLD.crew_email)
    LIMIT 1;
  END IF;

  IF TG_OP = 'UPDATE'
     AND ROW(OLD.concert_id, OLD.crew_user_id, OLD.crew_id, OLD.crew_email, OLD.gate_name)
         IS NOT DISTINCT FROM
         ROW(NEW.concert_id, NEW.crew_user_id, NEW.crew_id, NEW.crew_email, NEW.gate_name) THEN
    RETURN NEW;
  END IF;

  SELECT c.title INTO concert_title
  FROM public.concerts c
  WHERE c.id::TEXT = COALESCE(NEW.concert_id, OLD.concert_id)::TEXT
  LIMIT 1;

  IF TG_OP = 'DELETE' OR
     (TG_OP = 'UPDATE' AND old_recipient_id IS DISTINCT FROM recipient_id) THEN
    PERFORM public.create_notification(
      old_recipient_id,
      'gate-assignment-revoked:' || OLD.id::TEXT || ':' ||
        COALESCE(OLD.updated_at::TEXT, OLD.created_at::TEXT, NOW()::TEXT),
      'Akses Gate Crew dicabut',
      'Penugasan Anda untuk ' || COALESCE(NULLIF(concert_title, ''), 'konser ini') || ' telah dicabut.',
      'assignment',
      'concert',
      OLD.concert_id::TEXT,
      jsonb_build_object('concert_id', OLD.concert_id, 'action', 'assignment_revoked')
    );
  END IF;

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;

  PERFORM public.create_notification(
    recipient_id,
    'gate-assignment:' || NEW.id::TEXT || ':' || COALESCE(NEW.updated_at::TEXT, NEW.created_at::TEXT, NOW()::TEXT),
    CASE
      WHEN TG_OP = 'UPDATE' AND OLD.gate_name IS DISTINCT FROM NEW.gate_name
        THEN 'Penugasan Gate Crew dipindahkan'
      ELSE 'Penugasan Gate Crew baru'
    END,
    CASE
      WHEN TG_OP = 'UPDATE' AND OLD.gate_name IS DISTINCT FROM NEW.gate_name
        THEN 'Tugas Anda untuk ' || COALESCE(NULLIF(concert_title, ''), 'konser') ||
          ' dipindahkan ke ' || COALESCE(NULLIF(NEW.gate_name, ''), 'gate yang ditentukan') || '.'
      ELSE 'Anda ditugaskan di ' || COALESCE(NULLIF(concert_title, ''), 'konser') ||
        ' pada ' || COALESCE(NULLIF(NEW.gate_name, ''), 'gate yang ditentukan')
    END,
    'assignment',
    'concert',
    NEW.concert_id::TEXT,
    jsonb_build_object('concert_id', NEW.concert_id, 'gate_name', NEW.gate_name)
  );

  RETURN NEW;
END;
$$;

ALTER TABLE public.concert_gate_crews
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

DROP TRIGGER IF EXISTS notifications_gate_crew_assignment ON public.concert_gate_crews;
CREATE OR REPLACE FUNCTION public.touch_gate_crew_assignment()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := NOW();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS touch_gate_crew_assignment ON public.concert_gate_crews;
CREATE TRIGGER touch_gate_crew_assignment
  BEFORE UPDATE ON public.concert_gate_crews
  FOR EACH ROW EXECUTE FUNCTION public.touch_gate_crew_assignment();

CREATE TRIGGER notifications_gate_crew_assignment
  AFTER INSERT OR UPDATE OR DELETE
  ON public.concert_gate_crews
  FOR EACH ROW EXECUTE FUNCTION public.notify_gate_crew_assignment();

CREATE OR REPLACE FUNCTION public.notify_cs_message()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  message_is_admin BOOLEAN;
  user_id_text TEXT;
  user_id_value UUID;
  sender_label TEXT;
  message_preview TEXT;
BEGIN
  message_is_admin := COALESCE(NEW.is_admin_reply, FALSE)
    OR COALESCE(NEW.is_from_admin, FALSE)
    OR LOWER(COALESCE(NEW.sender_role, '')) IN ('admin', 'superadmin');
  sender_label := COALESCE(NULLIF(NEW.sender_name, ''), 'Pengguna');
  message_preview := LEFT(BTRIM(COALESCE(NEW.message, '')), 160);

  IF message_is_admin THEN
    user_id_text := COALESCE(NULLIF(NEW.thread_user_id, ''), NULLIF(NEW.receiver_id, ''));
    IF user_id_text ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
      user_id_value := user_id_text::UUID;
      PERFORM public.create_notification(
        user_id_value,
        'cs-message:' || NEW.id::TEXT || ':' || user_id_value::TEXT,
        'Pesan baru dari Customer Service',
        message_preview,
        'support',
        'cs_thread',
        NEW.thread_id,
        jsonb_build_object('thread_id', NEW.thread_id)
      );
    END IF;
  ELSE
    PERFORM public.create_role_notifications(
      'admin',
      'cs-message:' || NEW.id::TEXT,
      'Pesan Customer Service baru',
      sender_label || ': ' || message_preview,
      'support',
      'cs_thread',
      NEW.thread_id,
      jsonb_build_object('thread_id', NEW.thread_id)
    );
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS notifications_cs_message ON public.cs_messages;
CREATE TRIGGER notifications_cs_message
  AFTER INSERT ON public.cs_messages
  FOR EACH ROW EXECUTE FUNCTION public.notify_cs_message();

ALTER TABLE public.tickets
  ADD COLUMN IF NOT EXISTS concert_starts_at TIMESTAMPTZ;

UPDATE public.tickets t
SET concert_starts_at = c.starts_at
FROM public.concerts c
WHERE c.id::TEXT = t.concert_id::TEXT
  AND t.concert_starts_at IS NULL;

DROP TRIGGER IF EXISTS notifications_ticket_status_changes ON public.tickets;
ALTER TABLE public.tickets
  DROP CONSTRAINT IF EXISTS chk_ticket_status;
ALTER TABLE public.tickets
  ADD CONSTRAINT chk_ticket_status
  CHECK (LOWER(status) IN (
    'aktif', 'active', 'paid', 'dipakai', 'sudah dipakai', 'used',
    'dibatalkan', 'cancelled', 'canceled', 'direfund', 'refunded', 'hangus'
  ));

CREATE OR REPLACE FUNCTION public.set_ticket_concert_start()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  concert_start TIMESTAMPTZ;
BEGIN
  SELECT starts_at INTO concert_start
  FROM public.concerts
  WHERE id::TEXT = NEW.concert_id::TEXT;
  NEW.concert_starts_at := concert_start;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS set_ticket_concert_start ON public.tickets;
CREATE TRIGGER set_ticket_concert_start
  BEFORE INSERT OR UPDATE OF concert_id ON public.tickets
  FOR EACH ROW EXECUTE FUNCTION public.set_ticket_concert_start();

CREATE OR REPLACE FUNCTION public.sync_ticket_concert_start()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE public.tickets
  SET concert_starts_at = NEW.starts_at
  WHERE concert_id::TEXT = NEW.id::TEXT;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS sync_ticket_concert_start ON public.concerts;
CREATE TRIGGER sync_ticket_concert_start
  AFTER UPDATE OF starts_at ON public.concerts
  FOR EACH ROW
  WHEN (OLD.starts_at IS DISTINCT FROM NEW.starts_at)
  EXECUTE FUNCTION public.sync_ticket_concert_start();

CREATE OR REPLACE FUNCTION public.notify_ticket_expired()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF LOWER(COALESCE(NEW.status, '')) = 'hangus'
     AND LOWER(COALESCE(OLD.status, '')) IS DISTINCT FROM 'hangus' THEN
    PERFORM public.create_notification(
      NEW.user_id,
      'ticket:' || NEW.id::TEXT || ':expired',
      'Tiket telah hangus',
      'Tiket ' || COALESCE(NULLIF(NEW.ticket_code, ''), NEW.id::TEXT) ||
        ' untuk ' || COALESCE(NULLIF(NEW.concert_title, ''), 'konser ini') ||
        ' telah hangus karena tidak digunakan dalam 1 hari setelah konser dimulai.',
      'ticket',
      'ticket',
      NEW.id::TEXT,
      jsonb_build_object('ticket_id', NEW.id::TEXT, 'concert_id', NEW.concert_id)
    );
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER notifications_ticket_status_changes
  AFTER UPDATE OF status ON public.tickets
  FOR EACH ROW EXECUTE FUNCTION public.notify_ticket_expired();

CREATE OR REPLACE FUNCTION public.process_scheduled_notifications()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  INSERT INTO public.notifications (
    user_id, title, body, category, target_kind, target_id, data, dedupe_key
  )
  SELECT DISTINCT ON (t.user_id, c.id, reminder.kind)
    t.user_id,
    reminder.title,
    reminder.body || c.title || '. Jangan lupa menyiapkan tiket Anda.',
    'concert',
    'concert',
    c.id::TEXT,
    jsonb_build_object(
      'concert_id', c.id::TEXT,
      'starts_at', c.starts_at,
      'reminder', reminder.kind
    ),
    'concert:' || c.id::TEXT || ':reminder:' || reminder.kind ||
      ':user:' || t.user_id::TEXT
  FROM public.concerts c
  JOIN public.tickets t ON t.concert_id::TEXT = c.id::TEXT
  CROSS JOIN LATERAL (
    VALUES
      ('one-day', 'Konser besok', 'Konser Anda akan dimulai besok: '),
      ('one-hour', 'Konser segera dimulai', 'Konser Anda dimulai sekitar 1 jam lagi: ')
  ) AS reminder(kind, title, body)
  WHERE c.starts_at IS NOT NULL
    AND LOWER(COALESCE(c.status, '')) NOT IN ('cancelled', 'canceled', 'dibatalkan')
    AND LOWER(COALESCE(t.status, '')) IN ('aktif', 'active', 'paid')
    AND t.qr_scans_used = 0
    AND (
      (reminder.kind = 'one-day'
        AND c.starts_at BETWEEN NOW() + INTERVAL '23 hours 55 minutes'
                            AND NOW() + INTERVAL '24 hours')
      OR
      (reminder.kind = 'one-hour'
        AND c.starts_at BETWEEN NOW() + INTERVAL '55 minutes'
                            AND NOW() + INTERVAL '1 hour')
    )
  ORDER BY t.user_id, c.id, reminder.kind, t.id
  ON CONFLICT (dedupe_key) DO NOTHING;

  INSERT INTO public.notifications (
    user_id, title, body, category, target_kind, target_id, data, dedupe_key
  )
  SELECT
    t.user_id,
    warning.title,
    'Tiket ' || COALESCE(NULLIF(t.ticket_code, ''), t.id::TEXT) ||
      ' untuk ' || COALESCE(NULLIF(t.concert_title, ''), 'konser ini') ||
      warning.body,
    'ticket',
    'ticket',
    t.id::TEXT,
    jsonb_build_object(
      'ticket_id', t.id::TEXT,
      'concert_id', t.concert_id,
      'expires_at', t.concert_starts_at + INTERVAL '1 day'
    ),
    'ticket:' || t.id::TEXT || ':expiry-warning:' || warning.kind
  FROM public.tickets t
  CROSS JOIN LATERAL (
    VALUES
      ('one-hour', 'Tiket akan hangus 1 jam lagi jika belum digunakan.'),
      ('five-minutes', 'Tiket akan hangus dalam 5 menit jika belum digunakan.')
  ) AS warning(kind, body)
  WHERE t.concert_starts_at IS NOT NULL
    AND LOWER(COALESCE(t.status, '')) IN ('aktif', 'active', 'paid')
    AND t.qr_scans_used = 0
    AND (
      (warning.kind = 'one-hour'
        AND t.concert_starts_at + INTERVAL '1 day'
          BETWEEN NOW() + INTERVAL '55 minutes' AND NOW() + INTERVAL '1 hour')
      OR
      (warning.kind = 'five-minutes'
        AND t.concert_starts_at + INTERVAL '1 day'
          BETWEEN NOW() AND NOW() + INTERVAL '5 minutes')
    )
  ON CONFLICT (dedupe_key) DO NOTHING;

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

  INSERT INTO public.notifications (
    user_id, title, body, category, target_kind, target_id, data, dedupe_key
  )
  SELECT
    CASE
      WHEN COALESCE(pp.user_id, '') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        THEN pp.user_id::UUID
      ELSE pp.id
    END,
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

  INSERT INTO public.notifications (
    user_id, title, body, category, target_kind, target_id, data, dedupe_key
  )
  SELECT
    CASE
      WHEN COALESCE(pp.user_id, '') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        THEN pp.user_id::UUID
      ELSE pp.id
    END,
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

DO $$
BEGIN
  BEGIN
    CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA pg_catalog;
    PERFORM cron.schedule(
      'livetix-notification-scheduler',
      '*/5 * * * *',
      'SELECT public.process_scheduled_notifications()'
    );
  EXCEPTION
    WHEN OTHERS THEN
      RAISE NOTICE 'pg_cron belum tersedia; jadwalkan process_scheduled_notifications() lewat Supabase Cron: %', SQLERRM;
  END;
END;
$$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'notifications'
  ) IS FALSE THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
  END IF;
EXCEPTION
  WHEN undefined_object THEN
    RAISE NOTICE 'Publication supabase_realtime belum tersedia.';
END;
$$;

REVOKE ALL ON FUNCTION public.create_notification(UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, JSONB)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.create_role_notifications(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, JSONB)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.notify_profile_changes()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.notify_promoter_status_changes()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.notify_concert_changes()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.notify_order_changes()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.notify_gate_crew_assignment()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.notify_cs_message()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.notify_ticket_expired()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.sync_ticket_concert_start()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.process_scheduled_notifications()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.parse_livetix_concert_start(TEXT, TEXT)
  FROM PUBLIC, anon, authenticated;

COMMIT;
