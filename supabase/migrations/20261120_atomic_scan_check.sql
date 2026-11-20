-- ==============================================================================
-- MIGRATION: 20261120_atomic_scan_check.sql
-- Pengaman Validasi Scan Gate Crew & Status Tiket
-- ==============================================================================

-- 0. Perbaiki dan longgarkan check constraint status tiket agar tidak terjadi error 23514
ALTER TABLE public.tickets DROP CONSTRAINT IF EXISTS tickets_status_check;
ALTER TABLE public.tickets DROP CONSTRAINT IF EXISTS chk_ticket_status;
ALTER TABLE public.tickets ADD CONSTRAINT chk_ticket_status
  CHECK (LOWER(status) IN (
    'aktif', 'active', 'paid', 'dipakai', 'sudah dipakai', 'used',
    'dibatalkan', 'cancelled', 'canceled', 'direfund', 'refunded', 'hangus', 'pending'
  ));

-- 1. Pastikan kolom-kolom scan pada tabel tickets tersedia
ALTER TABLE public.tickets
  ADD COLUMN IF NOT EXISTS qr_scan_quota INT DEFAULT 1,
  ADD COLUMN IF NOT EXISTS qr_scans_used INT DEFAULT 0,
  ADD COLUMN IF NOT EXISTS scans_used INT DEFAULT 0,
  ADD COLUMN IF NOT EXISTS customer_email TEXT,
  ADD COLUMN IF NOT EXISTS customer_nik TEXT,
  ADD COLUMN IF NOT EXISTS customer_name TEXT,
  ADD COLUMN IF NOT EXISTS used_at TIMESTAMPTZ;

-- 2. Index untuk lookup cepat saat scan barcode/QR code di Gate Crew
CREATE INDEX IF NOT EXISTS idx_tickets_ticket_code ON public.tickets(ticket_code);
CREATE INDEX IF NOT EXISTS idx_tickets_booking_code ON public.tickets(booking_code);
CREATE INDEX IF NOT EXISTS idx_tickets_status_lower ON public.tickets(LOWER(status));

-- 3. Fungsi Atomic Check-in Tiket (RPC) untuk mencegah race condition / scan ganda
CREATE OR REPLACE FUNCTION public.execute_atomic_ticket_scan(
  p_ticket_id   TEXT,
  p_ticket_code TEXT,
  p_count_use   INT DEFAULT 1,
  p_gate_name   TEXT DEFAULT 'Gate A',
  p_crew_email  TEXT DEFAULT ''
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_ticket RECORD;
  v_new_used INT;
  v_is_fully_used BOOLEAN;
  v_status TEXT;
BEGIN
  -- 1. Kunci baris tiket dengan FOR UPDATE agar thread lain menunggu
  SELECT id, ticket_code, booking_code, status, qr_scan_quota, qr_scans_used
  INTO v_ticket
  FROM public.tickets
  WHERE id::TEXT = p_ticket_id 
     OR ticket_code = p_ticket_code 
     OR booking_code = p_ticket_code
  LIMIT 1
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'reason', 'TICKET_NOT_FOUND');
  END IF;

  -- 2. Cek status pembatalan / refund
  IF LOWER(v_ticket.status) IN ('dibatalkan', 'cancelled', 'direfund', 'refunded', 'hangus') THEN
    RETURN jsonb_build_object('success', false, 'reason', 'TICKET_INVALID_STATUS', 'status', v_ticket.status);
  END IF;

  -- 3. Cek sisa kuota scan
  IF v_ticket.qr_scans_used >= v_ticket.qr_scan_quota THEN
    RETURN jsonb_build_object(
      'success', false, 
      'reason', 'SCAN_QUOTA_EXCEEDED',
      'used', v_ticket.qr_scans_used,
      'quota', v_ticket.qr_scan_quota
    );
  END IF;

  -- 4. Kalkulasi penggunaan baru
  v_new_used := v_ticket.qr_scans_used + p_count_use;
  v_is_fully_used := (v_new_used >= v_ticket.qr_scan_quota);
  v_status := CASE WHEN v_is_fully_used THEN 'dipakai' ELSE 'aktif' END;

  -- 5. Update data tiket
  UPDATE public.tickets
  SET qr_scans_used = v_new_used,
      scans_used = v_new_used,
      status = v_status,
      used_at = CASE WHEN v_is_fully_used THEN NOW() ELSE used_at END
  WHERE id = v_ticket.id;

  RETURN jsonb_build_object(
    'success', true,
    'used', v_new_used,
    'quota', v_ticket.qr_scan_quota,
    'is_fully_used', v_is_fully_used,
    'status', v_status
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.execute_atomic_ticket_scan(TEXT, TEXT, INT, TEXT, TEXT) TO authenticated, service_role, anon;
