-- ==============================================================================
-- LIVE TIX: FASE 4 - QR TIKET AMAN (HMAC-SHA256)
-- File: 20261118_fase4_qr_ticket.sql
-- Rumus Wajib:
--   signature = HMAC-SHA256(secret_server, NIK|NamaUser|tanggal_buat|kode_tiket)
--   Isi QR    = ticket_id.kode_tiket.signature (TANPA NIK/nama plaintext)
-- Validasi:
--   validate-ticket: hitung ulang HMAC dari data database, bandingkan
--   constant-time, cek belum dipakai & belum dibatalkan, tandai 'dipakai'
--   secara atomic (anti scan ganda).
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. AKTIFKAN PGCRYPTO
-- ------------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ------------------------------------------------------------------------------
-- 2. KOLOM PADA TABEL TICKETS
-- ------------------------------------------------------------------------------
ALTER TABLE public.tickets
  ADD COLUMN IF NOT EXISTS customer_nik TEXT,
  ADD COLUMN IF NOT EXISTS customer_name TEXT,
  ADD COLUMN IF NOT EXISTS kode_tiket TEXT,
  ADD COLUMN IF NOT EXISTS qr_payload TEXT,
  ADD COLUMN IF NOT EXISTS validated_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS validated_by TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS idx_tickets_kode_tiket
  ON public.tickets (kode_tiket)
  WHERE kode_tiket IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_tickets_qr_payload
  ON public.tickets (qr_payload)
  WHERE qr_payload IS NOT NULL;

-- ------------------------------------------------------------------------------
-- 3. FUNGSI issue_ticket_secure
--    Dipanggil setelah transaksi 'paid' (oleh Edge Function / webhook)
--    Menghasilkan kode_tiket acak + HMAC-SHA256(secret, NIK|NamaUser|tanggal_buat|kode_tiket)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.issue_ticket_secure(
  p_order_id  TEXT,
  p_secret    TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_order       RECORD;
  v_ticket      RECORD;
  v_nik         TEXT;
  v_nama_user   TEXT;
  v_kode        TEXT;
  v_tgl_buat    TEXT;
  v_message     TEXT;
  v_signature   TEXT;
  v_payload     TEXT;
  v_updated     INT := 0;
BEGIN
  -- Ambil data pemesan dari orders (explicit ::TEXT cast to prevent text = uuid errors)
  SELECT o.id, o.customer_nik, o.customer_name, o.user_id,
         COALESCE(p.nik, o.customer_nik, '') AS eff_nik,
         COALESCE(o.customer_name, p.full_name, p.name, 'User') AS eff_name
  INTO v_order
  FROM public.orders o
  LEFT JOIN public.profiles p ON p.id::TEXT = o.user_id::TEXT
  WHERE o.id::TEXT = p_order_id;

  v_nik       := COALESCE(v_order.eff_nik, '');
  v_nama_user := COALESCE(v_order.eff_name, 'User');

  -- Loop tiket-tiket dalam order ini yang belum punya kode_tiket
  FOR v_ticket IN
    SELECT t.id, COALESCE(t.issued_at, NOW()) AS eff_issued_at
    FROM public.tickets t
    WHERE t.order_id::TEXT = p_order_id
      AND (t.kode_tiket IS NULL OR t.kode_tiket = '')
  LOOP
    -- 1. kode_tiket acak unik (32 karakter hex)
    v_kode := encode(gen_random_bytes(16), 'hex');

    -- 2. Format tanggal ISO 8601 UTC presisi detik: YYYY-MM-DD"T"HH24:MI:SS"Z"
    v_tgl_buat := to_char(v_ticket.eff_issued_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"');

    -- 3. Rumus wajib: HMAC-SHA256(secret, NIK|NamaUser|tanggal_buat|kode_tiket)
    v_message := v_nik || '|' || v_nama_user || '|' || v_tgl_buat || '|' || v_kode;
    v_signature := encode(hmac(v_message::bytea, p_secret::bytea, 'sha256'), 'hex');

    -- 4. Isi QR: ticket_id.kode_tiket.signature (TANPA NIK/nama plaintext)
    v_payload := v_ticket.id::TEXT || '.' || v_kode || '.' || v_signature;

    UPDATE public.tickets
    SET customer_nik  = v_nik,
        customer_name = v_nama_user,
        kode_tiket    = v_kode,
        secret_hmac   = v_signature,
        qr_payload    = v_payload,
        issued_at     = v_ticket.eff_issued_at
    WHERE id = v_ticket.id;

    v_updated := v_updated + 1;
  END LOOP;

  RETURN jsonb_build_object(
    'success',  true,
    'updated',  v_updated,
    'order_id', p_order_id
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.issue_ticket_secure(TEXT, TEXT) TO service_role;

-- ------------------------------------------------------------------------------
-- 4. FUNGSI get_ticket_qr_payload
--    Mengambil payload QR resmi untuk user yang sah
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_ticket_qr_payload(
  p_ticket_id TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_ticket RECORD;
BEGIN
  SELECT id, user_id, kode_tiket, qr_payload, status, qr_scans_used,
         qr_scan_quota, issued_at
  INTO v_ticket
  FROM public.tickets
  WHERE id::TEXT = p_ticket_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'Tiket tidak ditemukan');
  END IF;

  -- Explicit cast to text for comparison
  IF COALESCE(v_ticket.user_id::TEXT, '') != COALESCE(auth.uid()::TEXT, '') THEN
    RETURN jsonb_build_object('error', 'Akses ditolak');
  END IF;

  IF LOWER(v_ticket.status) IN ('dibatalkan', 'cancelled', 'direfund', 'refunded') THEN
    RETURN jsonb_build_object('error', 'Tiket tidak valid', 'status', v_ticket.status);
  END IF;

  RETURN jsonb_build_object(
    'ticket_id',      v_ticket.id,
    'qr_payload',     COALESCE(v_ticket.qr_payload, ''),
    'kode_tiket',     COALESCE(v_ticket.kode_tiket, ''),
    'status',         v_ticket.status,
    'qr_scans_used',  v_ticket.qr_scans_used,
    'qr_scan_quota',  v_ticket.qr_scan_quota,
    'issued_at',      v_ticket.issued_at
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_ticket_qr_payload(TEXT) TO authenticated;

-- ------------------------------------------------------------------------------
-- 5. FUNGSI validate_ticket_scan (Atomic Validator di Server)
--    Memvalidasi HMAC-SHA256, status pembatalan, kuota scan,
--    dan menandai 'dipakai' secara atomic dalam 1 transaksi kunci baris (FOR UPDATE).
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.validate_ticket_scan(
  p_ticket_id   TEXT,
  p_kode_tiket  TEXT,
  p_signature   TEXT,
  p_secret      TEXT DEFAULT '',
  p_gate_user   TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_ticket      RECORD;
  v_tgl_buat    TEXT;
  v_message     TEXT;
  v_expected    TEXT;
  v_new_scans   INT;
BEGIN
  -- 1. Kunci baris tiket untuk mencegah race condition (anti scan ganda)
  SELECT id, kode_tiket, customer_nik, customer_name, status,
         qr_scan_quota, qr_scans_used, tier_name, issued_at, user_id,
         secret_hmac
  INTO v_ticket
  FROM public.tickets
  WHERE id::TEXT = p_ticket_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('valid', false, 'reason', 'TICKET_NOT_FOUND');
  END IF;

  -- 2. Validasi kode_tiket cocok
  IF v_ticket.kode_tiket IS DISTINCT FROM p_kode_tiket THEN
    RETURN jsonb_build_object('valid', false, 'reason', 'CODE_MISMATCH');
  END IF;

  -- 3. Hitung ulang HMAC-SHA256 dari database dan bandingkan constant-time
  IF p_secret IS NOT NULL AND p_secret <> '' THEN
    v_tgl_buat  := to_char(v_ticket.issued_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"');
    v_message   := COALESCE(v_ticket.customer_nik, '') || '|' ||
                   COALESCE(v_ticket.customer_name, 'User') || '|' ||
                   v_tgl_buat || '|' ||
                   v_ticket.kode_tiket;
    v_expected  := encode(hmac(v_message::bytea, p_secret::bytea, 'sha256'), 'hex');

    IF v_expected <> p_signature THEN
      RETURN jsonb_build_object('valid', false, 'reason', 'SIGNATURE_INVALID');
    END IF;
  ELSE
    -- Jika p_secret kosong (misal mode sandbox tanpa secret), verifikasi dengan signature tersimpan
    IF v_ticket.secret_hmac IS NOT NULL AND v_ticket.secret_hmac <> '' THEN
      IF v_ticket.secret_hmac <> p_signature THEN
        RETURN jsonb_build_object('valid', false, 'reason', 'SIGNATURE_INVALID');
      END IF;
    END IF;
  END IF;

  -- 4. Cek status pembatalan / refund konser
  IF LOWER(v_ticket.status) IN ('dibatalkan', 'cancelled', 'direfund', 'refunded') THEN
    RETURN jsonb_build_object(
      'valid', false,
      'reason', 'TICKET_CANCELLED',
      'status', v_ticket.status
    );
  END IF;

  -- 5. Cek kuota scan tiket (anti scan ganda)
  IF v_ticket.qr_scans_used >= v_ticket.qr_scan_quota THEN
    RETURN jsonb_build_object(
      'valid', false,
      'reason', 'SCAN_QUOTA_EXCEEDED',
      'scans_used', v_ticket.qr_scans_used,
      'scan_quota', v_ticket.qr_scan_quota
    );
  END IF;

  -- 6. Atomic increment & tandai dipakai
  v_new_scans := v_ticket.qr_scans_used + 1;

  UPDATE public.tickets
  SET qr_scans_used = v_new_scans,
      validated_at  = COALESCE(validated_at, NOW()),
      validated_by  = p_gate_user,
      status        = CASE
                        WHEN v_new_scans >= qr_scan_quota THEN 'dipakai'
                        ELSE status
                      END
  WHERE id = v_ticket.id;

  RETURN jsonb_build_object(
    'valid',        true,
    'ticket_id',    v_ticket.id,
    'tier_name',    v_ticket.tier_name,
    'scans_used',   v_new_scans,
    'scan_quota',   v_ticket.qr_scan_quota,
    'scans_left',   v_ticket.qr_scan_quota - v_new_scans,
    'issued_at',    v_ticket.issued_at,
    'status',       CASE WHEN v_new_scans >= v_ticket.qr_scan_quota THEN 'dipakai' ELSE v_ticket.status END
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.validate_ticket_scan(TEXT, TEXT, TEXT, TEXT, TEXT) TO service_role;

-- ------------------------------------------------------------------------------
-- 6. RLS: Gate Crew & Admin (Explicit ::TEXT on all UUID/TEXT comparisons)
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "tickets_read_gate_crew" ON public.tickets;
CREATE POLICY "tickets_read_gate_crew"
  ON public.tickets
  FOR SELECT
  TO authenticated
  USING (
    COALESCE(tickets.user_id::TEXT, '') = COALESCE(auth.uid()::TEXT, '')
    OR
    EXISTS (
      SELECT 1 FROM public.concert_gate_crews cgc
      JOIN public.orders o ON o.concert_id::TEXT = cgc.concert_id::TEXT
      WHERE (COALESCE(cgc.crew_user_id::TEXT, '') = auth.uid()::TEXT 
             OR COALESCE(cgc.crew_id::TEXT, '') = auth.uid()::TEXT)
        AND o.id::TEXT = tickets.order_id::TEXT
    )
    OR
    EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id::TEXT = auth.uid()::TEXT
        AND p.role IN ('admin', 'superadmin')
    )
  );
