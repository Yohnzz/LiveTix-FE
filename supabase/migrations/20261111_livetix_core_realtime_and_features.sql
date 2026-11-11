-- ==============================================================================
-- LIVE TIX: MASTER REALTIME TICKET AVAILABILITY, PROFILE STORAGE, LIKES & CS
-- File: 20261111_livetix_core_realtime_and_features.sql
-- ==============================================================================

-- 1. PROFILES & STORAGE: url_foto dan bucket 'avatars'
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS url_foto TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS avatar_url TEXT;

-- Buat bucket storage 'avatars' jika belum ada
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('avatars', 'avatars', true, 5242880, ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/jpg'])
ON CONFLICT (id) DO UPDATE SET public = true;

-- Storage policies untuk bucket avatars
DROP POLICY IF EXISTS "Avatars Public Read" ON storage.objects;
CREATE POLICY "Avatars Public Read" ON storage.objects
  FOR SELECT USING (bucket_id = 'avatars');

DROP POLICY IF EXISTS "Avatars Upload All" ON storage.objects;
CREATE POLICY "Avatars Upload All" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'avatars');

DROP POLICY IF EXISTS "Avatars Update All" ON storage.objects;
CREATE POLICY "Avatars Update All" ON storage.objects
  FOR UPDATE USING (bucket_id = 'avatars') WITH CHECK (bucket_id = 'avatars');

DROP POLICY IF EXISTS "Avatars Delete All" ON storage.objects;
CREATE POLICY "Avatars Delete All" ON storage.objects
  FOR DELETE USING (bucket_id = 'avatars');

-- 2. CONCERTS: Kolom gates (JSONB) dan likes_count
ALTER TABLE public.concerts ADD COLUMN IF NOT EXISTS gates JSONB DEFAULT '[]'::jsonb;
ALTER TABLE public.concerts ADD COLUMN IF NOT EXISTS likes_count BIGINT DEFAULT 0;

-- 3. TICKET TIERS: Kuota, Terjual, dan Reservasi (Atomic Stock Tracking)
ALTER TABLE public.ticket_tiers ADD COLUMN IF NOT EXISTS quota INT DEFAULT 100;
ALTER TABLE public.ticket_tiers ADD COLUMN IF NOT EXISTS total_quota INT DEFAULT 100;
ALTER TABLE public.ticket_tiers ADD COLUMN IF NOT EXISTS sold_count INT DEFAULT 0;
ALTER TABLE public.ticket_tiers ADD COLUMN IF NOT EXISTS reserved_count INT DEFAULT 0;
ALTER TABLE public.ticket_tiers ADD COLUMN IF NOT EXISTS is_sold_out BOOLEAN DEFAULT FALSE;

-- 3B. ORDERS: Tracking batas waktu 1 jam dan flag reservasi stok
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS is_stock_reserved BOOLEAN DEFAULT FALSE;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS tier_name TEXT;

-- 4. CONCERT LIKES: Relasi unik user_id dan concert_id
CREATE TABLE IF NOT EXISTS public.concert_likes (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL,
  concert_id TEXT NOT NULL REFERENCES public.concerts(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT concert_likes_user_concert_key UNIQUE(user_id, concert_id)
);

DO $$
BEGIN
  DELETE FROM public.concert_likes a
  USING public.concert_likes b
  WHERE a.ctid < b.ctid
    AND a.user_id = b.user_id
    AND a.concert_id = b.concert_id;

  CREATE UNIQUE INDEX IF NOT EXISTS concert_likes_user_concert_uidx
    ON public.concert_likes(user_id, concert_id);
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

ALTER TABLE public.concert_likes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Concert Likes Select All" ON public.concert_likes;
CREATE POLICY "Concert Likes Select All" ON public.concert_likes FOR SELECT USING (true);
DROP POLICY IF EXISTS "Concert Likes Insert All" ON public.concert_likes;
CREATE POLICY "Concert Likes Insert All" ON public.concert_likes FOR INSERT WITH CHECK (true);
DROP POLICY IF EXISTS "Concert Likes Delete All" ON public.concert_likes;
CREATE POLICY "Concert Likes Delete All" ON public.concert_likes FOR DELETE USING (true);

-- 5. CUSTOMER SERVICE MESSAGES (cs_messages)
CREATE TABLE IF NOT EXISTS public.cs_messages (
  id TEXT PRIMARY KEY,
  thread_id TEXT NOT NULL,
  sender_id TEXT,
  sender_name TEXT,
  sender_email TEXT,
  sender_role TEXT DEFAULT 'User',
  is_admin_reply BOOLEAN DEFAULT FALSE,
  is_from_admin BOOLEAN DEFAULT FALSE,
  message TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'cs_messages' AND column_name = 'id' AND data_type = 'uuid'
  ) THEN
    ALTER TABLE public.cs_messages ALTER COLUMN id TYPE TEXT USING id::text;
  END IF;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- Pastikan seluruh kolom tersedia jika tabel cs_messages sudah ada
ALTER TABLE public.cs_messages ADD COLUMN IF NOT EXISTS id TEXT;
ALTER TABLE public.cs_messages ADD COLUMN IF NOT EXISTS thread_id TEXT;
ALTER TABLE public.cs_messages ADD COLUMN IF NOT EXISTS sender_id TEXT;
ALTER TABLE public.cs_messages ADD COLUMN IF NOT EXISTS sender_name TEXT;
ALTER TABLE public.cs_messages ADD COLUMN IF NOT EXISTS sender_email TEXT;
ALTER TABLE public.cs_messages ADD COLUMN IF NOT EXISTS sender_role TEXT DEFAULT 'User';
ALTER TABLE public.cs_messages ADD COLUMN IF NOT EXISTS receiver_id TEXT;
ALTER TABLE public.cs_messages ADD COLUMN IF NOT EXISTS receiver_name TEXT;
ALTER TABLE public.cs_messages ADD COLUMN IF NOT EXISTS receiver_role TEXT;
ALTER TABLE public.cs_messages ADD COLUMN IF NOT EXISTS thread_user_id TEXT;
ALTER TABLE public.cs_messages ADD COLUMN IF NOT EXISTS thread_user_name TEXT;
ALTER TABLE public.cs_messages ADD COLUMN IF NOT EXISTS thread_user_email TEXT;
ALTER TABLE public.cs_messages ADD COLUMN IF NOT EXISTS thread_user_role TEXT DEFAULT 'User';
ALTER TABLE public.cs_messages ADD COLUMN IF NOT EXISTS is_admin_reply BOOLEAN DEFAULT FALSE;
ALTER TABLE public.cs_messages ADD COLUMN IF NOT EXISTS is_from_admin BOOLEAN DEFAULT FALSE;
ALTER TABLE public.cs_messages ADD COLUMN IF NOT EXISTS message TEXT;
ALTER TABLE public.cs_messages ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();

ALTER TABLE public.cs_messages ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "CS Messages Select All" ON public.cs_messages;
CREATE POLICY "CS Messages Select All" ON public.cs_messages FOR SELECT USING (true);
DROP POLICY IF EXISTS "CS Messages Insert All" ON public.cs_messages;
CREATE POLICY "CS Messages Insert All" ON public.cs_messages FOR INSERT WITH CHECK (true);
DROP POLICY IF EXISTS "CS Messages Update All" ON public.cs_messages;
CREATE POLICY "CS Messages Update All" ON public.cs_messages FOR UPDATE USING (true) WITH CHECK (true);

-- 6. CONCERT GATE CREWS & TICKET CHECKINS
CREATE TABLE IF NOT EXISTS public.concert_gate_crews (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  concert_id TEXT NOT NULL,
  concert_title TEXT DEFAULT 'Konser LiveTix',
  venue TEXT DEFAULT 'Venue Utama',
  crew_id TEXT,
  crew_user_id UUID,
  crew_email TEXT,
  crew_name TEXT,
  phone TEXT,
  gate_name TEXT DEFAULT 'Gate A',
  gate_section TEXT DEFAULT 'Gate A',
  assigned_by TEXT,
  assigned_at TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Relaksasi foreign key & tipe kolom agar produser bisa mengundang gate crew baru dengan concert_id TEXT
DO $$
BEGIN
  BEGIN
    ALTER TABLE public.concert_gate_crews DROP CONSTRAINT IF EXISTS concert_gate_crews_concert_id_fkey;
  EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN
    ALTER TABLE public.concert_gate_crews DROP CONSTRAINT IF EXISTS concert_gate_crews_crew_id_fkey;
  EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN
    ALTER TABLE public.concert_gate_crews DROP CONSTRAINT IF EXISTS concert_gate_crews_crew_user_id_fkey;
  EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN
    ALTER TABLE public.concert_gate_crews DROP CONSTRAINT IF EXISTS concert_gate_crews_assigned_by_fkey;
  EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN
    ALTER TABLE public.concert_gate_crews DROP CONSTRAINT IF EXISTS concert_gate_crews_concert_id_crew_user_id_key;
  EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN
    ALTER TABLE public.concert_gate_crews DROP CONSTRAINT IF EXISTS concert_gate_crews_concert_id_crew_id_key;
  EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN
    ALTER TABLE public.concert_gate_crews ALTER COLUMN concert_id TYPE TEXT USING concert_id::text;
  EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN
    ALTER TABLE public.concert_gate_crews ALTER COLUMN crew_id TYPE TEXT USING crew_id::text;
  EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN
    ALTER TABLE public.concert_gate_crews ALTER COLUMN crew_user_id DROP NOT NULL;
  EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN
    ALTER TABLE public.concert_gate_crews ALTER COLUMN assigned_by TYPE TEXT USING assigned_by::text;
  EXCEPTION WHEN OTHERS THEN NULL; END;
END $$;

ALTER TABLE public.concert_gate_crews ADD COLUMN IF NOT EXISTS crew_id TEXT;
ALTER TABLE public.concert_gate_crews ADD COLUMN IF NOT EXISTS crew_user_id UUID;
ALTER TABLE public.concert_gate_crews ADD COLUMN IF NOT EXISTS crew_email TEXT;
ALTER TABLE public.concert_gate_crews ADD COLUMN IF NOT EXISTS crew_name TEXT;
ALTER TABLE public.concert_gate_crews ADD COLUMN IF NOT EXISTS phone TEXT;
ALTER TABLE public.concert_gate_crews ADD COLUMN IF NOT EXISTS gate_name TEXT DEFAULT 'Gate A';
ALTER TABLE public.concert_gate_crews ADD COLUMN IF NOT EXISTS gate_section TEXT DEFAULT 'Gate A';
ALTER TABLE public.concert_gate_crews ADD COLUMN IF NOT EXISTS concert_title TEXT;
ALTER TABLE public.concert_gate_crews ADD COLUMN IF NOT EXISTS venue TEXT;
ALTER TABLE public.concert_gate_crews ADD COLUMN IF NOT EXISTS assigned_by TEXT;
ALTER TABLE public.concert_gate_crews ADD COLUMN IF NOT EXISTS assigned_at TIMESTAMPTZ DEFAULT NOW();

DO $$
BEGIN
  DELETE FROM public.concert_gate_crews a
  USING public.concert_gate_crews b
  WHERE a.ctid < b.ctid
    AND a.concert_id = b.concert_id
    AND LOWER(TRIM(COALESCE(a.crew_email, ''))) <> ''
    AND LOWER(TRIM(a.crew_email)) = LOWER(TRIM(b.crew_email));

  CREATE UNIQUE INDEX IF NOT EXISTS cgc_unique_concert_crew_email
    ON public.concert_gate_crews(concert_id, crew_email)
    WHERE crew_email IS NOT NULL AND TRIM(crew_email) <> '';
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

ALTER TABLE public.concert_gate_crews ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Concert Gate Crews Select All" ON public.concert_gate_crews;
CREATE POLICY "Concert Gate Crews Select All" ON public.concert_gate_crews FOR SELECT USING (true);
DROP POLICY IF EXISTS "Concert Gate Crews Manage All" ON public.concert_gate_crews;
CREATE POLICY "Concert Gate Crews Manage All" ON public.concert_gate_crews FOR ALL USING (true) WITH CHECK (true);

-- Tabel ticket_checkins (pastikan concert_id bertipe TEXT bukan UUID untuk mencegah error 22P02)
CREATE TABLE IF NOT EXISTS public.ticket_checkins (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  concert_id TEXT NOT NULL,
  concert_title TEXT,
  ticket_code TEXT NOT NULL,
  booking_code TEXT,
  attendee_name TEXT,
  category TEXT,
  gate_name TEXT DEFAULT 'Gate A',
  crew_id TEXT,
  crew_email TEXT,
  crew_name TEXT,
  status TEXT DEFAULT 'berhasil',
  scanned_count INT DEFAULT 1,
  quota INT DEFAULT 1,
  notes TEXT,
  checked_in_at TIMESTAMPTZ DEFAULT NOW(),
  scanned_at TIMESTAMPTZ DEFAULT NOW()
);

-- Jika tabel ticket_checkins sudah ada sebelumnya dengan concert_id UUID, ubah ke TEXT
DO $$
BEGIN
  BEGIN
    ALTER TABLE public.ticket_checkins DROP CONSTRAINT IF EXISTS ticket_checkins_concert_id_fkey;
  EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN
    ALTER TABLE public.ticket_checkins ALTER COLUMN concert_id TYPE TEXT USING concert_id::text;
  EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN
    ALTER TABLE public.ticket_checkins ALTER COLUMN crew_id TYPE TEXT USING crew_id::text;
  EXCEPTION WHEN OTHERS THEN NULL; END;
END $$;

ALTER TABLE public.ticket_checkins ADD COLUMN IF NOT EXISTS quota INT DEFAULT 1;
ALTER TABLE public.ticket_checkins ADD COLUMN IF NOT EXISTS notes TEXT;
ALTER TABLE public.ticket_checkins ADD COLUMN IF NOT EXISTS checked_in_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE public.ticket_checkins ADD COLUMN IF NOT EXISTS scanned_at TIMESTAMPTZ DEFAULT NOW();

ALTER TABLE public.ticket_checkins ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Ticket Checkins Select All" ON public.ticket_checkins;
CREATE POLICY "Ticket Checkins Select All" ON public.ticket_checkins FOR SELECT USING (true);
DROP POLICY IF EXISTS "Ticket Checkins Insert All" ON public.ticket_checkins;
CREATE POLICY "Ticket Checkins Insert All" ON public.ticket_checkins FOR INSERT WITH CHECK (true);
DROP POLICY IF EXISTS "Ticket Checkins Update All" ON public.ticket_checkins;
CREATE POLICY "Ticket Checkins Update All" ON public.ticket_checkins FOR UPDATE USING (true) WITH CHECK (true);

-- ==============================================================================
-- 7. ATOMIC RPC FUNCTIONS: PREVENT OVERSELLING & RACE CONDITIONS
-- ==============================================================================

-- A. Reservasi Stok Tiket Secara Atomic (Pending Payment selama 1 jam)
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
BEGIN
  IF p_quantity IS NULL OR p_quantity <= 0 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Jumlah tiket tidak valid.'
    );
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
      'expires_at', COALESCE(v_order.expires_at, NOW() + INTERVAL '1 hour')
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

  v_expires_at := COALESCE(v_order.expires_at, NOW() + INTERVAL '1 hour');

  -- 4. Update pesanan dengan status PENDING, flag reservasi, dan batas waktu 1 jam
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

-- B. Lepas Reservasi Tiket (Jika dibatalkan atau kadaluarsa 1 jam)
CREATE OR REPLACE FUNCTION public.release_ticket_reservation(
  p_order_id TEXT,
  p_reason TEXT DEFAULT 'CANCELLED'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_order RECORD;
  v_qty INT;
BEGIN
  SELECT * INTO v_order
  FROM public.orders
  WHERE id = p_order_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Pesanan tidak ditemukan.');
  END IF;

  -- Hanya pesanan PENDING yang bisa dilepas reservasinya
  IF UPPER(COALESCE(v_order.payment_status, '')) = 'PENDING' THEN
    v_qty := COALESCE(v_order.quantity, 1);

    -- Kembalikan stok ke ticket_tiers jika stok sebelumnya memang di-reserve
    IF COALESCE(v_order.is_stock_reserved, FALSE) = TRUE AND v_order.tier_id IS NOT NULL THEN
      UPDATE public.ticket_tiers
      SET reserved_count = GREATEST(0, COALESCE(reserved_count, 0) - v_qty),
          is_sold_out = (COALESCE(sold_count, 0) + GREATEST(0, COALESCE(reserved_count, 0) - v_qty) >= COALESCE(total_quota, quota, 0))
      WHERE id::text = v_order.tier_id::text;
    END IF;

    -- Update status pesanan menjadi CANCELLED atau EXPIRED
    UPDATE public.orders
    SET payment_status = UPPER(p_reason),
        is_stock_reserved = FALSE,
        updated_at = NOW()
    WHERE id = p_order_id;

    RETURN jsonb_build_object('success', true, 'released_quantity', v_qty, 'status', UPPER(p_reason));
  END IF;

  RETURN jsonb_build_object('success', false, 'message', 'Pesanan bukan berstatus PENDING.');
END;
$$;

-- B2. Lepas seluruh pesanan PENDING yang sudah melewati expires_at (1 jam)
CREATE OR REPLACE FUNCTION public.release_expired_orders()
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_rec RECORD;
  v_count INT := 0;
BEGIN
  FOR v_rec IN
    SELECT id
    FROM public.orders
    WHERE UPPER(COALESCE(payment_status, '')) = 'PENDING'
      AND expires_at IS NOT NULL
      AND expires_at < NOW()
    LIMIT 50
  LOOP
    PERFORM public.release_ticket_reservation(v_rec.id::text, 'EXPIRED');
    v_count := v_count + 1;
  END LOOP;
  RETURN v_count;
END;
$$;

-- C. Konfirmasi Pembayaran Berhasil (Ubah PENDING menjadi PAID, Terbitkan Tiket Resmi)
CREATE OR REPLACE FUNCTION public.confirm_ticket_payment(
  p_order_id TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_order RECORD;
  v_tier RECORD;
  v_qty INT;
  v_booking_code TEXT;
  v_clean_code TEXT;
  v_user_uuid UUID;
  v_new_reserved INT;
BEGIN
  SELECT * INTO v_order
  FROM public.orders
  WHERE id = p_order_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Pesanan tidak ditemukan.');
  END IF;

  v_qty := COALESCE(v_order.quantity, 1);
  v_clean_code := REPLACE(p_order_id, 'ORD-', '');
  v_booking_code := 'LTX-' || v_clean_code || '-2A';

  -- Jika sudah PAID sebelumnya dan tidak lagi menahan reserved_count
  IF UPPER(COALESCE(v_order.payment_status, '')) IN ('PAID', 'SETTLEMENT', 'CAPTURE')
     AND COALESCE(v_order.is_stock_reserved, FALSE) = FALSE THEN
    RETURN jsonb_build_object('success', true, 'already_paid', true, 'booking_code', v_booking_code);
  END IF;

  -- 1. Pindahkan reserved_count ke sold_count pada ticket_tiers
  IF v_order.tier_id IS NOT NULL THEN
    SELECT * INTO v_tier
    FROM public.ticket_tiers
    WHERE id::text = v_order.tier_id::text
    FOR UPDATE;

    IF FOUND THEN
      v_new_reserved := CASE
        WHEN COALESCE(v_order.is_stock_reserved, FALSE) THEN GREATEST(0, COALESCE(v_tier.reserved_count, 0) - v_qty)
        ELSE COALESCE(v_tier.reserved_count, 0)
      END;

      UPDATE public.ticket_tiers
      SET reserved_count = v_new_reserved,
          sold_count = COALESCE(sold_count, 0) + v_qty,
          is_sold_out = (COALESCE(sold_count, 0) + v_qty + v_new_reserved >= COALESCE(total_quota, quota, 0))
      WHERE id = v_tier.id;
    END IF;
  END IF;

  -- 2. Update status order menjadi PAID
  UPDATE public.orders
  SET payment_status = 'PAID',
      is_stock_reserved = FALSE,
      paid_at = COALESCE(paid_at, NOW()),
      updated_at = NOW()
  WHERE id = p_order_id;

  -- 3. Terbitkan e-tiket resmi ke tabel tickets bila belum ada
  v_user_uuid := v_order.user_id;
  IF NOT EXISTS (SELECT 1 FROM public.tickets WHERE order_id = p_order_id) THEN
    BEGIN
      INSERT INTO public.tickets (
        id,
        order_id,
        user_id,
        tier_id,
        ticket_code,
        secret_hmac,
        tier_name,
        gate_name,
        status,
        qr_scan_quota,
        qr_scans_used,
        issued_at
      ) VALUES (
        gen_random_uuid(),
        p_order_id,
        v_user_uuid,
        v_order.tier_id,
        v_booking_code,
        'HMAC-' || v_clean_code,
        COALESCE(v_order.tier_name, 'Tiket Resmi'),
        'Gate A',
        'ACTIVE',
        v_qty,
        0,
        NOW()
      );
    EXCEPTION WHEN OTHERS THEN
      -- Jika struktur kolom tickets berbeda, client tetap melakukan upsert lengkap via _syncTicketToSupabase
      NULL;
    END;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'booking_code', v_booking_code,
    'quantity', v_qty
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.reserve_ticket_stock(TEXT, INT, TEXT, UUID) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.release_ticket_reservation(TEXT, TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.release_expired_orders() TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.confirm_ticket_payment(TEXT) TO anon, authenticated, service_role;

-- 8. AKTIFKAN SUPABASE REALTIME
DO $$
BEGIN
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.ticket_tiers;
  EXCEPTION WHEN OTHERS THEN NULL; END;

  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.orders;
  EXCEPTION WHEN OTHERS THEN NULL; END;

  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.concerts;
  EXCEPTION WHEN OTHERS THEN NULL; END;

  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.cs_messages;
  EXCEPTION WHEN OTHERS THEN NULL; END;

  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.concert_gate_crews;
  EXCEPTION WHEN OTHERS THEN NULL; END;

  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.concert_likes;
  EXCEPTION WHEN OTHERS THEN NULL; END;

  BEGIN
    ALTER TABLE public.ticket_tiers REPLICA IDENTITY FULL;
  EXCEPTION WHEN OTHERS THEN NULL; END;

  BEGIN
    ALTER TABLE public.orders REPLICA IDENTITY FULL;
  EXCEPTION WHEN OTHERS THEN NULL; END;

  BEGIN
    ALTER TABLE public.concerts REPLICA IDENTITY FULL;
  EXCEPTION WHEN OTHERS THEN NULL; END;

  BEGIN
    ALTER TABLE public.cs_messages REPLICA IDENTITY FULL;
  EXCEPTION WHEN OTHERS THEN NULL; END;

  BEGIN
    ALTER TABLE public.concert_gate_crews REPLICA IDENTITY FULL;
  EXCEPTION WHEN OTHERS THEN NULL; END;

  BEGIN
    ALTER TABLE public.concert_likes REPLICA IDENTITY FULL;
  EXCEPTION WHEN OTHERS THEN NULL; END;
END $$;

NOTIFY pgrst, 'reload schema';
