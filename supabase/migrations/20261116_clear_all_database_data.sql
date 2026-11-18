-- ==============================================================================
-- SQL RESET TOTAL DATABASE: LIVE TIX
-- Menghapus seluruh data akun, profil, transaksi, konser, dan data autentikasi
-- beserta semua foreign key relasinya secara bersih dan aman.
-- ==============================================================================
-- Cara Menjalankan:
-- 1. Buka Supabase Dashboard -> Proyek LiveTix kamu
-- 2. Masuk ke menu "SQL Editor"
-- 3. Tempel (Paste) seluruh script di bawah ini lalu klik "Run"
-- ==============================================================================

DO $$
DECLARE
  r RECORD;
BEGIN
  -- 1. Nonaktifkan sementara constraint checking jika didukung (opsional / pelindung)
  BEGIN
    SET session_replication_role = 'replica';
  EXCEPTION WHEN OTHERS THEN
    -- Lanjut jika permission dibatasi
    NULL;
  END;

  -- 2. Hapus seluruh data transaksi & child tables di schema public
  IF to_regclass('public.ticket_checkins') IS NOT NULL THEN
    EXECUTE 'TRUNCATE TABLE public.ticket_checkins CASCADE';
  END IF;

  IF to_regclass('public.refunds') IS NOT NULL THEN
    EXECUTE 'TRUNCATE TABLE public.refunds CASCADE';
  END IF;

  IF to_regclass('public.ledger_mutations') IS NOT NULL THEN
    EXECUTE 'TRUNCATE TABLE public.ledger_mutations CASCADE';
  END IF;

  IF to_regclass('public.withdrawals') IS NOT NULL THEN
    EXECUTE 'TRUNCATE TABLE public.withdrawals CASCADE';
  END IF;

  IF to_regclass('public.tickets') IS NOT NULL THEN
    EXECUTE 'TRUNCATE TABLE public.tickets CASCADE';
  END IF;

  IF to_regclass('public.orders') IS NOT NULL THEN
    EXECUTE 'TRUNCATE TABLE public.orders CASCADE';
  END IF;

  IF to_regclass('public.concert_gate_crews') IS NOT NULL THEN
    EXECUTE 'TRUNCATE TABLE public.concert_gate_crews CASCADE';
  END IF;

  IF to_regclass('public.concert_likes') IS NOT NULL THEN
    EXECUTE 'TRUNCATE TABLE public.concert_likes CASCADE';
  END IF;

  IF to_regclass('public.cs_messages') IS NOT NULL THEN
    EXECUTE 'TRUNCATE TABLE public.cs_messages CASCADE';
  END IF;

  IF to_regclass('public.ticket_tiers') IS NOT NULL THEN
    EXECUTE 'TRUNCATE TABLE public.ticket_tiers CASCADE';
  END IF;

  IF to_regclass('public.concerts') IS NOT NULL THEN
    EXECUTE 'TRUNCATE TABLE public.concerts CASCADE';
  END IF;

  IF to_regclass('public.promoter_profiles') IS NOT NULL THEN
    EXECUTE 'TRUNCATE TABLE public.promoter_profiles CASCADE';
  END IF;

  -- 3. Hapus seluruh data profil di schema public
  IF to_regclass('public.profiles') IS NOT NULL THEN
    EXECUTE 'TRUNCATE TABLE public.profiles CASCADE';
  END IF;

  -- 4. Hapus seluruh data autentikasi di schema auth
  -- Hapus child table autentikasi terlebih dahulu
  IF to_regclass('auth.mfa_amr_claims') IS NOT NULL THEN
    EXECUTE 'DELETE FROM auth.mfa_amr_claims';
  END IF;

  IF to_regclass('auth.mfa_challenges') IS NOT NULL THEN
    EXECUTE 'DELETE FROM auth.mfa_challenges';
  END IF;

  IF to_regclass('auth.mfa_factors') IS NOT NULL THEN
    EXECUTE 'DELETE FROM auth.mfa_factors';
  END IF;

  IF to_regclass('auth.refresh_tokens') IS NOT NULL THEN
    EXECUTE 'DELETE FROM auth.refresh_tokens';
  END IF;

  IF to_regclass('auth.sessions') IS NOT NULL THEN
    EXECUTE 'DELETE FROM auth.sessions';
  END IF;

  IF to_regclass('auth.identities') IS NOT NULL THEN
    EXECUTE 'DELETE FROM auth.identities';
  END IF;

  -- Hapus seluruh akun pengguna dari auth.users
  IF to_regclass('auth.users') IS NOT NULL THEN
    EXECUTE 'DELETE FROM auth.users';
  END IF;

  -- 5. Kembalikan session_replication_role ke default
  BEGIN
    SET session_replication_role = 'origin';
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

  RAISE NOTICE 'Semua data di database public & auth berhasil dibersihkan (CLEAR)!';
END $$;

