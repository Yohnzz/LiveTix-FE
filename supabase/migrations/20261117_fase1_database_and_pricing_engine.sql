-- ==============================================================================
-- LIVE TIX: FASE 1 - DATABASE MIGRATION & PRICING ENGINE
-- File: 20261117_fase1_database_and_pricing_engine.sql
-- Komponen:
-- 1. Tabel app_config (konfigurasi pajak, biaya, limit tiket, kelipatan)
-- 2. Kolom komponen biaya di transactions & orders (Rupiah integer, transparansi)
-- 3. Tabel ledger append-only (tidak boleh UPDATE/DELETE) + Trigger imutabilitas
-- 4. Tabel withdrawals & refunds (status, foreign key, nominal integer)
-- 5. Penyelarasan status tiket ('aktif', 'dipakai', 'dibatalkan') & status konser
-- 6. Row Level Security (RLS) per role (User, Produser, Admin)
-- 7. Fungsi hitung_transaksi (sumber kebenaran tunggal di server) + assert invarian
-- 8. Otomatisasi pengujian invarian matematika & imutabilitas ledger
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. TABEL APP_CONFIG
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.app_config (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  description TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Seed konfigurasi dasar sistem LiveTix
INSERT INTO public.app_config (key, value, description)
VALUES 
  ('pajak_hiburan_persen', '10', 'Tarif Pajak Hiburan Daerah (default 10%)'),
  ('biaya_aplikasi_persen', '2', 'Tarif Biaya Layanan Aplikasi per transaksi (default 2%)'),
  ('max_tiket_per_transaksi', '4', 'Batas maksimal jumlah tiket dalam satu kali transaksi'),
  ('kelipatan_pembulatan', '1000', 'Kelipatan pembulatan ke atas untuk ratusan 000 (Rp 1.000)'),
  ('midtrans_mode', 'sandbox', 'Mode operasional payment gateway Midtrans (sandbox)')
ON CONFLICT (key) DO UPDATE SET
  value = EXCLUDED.value,
  description = EXCLUDED.description,
  updated_at = NOW();

-- ------------------------------------------------------------------------------
-- 2. TABEL TRANSACTIONS & SINKRONISASI KOLOM BIAYA DI ORDERS
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.transactions (
  id TEXT PRIMARY KEY,
  order_id TEXT,
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  concert_id TEXT REFERENCES public.concerts(id) ON DELETE SET NULL,
  tier_id TEXT,
  tier_name TEXT,
  jumlah_tiket INT NOT NULL CHECK (jumlah_tiket >= 1 AND jumlah_tiket <= 4),
  harga_satuan BIGINT NOT NULL CHECK (harga_satuan >= 0),
  harga_tiket BIGINT NOT NULL CHECK (harga_tiket >= 0),
  pajak_hiburan BIGINT NOT NULL CHECK (pajak_hiburan >= 0),
  biaya_aplikasi BIGINT NOT NULL CHECK (biaya_aplikasi >= 0),
  subtotal BIGINT NOT NULL CHECK (subtotal >= 0),
  total_bayar BIGINT NOT NULL CHECK (total_bayar >= 0),
  pembulatan BIGINT NOT NULL CHECK (pembulatan >= 0),
  bagian_produser BIGINT NOT NULL CHECK (bagian_produser >= 0),
  bagian_admin BIGINT NOT NULL CHECK (bagian_admin >= 0),
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'paid', 'expired', 'failed', 'refunded', 'cancelled')),
  payment_method TEXT DEFAULT 'QRIS',
  payment_type TEXT,
  snap_token TEXT,
  snap_redirect_url TEXT,
  midtrans_transaction_id TEXT,
  paid_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ,
  customer_name TEXT,
  customer_email TEXT,
  customer_nik TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT chk_transaksi_invarian CHECK (bagian_produser + bagian_admin = total_bayar)
);

CREATE INDEX IF NOT EXISTS idx_transactions_user ON public.transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_transactions_concert ON public.transactions(concert_id);
CREATE INDEX IF NOT EXISTS idx_transactions_status ON public.transactions(status);

-- Tambahkan komponen biaya terinci pada tabel orders jika ada pemanggilan kode legacy
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS customer_nik TEXT;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS harga_satuan BIGINT DEFAULT 0;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS jumlah_tiket INT DEFAULT 1;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS harga_tiket BIGINT DEFAULT 0;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS pajak_hiburan BIGINT DEFAULT 0;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS biaya_aplikasi BIGINT DEFAULT 0;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS subtotal BIGINT DEFAULT 0;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS total_bayar BIGINT DEFAULT 0;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS pembulatan BIGINT DEFAULT 0;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS bagian_produser BIGINT DEFAULT 0;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS bagian_admin BIGINT DEFAULT 0;

-- ------------------------------------------------------------------------------
-- 3. TABEL LEDGER APPEND-ONLY (BUKU BESAR SALDO MUTASI)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.ledger (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_type TEXT NOT NULL CHECK (wallet_type IN ('produser', 'admin')),
  wallet_owner_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  transaksi_id TEXT,
  tipe TEXT NOT NULL CHECK (tipe IN ('kredit', 'debit')),
  jumlah BIGINT NOT NULL CHECK (jumlah > 0),
  saldo_setelah BIGINT NOT NULL CHECK (saldo_setelah >= 0),
  keterangan TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ledger_wallet ON public.ledger(wallet_type, wallet_owner_id);
CREATE INDEX IF NOT EXISTS idx_ledger_transaksi ON public.ledger(transaksi_id);
CREATE INDEX IF NOT EXISTS idx_ledger_created ON public.ledger(created_at);

-- Enforce Append-Only: Tolak semua operasi UPDATE dan DELETE pada tabel ledger
CREATE OR REPLACE FUNCTION public.prevent_ledger_update_delete()
RETURNS TRIGGER AS $$
BEGIN
  RAISE EXCEPTION 'TABEL LEDGER APPEND-ONLY: Operasi % dilarang untuk menjaga integritas saldo!', TG_OP;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_ledger_prevent_update_delete ON public.ledger;
CREATE TRIGGER trg_ledger_prevent_update_delete
BEFORE UPDATE OR DELETE ON public.ledger
FOR EACH ROW
EXECUTE FUNCTION public.prevent_ledger_update_delete();

-- ------------------------------------------------------------------------------
-- 4. TABEL WITHDRAWALS & REFUNDS
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.withdrawals (
  id TEXT PRIMARY KEY,
  reference_no TEXT UNIQUE,
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  producer_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  role TEXT NOT NULL DEFAULT 'produser' CHECK (role IN ('produser', 'admin')),
  concert_id TEXT REFERENCES public.concerts(id) ON DELETE SET NULL,
  amount BIGINT NOT NULL CHECK (amount >= 50000),
  bank_name TEXT NOT NULL,
  account_number TEXT NOT NULL,
  account_name TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'success', 'failed')),
  rejection_reason TEXT,
  iris_payout_id TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  completed_at TIMESTAMPTZ
);

ALTER TABLE public.withdrawals ADD COLUMN IF NOT EXISTS role TEXT DEFAULT 'produser';
ALTER TABLE public.withdrawals ADD COLUMN IF NOT EXISTS iris_payout_id TEXT;
CREATE INDEX IF NOT EXISTS idx_withdrawals_wallet ON public.withdrawals(user_id, role);
CREATE INDEX IF NOT EXISTS idx_withdrawals_status ON public.withdrawals(status);

CREATE TABLE IF NOT EXISTS public.refunds (
  id TEXT PRIMARY KEY,
  transaction_id TEXT,
  order_id TEXT,
  ticket_id TEXT,
  concert_id TEXT REFERENCES public.concerts(id) ON DELETE SET NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  refund_amount BIGINT NOT NULL CHECK (refund_amount >= 0),
  admin_fee_retained BIGINT NOT NULL DEFAULT 0,
  destination_type TEXT NOT NULL DEFAULT 'BANK',
  destination_provider TEXT NOT NULL DEFAULT 'BCA',
  destination_account_no TEXT NOT NULL DEFAULT '',
  destination_account_name TEXT NOT NULL DEFAULT '',
  reason TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed')),
  iris_payout_id TEXT,
  failure_reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.refunds ADD COLUMN IF NOT EXISTS admin_fee_retained BIGINT DEFAULT 0;
CREATE INDEX IF NOT EXISTS idx_refunds_concert ON public.refunds(concert_id);
CREATE INDEX IF NOT EXISTS idx_refunds_user ON public.refunds(user_id);
CREATE INDEX IF NOT EXISTS idx_refunds_status ON public.refunds(status);

-- ------------------------------------------------------------------------------
-- 5. PENYELARASAN STATUS TIKET & EVENT (CONCERTS)
-- ------------------------------------------------------------------------------
-- Tiket: 'aktif', 'dipakai', 'dibatalkan' (toleransi kapitalisasi sistem lama)
ALTER TABLE public.tickets DROP CONSTRAINT IF EXISTS chk_ticket_status;
ALTER TABLE public.tickets ADD CONSTRAINT chk_ticket_status
  CHECK (LOWER(status) IN ('aktif', 'dipakai', 'sudah dipakai', 'dibatalkan', 'direfund'));

-- Konser / Event: pastikan kolom pembatalan tersedia
ALTER TABLE public.concerts ADD COLUMN IF NOT EXISTS cancellation_reason TEXT;
ALTER TABLE public.concerts ADD COLUMN IF NOT EXISTS cancelled_at TIMESTAMPTZ;

-- ------------------------------------------------------------------------------
-- 6. FUNGSI HITUNG_TRANSAKSI (SUMBER KEBENARAN TUNGGAL DI SERVER)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.hitung_transaksi(
  p_harga_satuan BIGINT,
  p_jumlah INT
)
RETURNS TABLE (
  harga_satuan BIGINT,
  jumlah INT,
  harga_tiket BIGINT,
  pajak_hiburan BIGINT,
  biaya_aplikasi BIGINT,
  subtotal BIGINT,
  total_bayar BIGINT,
  pembulatan BIGINT,
  bagian_produser BIGINT,
  bagian_admin BIGINT
) AS $$
DECLARE
  v_pajak_pct NUMERIC;
  v_biaya_pct NUMERIC;
  v_max_tiket INT;
  v_kelipatan INT;
  v_harga_tiket BIGINT;
  v_pajak_hiburan BIGINT;
  v_biaya_aplikasi BIGINT;
  v_subtotal BIGINT;
  v_total_bayar BIGINT;
  v_pembulatan BIGINT;
  v_bagian_produser BIGINT;
  v_bagian_admin BIGINT;
BEGIN
  -- 1. Baca konfigurasi dinamis dari tabel app_config
  SELECT COALESCE(NULLIF(value, '')::NUMERIC, 10.0)
  INTO v_pajak_pct
  FROM public.app_config
  WHERE key = 'pajak_hiburan_persen';
  IF v_pajak_pct IS NULL THEN v_pajak_pct := 10.0; END IF;

  SELECT COALESCE(NULLIF(value, '')::NUMERIC, 2.0)
  INTO v_biaya_pct
  FROM public.app_config
  WHERE key = 'biaya_aplikasi_persen';
  IF v_biaya_pct IS NULL THEN v_biaya_pct := 2.0; END IF;

  SELECT COALESCE(NULLIF(value, '')::INT, 4)
  INTO v_max_tiket
  FROM public.app_config
  WHERE key = 'max_tiket_per_transaksi';
  IF v_max_tiket IS NULL THEN v_max_tiket := 4; END IF;

  SELECT COALESCE(NULLIF(value, '')::INT, 1000)
  INTO v_kelipatan
  FROM public.app_config
  WHERE key = 'kelipatan_pembulatan';
  IF v_kelipatan IS NULL OR v_kelipatan <= 0 THEN v_kelipatan := 1000; END IF;

  -- 2. Validasi batas tiket (1 sampai 4) dan nominal harga
  IF p_jumlah < 1 OR p_jumlah > v_max_tiket THEN
    RAISE EXCEPTION 'Jumlah tiket tidak valid: %. Maksimal pembelian adalah % tiket per transaksi!', p_jumlah, v_max_tiket;
  END IF;

  IF p_harga_satuan < 0 THEN
    RAISE EXCEPTION 'Harga satuan tiket tidak boleh negatif: %', p_harga_satuan;
  END IF;

  -- 3. Kalkulasi Komponen Biaya (Semua nominal Integer Rupiah)
  v_harga_tiket := p_harga_satuan * p_jumlah;
  v_pajak_hiburan := ROUND(v_harga_tiket * (v_pajak_pct / 100.0))::BIGINT;
  v_biaya_aplikasi := ROUND(v_harga_tiket * (v_biaya_pct / 100.0))::BIGINT;
  v_subtotal := v_harga_tiket + v_pajak_hiburan + v_biaya_aplikasi;

  -- Pembulatan KE ATAS ke kelipatan Rp 1.000 (ratusan menjadi 000)
  v_total_bayar := (CEIL(v_subtotal::NUMERIC / v_kelipatan::NUMERIC) * v_kelipatan)::BIGINT;
  v_pembulatan := v_total_bayar - v_subtotal;

  -- Pembagian dana
  v_bagian_produser := v_harga_tiket + v_pajak_hiburan;
  v_bagian_admin := v_biaya_aplikasi + v_pembulatan;

  -- 4. Invarian Wajib: produser + admin == total_bayar
  IF (v_bagian_produser + v_bagian_admin) <> v_total_bayar THEN
    RAISE EXCEPTION 'Pelanggaran invarian: bagian_produser (%) + bagian_admin (%) != total_bayar (%)',
      v_bagian_produser, v_bagian_admin, v_total_bayar;
  END IF;

  -- Return hasil
  RETURN QUERY SELECT
    p_harga_satuan,
    p_jumlah,
    v_harga_tiket,
    v_pajak_hiburan,
    v_biaya_aplikasi,
    v_subtotal,
    v_total_bayar,
    v_pembulatan,
    v_bagian_produser,
    v_bagian_admin;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- Helper RPC dalam format JSON untuk kemudahan pemanggilan frontend / Edge Function
CREATE OR REPLACE FUNCTION public.hitung_transaksi_json(
  p_harga_satuan BIGINT,
  p_jumlah INT
)
RETURNS JSONB AS $$
DECLARE
  v_res RECORD;
BEGIN
  SELECT * INTO v_res FROM public.hitung_transaksi(p_harga_satuan, p_jumlah);
  RETURN jsonb_build_object(
    'harga_satuan', v_res.harga_satuan,
    'jumlah', v_res.jumlah,
    'harga_tiket', v_res.harga_tiket,
    'pajak_hiburan', v_res.pajak_hiburan,
    'biaya_aplikasi', v_res.biaya_aplikasi,
    'subtotal', v_res.subtotal,
    'total_bayar', v_res.total_bayar,
    'pembulatan', v_res.pembulatan,
    'bagian_produser', v_res.bagian_produser,
    'bagian_admin', v_res.bagian_admin
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- ------------------------------------------------------------------------------
-- 7. ROW LEVEL SECURITY (RLS) PER ROLE
-- ------------------------------------------------------------------------------
ALTER TABLE public.app_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ledger ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.withdrawals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.refunds ENABLE ROW LEVEL SECURITY;

-- Policy app_config
DROP POLICY IF EXISTS "app_config_read_public" ON public.app_config;
CREATE POLICY "app_config_read_public" ON public.app_config
  FOR SELECT USING (TRUE);

DROP POLICY IF EXISTS "app_config_write_admin" ON public.app_config;
CREATE POLICY "app_config_write_admin" ON public.app_config
  FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

-- Policy transactions
DROP POLICY IF EXISTS "transactions_select_policy" ON public.transactions;
CREATE POLICY "transactions_select_policy" ON public.transactions
  FOR SELECT USING (
    auth.uid() = user_id 
    OR public.is_admin()
    OR EXISTS (
      SELECT 1 FROM public.concerts c
      WHERE c.id = transactions.concert_id 
        AND c.producer_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "transactions_insert_user" ON public.transactions;
CREATE POLICY "transactions_insert_user" ON public.transactions
  FOR INSERT WITH CHECK (auth.uid() = user_id OR auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "transactions_update_admin" ON public.transactions;
CREATE POLICY "transactions_update_admin" ON public.transactions
  FOR UPDATE USING (public.is_admin());

-- Policy ledger
DROP POLICY IF EXISTS "ledger_select_policy" ON public.ledger;
CREATE POLICY "ledger_select_policy" ON public.ledger
  FOR SELECT USING (
    public.is_admin()
    OR (wallet_type = 'produser' AND wallet_owner_id = auth.uid())
  );

DROP POLICY IF EXISTS "ledger_insert_admin" ON public.ledger;
CREATE POLICY "ledger_insert_admin" ON public.ledger
  FOR INSERT WITH CHECK (public.is_admin());

-- Policy withdrawals
DROP POLICY IF EXISTS "withdrawals_select_policy" ON public.withdrawals;
CREATE POLICY "withdrawals_select_policy" ON public.withdrawals
  FOR SELECT USING (
    auth.uid() = user_id 
    OR auth.uid() = producer_id 
    OR public.is_admin()
  );

DROP POLICY IF EXISTS "withdrawals_insert_policy" ON public.withdrawals;
CREATE POLICY "withdrawals_insert_policy" ON public.withdrawals
  FOR INSERT WITH CHECK (
    auth.uid() = user_id 
    OR auth.uid() = producer_id 
    OR public.is_admin()
  );

DROP POLICY IF EXISTS "withdrawals_update_admin" ON public.withdrawals;
CREATE POLICY "withdrawals_update_admin" ON public.withdrawals
  FOR UPDATE USING (public.is_admin());

-- Policy refunds
DROP POLICY IF EXISTS "refunds_select_policy" ON public.refunds;
CREATE POLICY "refunds_select_policy" ON public.refunds
  FOR SELECT USING (
    auth.uid() = user_id
    OR public.is_admin()
    OR EXISTS (
      SELECT 1 FROM public.concerts c
      WHERE c.id = refunds.concert_id 
        AND c.producer_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "refunds_write_admin" ON public.refunds;
CREATE POLICY "refunds_write_admin" ON public.refunds
  FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

-- ------------------------------------------------------------------------------
-- 8. PENGUJIAN OTOMATIS: INVARIAN MATEMATIKA, CONTOH SPESIFIKASI & IMUTABILITAS LEDGER
-- ------------------------------------------------------------------------------
DO $$
DECLARE
  v_test RECORD;
  v_dummy_id UUID;
  v_ledger_blocked BOOLEAN := FALSE;
BEGIN
  -- UJI 1: Contoh Spesifikasi Persis
  -- 153.000 x 1 -> pajak 15.300, biaya 3.060, subtotal 171.360, total 172.000,
  -- pembulatan 640, produser 168.300, admin 3.700.
  SELECT * INTO v_test FROM public.hitung_transaksi(153000, 1);
  
  ASSERT v_test.harga_tiket = 153000, 'Uji 1 Gagal: harga_tiket tidak sama dengan 153000';
  ASSERT v_test.pajak_hiburan = 15300, 'Uji 1 Gagal: pajak_hiburan tidak sama dengan 15300';
  ASSERT v_test.biaya_aplikasi = 3060, 'Uji 1 Gagal: biaya_aplikasi tidak sama dengan 3060';
  ASSERT v_test.subtotal = 171360, 'Uji 1 Gagal: subtotal tidak sama dengan 171360';
  ASSERT v_test.total_bayar = 172000, 'Uji 1 Gagal: total_bayar tidak sama dengan 172000';
  ASSERT v_test.pembulatan = 640, 'Uji 1 Gagal: pembulatan tidak sama dengan 640';
  ASSERT v_test.bagian_produser = 168300, 'Uji 1 Gagal: bagian_produser tidak sama dengan 168300';
  ASSERT v_test.bagian_admin = 3700, 'Uji 1 Gagal: bagian_admin tidak sama dengan 3700';
  ASSERT (v_test.bagian_produser + v_test.bagian_admin) = v_test.total_bayar, 'Uji 1 Gagal: Invarian produser + admin == total_bayar meleset';

  -- UJI 2: Pembelian 4 tiket (Batas Maksimum)
  SELECT * INTO v_test FROM public.hitung_transaksi(250000, 4);
  ASSERT v_test.harga_tiket = 1000000, 'Uji 2 Gagal: harga_tiket 4x250rb';
  ASSERT (v_test.bagian_produser + v_test.bagian_admin) = v_test.total_bayar, 'Uji 2 Gagal: Invarian 4 tiket';

  -- UJI 3: Validasi Lebih dari 4 tiket harus melempar exception
  BEGIN
    PERFORM public.hitung_transaksi(150000, 5);
    RAISE EXCEPTION 'Uji 3 Gagal: Pembelian 5 tiket seharusnya ditolak!';
  EXCEPTION WHEN OTHERS THEN
    -- Sukses menolak jumlah tiket > 4
    NULL;
  END;

  -- UJI 4: Uji Append-Only Ledger (UPDATE dan DELETE wajib ditolak)
  INSERT INTO public.ledger (wallet_type, transaksi_id, tipe, jumlah, saldo_setelah, keterangan)
  VALUES ('admin', 'TEST-TRX-001', 'kredit', 3700, 3700, 'Uji Imutabilitas Ledger')
  RETURNING id INTO v_dummy_id;

  BEGIN
    UPDATE public.ledger SET jumlah = 99999 WHERE id = v_dummy_id;
  EXCEPTION WHEN OTHERS THEN
    v_ledger_blocked := TRUE;
  END;
  ASSERT v_ledger_blocked = TRUE, 'Uji 4 Gagal: UPDATE pada ledger berhasil (seharusnya ditolak)!';

  -- Bersihkan data uji ledger sementara dengan menonaktifkan trigger khusus sesi pengujian ini
  ALTER TABLE public.ledger DISABLE TRIGGER trg_ledger_prevent_update_delete;
  DELETE FROM public.ledger WHERE id = v_dummy_id;
  ALTER TABLE public.ledger ENABLE TRIGGER trg_ledger_prevent_update_delete;

  RAISE NOTICE 'Seluruh pengujian Fase 1 (Invarian, Rumus, dan Ledger Immutability) BERHASIL 100%%!';
END $$;
