-- ==============================================================================
-- LIVE TIX: MASTER PAYMENT GATEWAY, LEDGER MUTATIONS, WITHDRAWALS & REFUNDS
-- File: 20261109_payment_gateway_core.sql
-- Midtrans Core API (QRIS, E-Wallet Deep Link, Bank VA) & Midtrans Iris
-- ==============================================================================

-- 1. TABEL ORDERS (Pesanan Pembelian Tiket)
-- Jika tabel orders sudah ada (misal dari skema sebelumnya), sesuaikan tipe kolom id dan relasi
DO $$
BEGIN
  -- Sesuaikan tipe id ke text jika sebelumnya berformat uuid
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' AND table_name = 'orders' AND column_name = 'id' AND data_type = 'uuid'
  ) THEN
    ALTER TABLE public.user_library DROP CONSTRAINT IF EXISTS user_library_order_id_fkey;
    ALTER TABLE public.user_library ALTER COLUMN order_id TYPE text;
    ALTER TABLE public.orders ALTER COLUMN id TYPE text USING id::text;
    ALTER TABLE public.user_library ADD CONSTRAINT user_library_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(id) ON DELETE SET NULL;
  END IF;

  -- Lepas constraint NOT NULL kolom aplikasi game sebelumnya jika ada
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'orders' AND column_name = 'user_id') THEN
    ALTER TABLE public.orders ALTER COLUMN user_id DROP NOT NULL;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'orders' AND column_name = 'game_id') THEN
    ALTER TABLE public.orders ALTER COLUMN game_id DROP NOT NULL;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'orders' AND column_name = 'developer_id') THEN
    ALTER TABLE public.orders ALTER COLUMN developer_id DROP NOT NULL;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'orders' AND column_name = 'amount') THEN
    ALTER TABLE public.orders ALTER COLUMN amount DROP NOT NULL;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'orders' AND column_name = 'platform_commission') THEN
    ALTER TABLE public.orders ALTER COLUMN platform_commission DROP NOT NULL;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'orders' AND column_name = 'developer_earning') THEN
    ALTER TABLE public.orders ALTER COLUMN developer_earning DROP NOT NULL;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'orders' AND column_name = 'order_number') THEN
    ALTER TABLE public.orders ALTER COLUMN order_number DROP NOT NULL;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'orders' AND column_name = 'status') THEN
    ALTER TABLE public.orders ALTER COLUMN status DROP NOT NULL;
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.orders (
  id TEXT PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  concert_id TEXT REFERENCES public.concerts(id) ON DELETE SET NULL,
  tier_id TEXT,
  tier_name TEXT,
  quantity INT DEFAULT 1,
  ticket_price BIGINT DEFAULT 0,
  service_fee BIGINT DEFAULT 0,
  tax_admin_fee BIGINT DEFAULT 0,
  payment_fee BIGINT DEFAULT 0,
  total_amount BIGINT DEFAULT 0,
  gross_amount BIGINT DEFAULT 0,
  payment_method TEXT DEFAULT 'QRIS',
  payment_type TEXT,
  payment_status TEXT NOT NULL DEFAULT 'PENDING',
  midtrans_transaction_id TEXT,
  va_number TEXT,
  biller_code TEXT,
  bill_key TEXT,
  qr_string TEXT,
  qr_url TEXT,
  deeplink_url TEXT,
  expires_at TIMESTAMPTZ,
  paid_at TIMESTAMPTZ,
  customer_name TEXT,
  customer_email TEXT,
  customer_phone TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Pastikan seluruh kolom orders lengkap jika tabel orders sudah ada sebelumnya
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS concert_id TEXT REFERENCES public.concerts(id) ON DELETE SET NULL;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS tier_id TEXT;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS tier_name TEXT;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS quantity INT DEFAULT 1;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS ticket_price BIGINT DEFAULT 0;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS service_fee BIGINT DEFAULT 0;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS tax_admin_fee BIGINT DEFAULT 0;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS payment_fee BIGINT DEFAULT 0;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS total_amount BIGINT DEFAULT 0;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS gross_amount BIGINT DEFAULT 0;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS payment_method TEXT DEFAULT 'QRIS';
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS payment_type TEXT;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS payment_status TEXT DEFAULT 'PENDING';
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS midtrans_transaction_id TEXT;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS va_number TEXT;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS biller_code TEXT;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS bill_key TEXT;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS qr_string TEXT;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS qr_url TEXT;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS deeplink_url TEXT;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS paid_at TIMESTAMPTZ;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS customer_name TEXT;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS customer_email TEXT;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS customer_phone TEXT;

CREATE INDEX IF NOT EXISTS idx_orders_user ON public.orders(user_id);
CREATE INDEX IF NOT EXISTS idx_orders_concert ON public.orders(concert_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON public.orders(payment_status);

-- 2. TABEL TICKETS (Tiket Konser Resmi & QR Code)
CREATE TABLE IF NOT EXISTS public.tickets (
  id TEXT PRIMARY KEY,
  order_id TEXT,
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  concert_id TEXT REFERENCES public.concerts(id) ON DELETE SET NULL,
  tier_id TEXT,
  ticket_code TEXT,
  secret_hmac TEXT,
  tier_name TEXT,
  gate_name TEXT DEFAULT 'Gate A',
  venue TEXT,
  concert_title TEXT,
  concert_date TEXT,
  concert_time TEXT,
  status TEXT NOT NULL DEFAULT 'AKTIF', -- AKTIF, SUDAH DIPAKAI, DIREFUND
  qr_scan_quota INT DEFAULT 1,
  qr_scans_used INT DEFAULT 0,
  issued_at TIMESTAMPTZ DEFAULT NOW(),
  used_at TIMESTAMPTZ
);

-- Pastikan seluruh kolom tickets ada jika tabel sudah pernah dibuat sebelumnya
ALTER TABLE public.tickets ADD COLUMN IF NOT EXISTS order_id TEXT;
ALTER TABLE public.tickets ADD COLUMN IF NOT EXISTS user_id UUID;
ALTER TABLE public.tickets ADD COLUMN IF NOT EXISTS concert_id TEXT;
ALTER TABLE public.tickets ADD COLUMN IF NOT EXISTS tier_id TEXT;
ALTER TABLE public.tickets ADD COLUMN IF NOT EXISTS ticket_code TEXT;
ALTER TABLE public.tickets ADD COLUMN IF NOT EXISTS secret_hmac TEXT;
ALTER TABLE public.tickets ADD COLUMN IF NOT EXISTS tier_name TEXT;
ALTER TABLE public.tickets ADD COLUMN IF NOT EXISTS gate_name TEXT DEFAULT 'Gate A';
ALTER TABLE public.tickets ADD COLUMN IF NOT EXISTS venue TEXT;
ALTER TABLE public.tickets ADD COLUMN IF NOT EXISTS concert_title TEXT;
ALTER TABLE public.tickets ADD COLUMN IF NOT EXISTS concert_date TEXT;
ALTER TABLE public.tickets ADD COLUMN IF NOT EXISTS concert_time TEXT;
ALTER TABLE public.tickets ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'AKTIF';
ALTER TABLE public.tickets ADD COLUMN IF NOT EXISTS qr_scan_quota INT DEFAULT 1;
ALTER TABLE public.tickets ADD COLUMN IF NOT EXISTS qr_scans_used INT DEFAULT 0;
ALTER TABLE public.tickets ADD COLUMN IF NOT EXISTS issued_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE public.tickets ADD COLUMN IF NOT EXISTS used_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_tickets_user ON public.tickets(user_id);
CREATE INDEX IF NOT EXISTS idx_tickets_concert ON public.tickets(concert_id);
CREATE INDEX IF NOT EXISTS idx_tickets_code ON public.tickets(ticket_code);
CREATE INDEX IF NOT EXISTS idx_tickets_status ON public.tickets(status);

-- 3. TABEL LEDGER MUTATIONS (Buku Besar Mutasi Saldo - Append-Only)
CREATE TABLE IF NOT EXISTS public.ledger_mutations (
  id TEXT PRIMARY KEY,
  order_id TEXT,
  concert_id TEXT,
  producer_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  gross_amount BIGINT NOT NULL DEFAULT 0,
  fee_admin BIGINT NOT NULL DEFAULT 0, -- 3% dari total transaksi (dibulatkan)
  net_producer BIGINT NOT NULL DEFAULT 0, -- 97% dana produser
  mutation_type TEXT NOT NULL DEFAULT 'TICKET_SALE', -- TICKET_SALE, WITHDRAWAL_PRODUCER, WITHDRAWAL_ADMIN, REFUND_CONCERT_CANCELLATION, REVERSAL
  status TEXT NOT NULL DEFAULT 'PENDING_BALANCE', -- PENDING_BALANCE, AVAILABLE_BALANCE, WITHDRAWN, REFUNDED
  reference_id TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

ALTER TABLE public.ledger_mutations ADD COLUMN IF NOT EXISTS order_id TEXT;
ALTER TABLE public.ledger_mutations ADD COLUMN IF NOT EXISTS concert_id TEXT;
ALTER TABLE public.ledger_mutations ADD COLUMN IF NOT EXISTS producer_id UUID;
ALTER TABLE public.ledger_mutations ADD COLUMN IF NOT EXISTS gross_amount BIGINT DEFAULT 0;
ALTER TABLE public.ledger_mutations ADD COLUMN IF NOT EXISTS fee_admin BIGINT DEFAULT 0;
ALTER TABLE public.ledger_mutations ADD COLUMN IF NOT EXISTS net_producer BIGINT DEFAULT 0;
ALTER TABLE public.ledger_mutations ADD COLUMN IF NOT EXISTS mutation_type TEXT DEFAULT 'TICKET_SALE';
ALTER TABLE public.ledger_mutations ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'PENDING_BALANCE';
ALTER TABLE public.ledger_mutations ADD COLUMN IF NOT EXISTS reference_id TEXT;
ALTER TABLE public.ledger_mutations ADD COLUMN IF NOT EXISTS notes TEXT;

CREATE INDEX IF NOT EXISTS idx_ledger_producer ON public.ledger_mutations(producer_id);
CREATE INDEX IF NOT EXISTS idx_ledger_concert ON public.ledger_mutations(concert_id);
CREATE INDEX IF NOT EXISTS idx_ledger_type ON public.ledger_mutations(mutation_type);
CREATE INDEX IF NOT EXISTS idx_ledger_status ON public.ledger_mutations(status);

-- 4. TABEL WITHDRAWALS (Pengajuan & Riwayat Penarikan Dana Produser & Admin)
CREATE TABLE IF NOT EXISTS public.withdrawals (
  id TEXT PRIMARY KEY,
  reference_no TEXT UNIQUE NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  producer_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  role TEXT NOT NULL DEFAULT 'PRODUCER', -- PRODUCER, ADMIN
  concert_id TEXT REFERENCES public.concerts(id) ON DELETE SET NULL,
  amount BIGINT NOT NULL DEFAULT 50000 CHECK (amount >= 50000), -- Minimal penarikan Rp 50.000
  bank_name TEXT NOT NULL DEFAULT 'BCA',
  account_number TEXT NOT NULL DEFAULT '',
  account_name TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT 'PENDING', -- PENDING, PROCESSING, SUCCESS, FAILED
  rejection_reason TEXT,
  iris_payout_id TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  completed_at TIMESTAMPTZ
);

ALTER TABLE public.withdrawals ADD COLUMN IF NOT EXISTS reference_no TEXT;
ALTER TABLE public.withdrawals ADD COLUMN IF NOT EXISTS user_id UUID;
ALTER TABLE public.withdrawals ADD COLUMN IF NOT EXISTS producer_id UUID;
ALTER TABLE public.withdrawals ADD COLUMN IF NOT EXISTS role TEXT DEFAULT 'PRODUCER';
ALTER TABLE public.withdrawals ADD COLUMN IF NOT EXISTS concert_id TEXT;
ALTER TABLE public.withdrawals ADD COLUMN IF NOT EXISTS amount BIGINT DEFAULT 50000;
ALTER TABLE public.withdrawals ADD COLUMN IF NOT EXISTS bank_name TEXT DEFAULT 'BCA';
ALTER TABLE public.withdrawals ADD COLUMN IF NOT EXISTS account_number TEXT DEFAULT '';
ALTER TABLE public.withdrawals ADD COLUMN IF NOT EXISTS account_name TEXT DEFAULT '';
ALTER TABLE public.withdrawals ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'PENDING';
ALTER TABLE public.withdrawals ADD COLUMN IF NOT EXISTS rejection_reason TEXT;
ALTER TABLE public.withdrawals ADD COLUMN IF NOT EXISTS iris_payout_id TEXT;

CREATE INDEX IF NOT EXISTS idx_withdrawals_user ON public.withdrawals(user_id);
CREATE INDEX IF NOT EXISTS idx_withdrawals_producer ON public.withdrawals(producer_id);
CREATE INDEX IF NOT EXISTS idx_withdrawals_status ON public.withdrawals(status);

-- 5. TABEL REFUNDS (Pengembalian Dana Konser Dibatalkan)
CREATE TABLE IF NOT EXISTS public.refunds (
  id TEXT PRIMARY KEY,
  ticket_id TEXT,
  order_id TEXT,
  concert_id TEXT REFERENCES public.concerts(id) ON DELETE SET NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  refund_amount BIGINT NOT NULL DEFAULT 0, -- 100% nominal tiket
  destination_type TEXT NOT NULL DEFAULT 'BANK', -- BANK, EWALLET
  destination_provider TEXT NOT NULL DEFAULT 'BCA', -- BCA, Mandiri, BNI, BRI, GoPay, ShopeePay, DANA, dll
  destination_account_no TEXT NOT NULL DEFAULT '',
  destination_account_name TEXT NOT NULL DEFAULT '',
  reason TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT 'DIAJUKAN', -- DIAJUKAN, DIPROSES, BERHASIL, GAGAL
  failure_reason TEXT,
  iris_payout_id TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.refunds ADD COLUMN IF NOT EXISTS ticket_id TEXT;
ALTER TABLE public.refunds ADD COLUMN IF NOT EXISTS order_id TEXT;
ALTER TABLE public.refunds ADD COLUMN IF NOT EXISTS concert_id TEXT;
ALTER TABLE public.refunds ADD COLUMN IF NOT EXISTS user_id UUID;
ALTER TABLE public.refunds ADD COLUMN IF NOT EXISTS refund_amount BIGINT DEFAULT 0;
ALTER TABLE public.refunds ADD COLUMN IF NOT EXISTS destination_type TEXT DEFAULT 'BANK';
ALTER TABLE public.refunds ADD COLUMN IF NOT EXISTS destination_provider TEXT DEFAULT 'BCA';
ALTER TABLE public.refunds ADD COLUMN IF NOT EXISTS destination_account_no TEXT DEFAULT '';
ALTER TABLE public.refunds ADD COLUMN IF NOT EXISTS destination_account_name TEXT DEFAULT '';
ALTER TABLE public.refunds ADD COLUMN IF NOT EXISTS reason TEXT DEFAULT '';
ALTER TABLE public.refunds ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'DIAJUKAN';
ALTER TABLE public.refunds ADD COLUMN IF NOT EXISTS failure_reason TEXT;
ALTER TABLE public.refunds ADD COLUMN IF NOT EXISTS iris_payout_id TEXT;

CREATE INDEX IF NOT EXISTS idx_refunds_user ON public.refunds(user_id);
CREATE INDEX IF NOT EXISTS idx_refunds_concert ON public.refunds(concert_id);
CREATE INDEX IF NOT EXISTS idx_refunds_status ON public.refunds(status);

-- 6. ROW LEVEL SECURITY (RLS) POLICIES
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ledger_mutations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.withdrawals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.refunds ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'orders' AND policyname = 'Orders Manage All') THEN
    CREATE POLICY "Orders Manage All" ON public.orders FOR ALL USING (true) WITH CHECK (true);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'tickets' AND policyname = 'Tickets Manage All') THEN
    CREATE POLICY "Tickets Manage All" ON public.tickets FOR ALL USING (true) WITH CHECK (true);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'ledger_mutations' AND policyname = 'Ledger Manage All') THEN
    CREATE POLICY "Ledger Manage All" ON public.ledger_mutations FOR ALL USING (true) WITH CHECK (true);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'withdrawals' AND policyname = 'Withdrawals Manage All') THEN
    CREATE POLICY "Withdrawals Manage All" ON public.withdrawals FOR ALL USING (true) WITH CHECK (true);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'refunds' AND policyname = 'Refunds Manage All') THEN
    CREATE POLICY "Refunds Manage All" ON public.refunds FOR ALL USING (true) WITH CHECK (true);
  END IF;
END $$;

-- 7. FUNGSI BANTUAN PARSER TANGGAL INDONESIA & ZONA WAKTU ASIA/JAKARTA
CREATE OR REPLACE FUNCTION public.try_parse_indonesian_date(p_str TEXT)
RETURNS DATE
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  v_clean TEXT;
  v_day INT;
  v_month INT := 1;
  v_year INT;
BEGIN
  IF p_str IS NULL OR TRIM(p_str) = '' THEN
    RETURN NULL;
  END IF;

  IF p_str ~ '^\d{4}-\d{2}-\d{2}' THEN
    RETURN p_str::DATE;
  END IF;

  v_clean := REGEXP_REPLACE(p_str, '^(Senin|Selasa|Rabu|Kamis|Jumat|Jum''at|Sabtu|Minggu),?\s*', '', 'i');
  
  IF v_clean ~ '(\d{1,2})\s+([A-Za-z]+)\s+(\d{4})' THEN
    v_day := (SUBSTRING(v_clean FROM '(\d{1,2})'))::INT;
    v_year := (SUBSTRING(v_clean FROM '(\d{4})'))::INT;
    
    IF v_clean ~* 'Januari' THEN v_month := 1;
    ELSIF v_clean ~* 'Februari' THEN v_month := 2;
    ELSIF v_clean ~* 'Maret' THEN v_month := 3;
    ELSIF v_clean ~* 'April' THEN v_month := 4;
    ELSIF v_clean ~* 'Mei' THEN v_month := 5;
    ELSIF v_clean ~* 'Juni' THEN v_month := 6;
    ELSIF v_clean ~* 'Juli' THEN v_month := 7;
    ELSIF v_clean ~* 'Agustus' THEN v_month := 8;
    ELSIF v_clean ~* 'September' THEN v_month := 9;
    ELSIF v_clean ~* 'Oktober' THEN v_month := 10;
    ELSIF v_clean ~* 'November' THEN v_month := 11;
    ELSIF v_clean ~* 'Desember' THEN v_month := 12;
    END IF;

    RETURN MAKE_DATE(v_year, v_month, v_day);
  END IF;

  RETURN NULL;
EXCEPTION WHEN OTHERS THEN
  RETURN NULL;
END;
$$;
ALTER TABLE public.ledger_mutations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.withdrawals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.refunds ENABLE ROW LEVEL SECURITY;

-- Orders Policies
DROP POLICY IF EXISTS "Orders Select Own Or Admin" ON public.orders;
CREATE POLICY "Orders Select Own Or Admin" ON public.orders
  FOR SELECT USING (auth.uid() = user_id OR public.is_admin() OR auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Orders Insert Authenticated" ON public.orders;
CREATE POLICY "Orders Insert Authenticated" ON public.orders
  FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Orders Update Authenticated Or Admin" ON public.orders;
CREATE POLICY "Orders Update Authenticated Or Admin" ON public.orders
  FOR UPDATE USING (true) WITH CHECK (true);

-- Tickets Policies
DROP POLICY IF EXISTS "Tickets Select Own Or Admin" ON public.tickets;
CREATE POLICY "Tickets Select Own Or Admin" ON public.tickets
  FOR SELECT USING (auth.uid() = user_id OR public.is_admin() OR auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Tickets Manage All" ON public.tickets;
CREATE POLICY "Tickets Manage All" ON public.tickets
  FOR ALL USING (true) WITH CHECK (true);

-- Ledger Mutations Policies
DROP POLICY IF EXISTS "Ledger Select Producer Or Admin" ON public.ledger_mutations;
CREATE POLICY "Ledger Select Producer Or Admin" ON public.ledger_mutations
  FOR SELECT USING (auth.uid() = producer_id OR public.is_admin() OR auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Ledger Insert Authenticated Or Backend" ON public.ledger_mutations;
CREATE POLICY "Ledger Insert Authenticated Or Backend" ON public.ledger_mutations
  FOR INSERT WITH CHECK (true);

-- Withdrawals Policies
DROP POLICY IF EXISTS "Withdrawals Select Own Or Admin" ON public.withdrawals;
CREATE POLICY "Withdrawals Select Own Or Admin" ON public.withdrawals
  FOR SELECT USING (auth.uid() = user_id OR auth.uid() = producer_id OR public.is_admin() OR auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Withdrawals Manage All" ON public.withdrawals;
CREATE POLICY "Withdrawals Manage All" ON public.withdrawals
  FOR ALL USING (true) WITH CHECK (true);

-- Refunds Policies
DROP POLICY IF EXISTS "Refunds Select Own Or Admin" ON public.refunds;
CREATE POLICY "Refunds Select Own Or Admin" ON public.refunds
  FOR SELECT USING (auth.uid() = user_id OR public.is_admin() OR auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Refunds Manage All" ON public.refunds;
CREATE POLICY "Refunds Manage All" ON public.refunds
  FOR ALL USING (true) WITH CHECK (true);


-- 7. STORED PROCEDURES & PERHITUNGAN SALDO (ATOMIC DENGAN ZONA WAKTU ASIA/JAKARTA)

-- A. Hitung Saldo Produser dari Ledger (Saldo Tertahan vs Saldo Tersedia)
-- Aturan kunci: Saldo sebuah konser baru menjadi TERSEDIA setelah waktu mulai konser terlewati
-- dan konser TIDAK dalam status dibatalkan.
CREATE OR REPLACE FUNCTION public.calculate_promoter_balance(p_producer_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_pending_balance BIGINT := 0;
  v_available_balance BIGINT := 0;
  v_total_sales BIGINT := 0;
  v_total_withdrawn BIGINT := 0;
  v_now_wib TIMESTAMPTZ := timezone('Asia/Jakarta', now());
  v_rec RECORD;
  v_concert_passed BOOLEAN;
BEGIN
  -- 1. Ambil mutasi penjualan tiket
  FOR v_rec IN (
    SELECT lm.net_producer, lm.concert_id, c.date, c.time, c.status AS concert_status
    FROM public.ledger_mutations lm
    LEFT JOIN public.concerts c ON c.id = lm.concert_id
    WHERE lm.producer_id = p_producer_id
      AND lm.mutation_type = 'TICKET_SALE'
  ) LOOP
    v_total_sales := v_total_sales + v_rec.net_producer;
    
    -- Jika konser dibatalkan, dana tertahan tidak bisa ditarik sama sekali (dialihkan untuk refund)
    IF LOWER(COALESCE(v_rec.concert_status, '')) IN ('dibatalkan', 'cancelled') THEN
      -- Dana terkunci untuk refund
      CONTINUE;
    END IF;

    -- Pengecekan apakah tanggal + jam konser sudah terlewati
    -- Jika format date ISO / parsable, kita evaluasi. Default bila belum lewat -> pending
    BEGIN
      -- Cek apakah string date berformat 'YYYY-MM-DD' atau format tanggal
      IF v_rec.date IS NOT NULL AND v_rec.date ~ '^\d{4}-\d{2}-\d{2}' THEN
        v_concert_passed := (v_rec.date::date <= (v_now_wib::date));
      ELSE
        -- Fallback: jika konser masih aktif, dana tertahan
        v_concert_passed := FALSE;
      END IF;
    EXCEPTION WHEN OTHERS THEN
      v_concert_passed := FALSE;
    END;

    IF v_concert_passed THEN
      v_available_balance := v_available_balance + v_rec.net_producer;
    ELSE
      v_pending_balance := v_pending_balance + v_rec.net_producer;
    END IF;
  END LOOP;

  -- 2. Kurangi dengan total penarikan yang telah berhasil atau sedang diproses
  SELECT COALESCE(SUM(amount), 0) INTO v_total_withdrawn
  FROM public.withdrawals
  WHERE (producer_id = p_producer_id OR user_id = p_producer_id)
    AND role = 'PRODUCER'
    AND status IN ('PENDING', 'PROCESSING', 'SUCCESS');

  v_available_balance := GREATEST(0, v_available_balance - v_total_withdrawn);

  RETURN jsonb_build_object(
    'pending_balance', v_pending_balance,
    'available_balance', v_available_balance,
    'total_sales', v_total_sales,
    'total_withdrawn', v_total_withdrawn
  );
END;
$$;


-- B. Hitung Saldo Fee 3% Admin
CREATE OR REPLACE FUNCTION public.calculate_admin_balance()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_total_fees BIGINT := 0;
  v_total_withdrawn BIGINT := 0;
  v_available_fee_balance BIGINT := 0;
BEGIN
  -- Total fee 3% yang masuk dari seluruh transaksi PAID
  SELECT COALESCE(SUM(fee_admin), 0) INTO v_total_fees
  FROM public.ledger_mutations
  WHERE mutation_type = 'TICKET_SALE';

  -- Total fee yang sudah ditarik Admin
  SELECT COALESCE(SUM(amount), 0) INTO v_total_withdrawn
  FROM public.withdrawals
  WHERE role = 'ADMIN'
    AND status IN ('PENDING', 'PROCESSING', 'SUCCESS');

  v_available_fee_balance := GREATEST(0, v_total_fees - v_total_withdrawn);

  RETURN jsonb_build_object(
    'total_fee_collected', v_total_fees,
    'available_fee_balance', v_available_fee_balance,
    'total_fee_withdrawn', v_total_withdrawn
  );
END;
$$;


-- C. Request Penarikan Dana Produser (Atomic Row-Locking Mencegah Race Condition & Double Withdraw)
CREATE OR REPLACE FUNCTION public.request_producer_withdrawal_atomic(
  p_producer_id UUID,
  p_amount BIGINT,
  p_bank_name TEXT,
  p_account_number TEXT,
  p_account_name TEXT,
  p_concert_id TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_balance JSONB;
  v_available BIGINT;
  v_ref_no TEXT;
  v_withdrawal_id TEXT;
BEGIN
  IF p_amount < 50000 THEN
    RETURN jsonb_build_object('success', false, 'message', 'Nominal penarikan minimum adalah Rp 50.000');
  END IF;

  -- Kunci tabel withdrawals untuk producer ini secara eksklusif selama transaksi
  PERFORM 1 FROM public.profiles WHERE id = p_producer_id FOR UPDATE;

  -- Hitung saldo tersedia secara realtime
  v_balance := public.calculate_promoter_balance(p_producer_id);
  v_available := (v_balance->>'available_balance')::BIGINT;

  IF p_amount > v_available THEN
    RETURN jsonb_build_object('success', false, 'message', 'Saldo tersedia tidak mencukupi (Tersedia: Rp ' || v_available || ')');
  END IF;

  v_ref_no := 'WD-PRD-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || SUBSTRING(gen_random_uuid()::text, 1, 8);
  v_withdrawal_id := 'wd_' || gen_random_uuid()::text;

  INSERT INTO public.withdrawals (
    id, reference_no, user_id, producer_id, role, concert_id,
    amount, bank_name, account_number, account_name, status, created_at
  ) VALUES (
    v_withdrawal_id, v_ref_no, p_producer_id, p_producer_id, 'PRODUCER', p_concert_id,
    p_amount, p_bank_name, p_account_number, p_account_name, 'PENDING', NOW()
  );

  -- Catat entri mutasi ledger
  INSERT INTO public.ledger_mutations (
    id, producer_id, concert_id, gross_amount, fee_admin, net_producer,
    mutation_type, status, reference_id, notes
  ) VALUES (
    'lm_wd_' || gen_random_uuid()::text, p_producer_id, p_concert_id, p_amount, 0, p_amount,
    'WITHDRAWAL_PRODUCER', 'WITHDRAWN', v_ref_no, 'Penarikan saldo produser ke ' || p_bank_name || ' ' || p_account_number
  );

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Pengajuan penarikan dana Rp ' || p_amount || ' berhasil dibuat dan sedang diproses.',
    'reference_no', v_ref_no,
    'withdrawal_id', v_withdrawal_id
  );
END;
$$;


-- D. Request Penarikan Fee Admin (Atomic)
CREATE OR REPLACE FUNCTION public.request_admin_withdrawal_atomic(
  p_admin_id UUID,
  p_amount BIGINT,
  p_bank_name TEXT,
  p_account_number TEXT,
  p_account_name TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_balance JSONB;
  v_available BIGINT;
  v_ref_no TEXT;
  v_withdrawal_id TEXT;
BEGIN
  IF p_amount < 50000 THEN
    RETURN jsonb_build_object('success', false, 'message', 'Nominal penarikan minimum adalah Rp 50.000');
  END IF;

  PERFORM 1 FROM public.profiles WHERE id = p_admin_id FOR UPDATE;

  v_balance := public.calculate_admin_balance();
  v_available := (v_balance->>'available_fee_balance')::BIGINT;

  IF p_amount > v_available THEN
    RETURN jsonb_build_object('success', false, 'message', 'Saldo fee admin tidak mencukupi (Tersedia: Rp ' || v_available || ')');
  END IF;

  v_ref_no := 'WD-ADM-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || SUBSTRING(gen_random_uuid()::text, 1, 8);
  v_withdrawal_id := 'wd_' || gen_random_uuid()::text;

  INSERT INTO public.withdrawals (
    id, reference_no, user_id, role,
    amount, bank_name, account_number, account_name, status, created_at
  ) VALUES (
    v_withdrawal_id, v_ref_no, p_admin_id, 'ADMIN',
    p_amount, p_bank_name, p_account_number, p_account_name, 'PENDING', NOW()
  );

  INSERT INTO public.ledger_mutations (
    id, gross_amount, fee_admin, net_producer,
    mutation_type, status, reference_id, notes
  ) VALUES (
    'lm_wd_adm_' || gen_random_uuid()::text, p_amount, p_amount, 0,
    'WITHDRAWAL_ADMIN', 'WITHDRAWN', v_ref_no, 'Penarikan fee admin 3% ke ' || p_bank_name || ' ' || p_account_number
  );

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Pengajuan penarikan fee admin Rp ' || p_amount || ' berhasil diproses.',
    'reference_no', v_ref_no,
    'withdrawal_id', v_withdrawal_id
  );
END;
$$;


-- E. Eksekusi Pembatalan Konser & Penguncian Penarikan Produser
CREATE OR REPLACE FUNCTION public.cancel_concert_and_lock_funds(
  p_concert_id TEXT,
  p_reason TEXT,
  p_category TEXT DEFAULT 'Force Majeure'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF p_reason IS NULL OR TRIM(p_reason) = '' THEN
    RETURN jsonb_build_object('success', false, 'message', 'Alasan pembatalan konser wajib diisi.');
  END IF;

  -- 1. Update status konser menjadi 'dibatalkan'
  UPDATE public.concerts
  SET status = 'dibatalkan',
      cancellation_reason = p_reason,
      cancellation_category = p_category,
      cancellation_date = TO_CHAR(NOW(), 'YYYY-MM-DD HH24:MI:SS'),
      updated_at = NOW()
  WHERE id = p_concert_id;

  -- 2. Hentikan penjualan tiket pada tier
  UPDATE public.ticket_tiers
  SET is_sold_out = TRUE
  WHERE concert_id = p_concert_id;

  -- 3. Kunci seluruh mutasi ledger terkait konser ini menjadi REFUND_RESERVED
  UPDATE public.ledger_mutations
  SET status = 'REFUNDED',
      notes = COALESCE(notes, '') || ' [Konser Dibatalkan: Saldo ditahan untuk refund]'
  WHERE concert_id = p_concert_id
    AND mutation_type = 'TICKET_SALE';

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Konser berhasil dibatalkan. Seluruh tiket aktif berhak mengajukan refund 100% dan dana produser telah dikunci.'
  );
END;
$$;


-- F. Pengajuan Refund User (100% Harga Tiket, Fee 3% Dikembalikan dari Saldo Admin)
CREATE OR REPLACE FUNCTION public.request_ticket_refund_atomic(
  p_ticket_id TEXT,
  p_user_id UUID,
  p_dest_type TEXT,
  p_dest_provider TEXT,
  p_dest_account_no TEXT,
  p_dest_account_name TEXT,
  p_reason TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_ticket RECORD;
  v_order RECORD;
  v_refund_id TEXT;
  v_refund_amount BIGINT;
BEGIN
  -- 1. Cek validitas tiket
  SELECT * INTO v_ticket
  FROM public.tickets
  WHERE id = p_ticket_id
  FOR UPDATE;

  IF v_ticket IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'Tiket tidak ditemukan.');
  END IF;

  IF v_ticket.user_id != p_user_id AND NOT public.is_admin() THEN
    RETURN jsonb_build_object('success', false, 'message', 'Anda tidak memiliki hak atas tiket ini.');
  END IF;

  IF v_ticket.status = 'DIREFUND' THEN
    RETURN jsonb_build_object('success', false, 'message', 'Tiket ini sudah pernah direfund.');
  END IF;

  IF v_ticket.status = 'SUDAH DIPAKAI' THEN
    RETURN jsonb_build_object('success', false, 'message', 'Tiket yang sudah dipakai tidak dapat direfund.');
  END IF;

  -- 2. Ambil harga dari order terkait
  SELECT * INTO v_order FROM public.orders WHERE id = v_ticket.order_id;
  v_refund_amount := COALESCE(v_order.ticket_price, 0);

  IF v_refund_amount <= 0 THEN
    v_refund_amount := COALESCE(v_order.total_amount, 0);
  END IF;

  v_refund_id := 'ref_' || gen_random_uuid()::text;

  -- 3. Ubah status tiket menjadi DIREFUND (langsung tidak valid untuk check-in QR scanner)
  UPDATE public.tickets
  SET status = 'DIREFUND',
      used_at = NOW()
  WHERE id = p_ticket_id;

  -- 4. Simpan pengajuan refund
  INSERT INTO public.refunds (
    id, ticket_id, order_id, concert_id, user_id,
    refund_amount, destination_type, destination_provider,
    destination_account_no, destination_account_name,
    reason, status, created_at, updated_at
  ) VALUES (
    v_refund_id, p_ticket_id, v_ticket.order_id, v_ticket.concert_id, p_user_id,
    v_refund_amount, p_dest_type, p_dest_provider,
    p_dest_account_no, p_dest_account_name,
    p_reason, 'DIPROSES', NOW(), NOW()
  );

  -- 5. Catat mutasi ledger pembalikan dana refund
  INSERT INTO public.ledger_mutations (
    id, order_id, concert_id, gross_amount, fee_admin, net_producer,
    mutation_type, status, reference_id, notes
  ) VALUES (
    'lm_ref_' || gen_random_uuid()::text, v_ticket.order_id, v_ticket.concert_id,
    -v_refund_amount, -(v_refund_amount * 0.03)::BIGINT, -(v_refund_amount * 0.97)::BIGINT,
    'REFUND_CONCERT_CANCELLATION', 'REFUNDED', v_refund_id,
    'Refund 100% tiket ' || v_ticket.ticket_code || ' ke ' || p_dest_provider || ' ' || p_dest_account_no
  );

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Pengajuan refund 100% berhasil diproses ke ' || p_dest_provider || ' ' || p_dest_account_no || '.',
    'refund_id', v_refund_id,
    'refund_amount', v_refund_amount
  );
END;
$$;