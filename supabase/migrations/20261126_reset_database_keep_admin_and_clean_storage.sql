-- ==============================================================================
-- SQL RESET TOTAL DATABASE & STORAGE: LIVE TIX
-- Menghapus seluruh data (User, Produser, Gate Crew, Konser, Tiket, Transaksi,
-- serta seluruh file di Supabase Storage), KECUALI akun Admin.
--
-- Akun Admin yang dipertahankan & dijamin aktif:
-- Email    : admin1@gmail.com (atau akun admin terdaftar lainnya)
-- Password : admin123
-- Role     : Admin (Full Access)
-- ==============================================================================
-- CARA MENJALANKAN DI SUPABASE:
-- 1. Buka Supabase Dashboard -> Proyek LiveTix Anda
-- 2. Buka menu "SQL Editor" di bilah kiri
-- 3. Tempel (Paste) seluruh isi script ini
-- 4. Klik tombol "RUN"
-- ==============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

DO $$
DECLARE
  v_admin_id UUID;
  v_admin_email TEXT := 'admin1@gmail.com';
  v_admin_password TEXT := 'admin123';
  v_instance_id UUID;
  v_enc_pw TEXT;
  v_deleted_users_count INT := 0;
  v_deleted_storage_count INT := 0;
BEGIN
  -- 1. Matikan sementara constraint checking (Session Replication Mode) agar penghapusan lancar
  BEGIN
    SET session_replication_role = 'replica';
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

  -- 2. Identifikasi atau siapkan Akun Admin Utama
  SELECT id INTO v_admin_id
  FROM public.profiles
  WHERE LOWER(role) = 'admin' OR LOWER(email) IN ('admin1@gmail.com', 'admin@gmail.com', 'admin@livetix.com')
  LIMIT 1;

  IF v_admin_id IS NULL THEN
    SELECT id INTO v_admin_id
    FROM auth.users
    WHERE LOWER(email) IN ('admin1@gmail.com', 'admin@gmail.com', 'admin@livetix.com')
    LIMIT 1;
  END IF;

  IF v_admin_id IS NULL THEN
    v_admin_id := 'a0000000-0000-0000-0000-000000000001'::uuid;
  END IF;

  SELECT COALESCE(
    (SELECT instance_id FROM auth.users WHERE instance_id IS NOT NULL LIMIT 1),
    '00000000-0000-0000-0000-000000000000'::uuid
  ) INTO v_instance_id;

  v_enc_pw := extensions.crypt(v_admin_password, extensions.gen_salt('bf'));

  CREATE TEMP TABLE IF NOT EXISTS temp_preserved_admins (id UUID PRIMARY KEY) ON COMMIT DROP;
  TRUNCATE TABLE temp_preserved_admins;

  INSERT INTO temp_preserved_admins (id)
  SELECT id FROM public.profiles WHERE LOWER(role) = 'admin' OR LOWER(email) LIKE 'admin%'
  ON CONFLICT DO NOTHING;

  INSERT INTO temp_preserved_admins (id)
  SELECT id FROM auth.users WHERE LOWER(email) LIKE 'admin%'
  ON CONFLICT DO NOTHING;

  INSERT INTO temp_preserved_admins (id) VALUES (v_admin_id)
  ON CONFLICT DO NOTHING;

  -- ----------------------------------------------------------------------------
  -- 3. HAPUS SELURUH FILE DI SUPABASE STORAGE (storage.objects)
  -- ----------------------------------------------------------------------------
  IF to_regclass('storage.objects') IS NOT NULL THEN
    SELECT COUNT(*) INTO v_deleted_storage_count FROM storage.objects;
    DELETE FROM storage.objects;
    RAISE NOTICE 'Storage Supabase: % file berhasil dihapus bersih dari seluruh bucket!', v_deleted_storage_count;
  END IF;

  -- ----------------------------------------------------------------------------
  -- 4. HAPUS DATA TRANSAKSI, TIKET, KEUANGAN, & LOG
  -- ----------------------------------------------------------------------------
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

  IF to_regclass('public.ledger') IS NOT NULL THEN
    EXECUTE 'TRUNCATE TABLE public.ledger CASCADE';
  END IF;

  IF to_regclass('public.transactions') IS NOT NULL THEN
    EXECUTE 'TRUNCATE TABLE public.transactions CASCADE';
  END IF;

  IF to_regclass('public.tickets') IS NOT NULL THEN
    EXECUTE 'TRUNCATE TABLE public.tickets CASCADE';
  END IF;

  IF to_regclass('public.orders') IS NOT NULL THEN
    EXECUTE 'TRUNCATE TABLE public.orders CASCADE';
  END IF;

  -- ----------------------------------------------------------------------------
  -- 5. HAPUS DATA KONSER, GATE CREW, CS & NOTIFIKASI
  -- ----------------------------------------------------------------------------
  IF to_regclass('public.concert_gate_crews') IS NOT NULL THEN
    EXECUTE 'TRUNCATE TABLE public.concert_gate_crews CASCADE';
  END IF;

  IF to_regclass('public.gate_crew') IS NOT NULL THEN
    EXECUTE 'TRUNCATE TABLE public.gate_crew CASCADE';
  END IF;

  IF to_regclass('public.concert_likes') IS NOT NULL THEN
    EXECUTE 'TRUNCATE TABLE public.concert_likes CASCADE';
  END IF;

  IF to_regclass('public.cs_messages') IS NOT NULL THEN
    EXECUTE 'TRUNCATE TABLE public.cs_messages CASCADE';
  END IF;

  IF to_regclass('public.customer_service_messages') IS NOT NULL THEN
    EXECUTE 'TRUNCATE TABLE public.customer_service_messages CASCADE';
  END IF;

  IF to_regclass('public.customer_service_conversations') IS NOT NULL THEN
    EXECUTE 'TRUNCATE TABLE public.customer_service_conversations CASCADE';
  END IF;

  IF to_regclass('public.notifications') IS NOT NULL THEN
    EXECUTE 'TRUNCATE TABLE public.notifications CASCADE';
  END IF;

  IF to_regclass('public.user_fcm_tokens') IS NOT NULL THEN
    EXECUTE 'DELETE FROM public.user_fcm_tokens WHERE user_id NOT IN (SELECT id FROM temp_preserved_admins)';
  END IF;

  IF to_regclass('public.approval_queue') IS NOT NULL THEN
    EXECUTE 'TRUNCATE TABLE public.approval_queue CASCADE';
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

  -- ----------------------------------------------------------------------------
  -- 6. HAPUS SELURUH PROFIL KECUALI ADMIN (public.profiles)
  -- ----------------------------------------------------------------------------
  IF to_regclass('public.profiles') IS NOT NULL THEN
    EXECUTE 'DELETE FROM public.profiles WHERE id NOT IN (SELECT id FROM temp_preserved_admins)';
  END IF;

  -- ----------------------------------------------------------------------------
  -- 7. HAPUS SELURUH AKUN PENGGUNA NON-ADMIN DI AUTH SUPABASE (auth.users dll)
  -- ----------------------------------------------------------------------------
  IF to_regclass('auth.mfa_amr_claims') IS NOT NULL THEN
    EXECUTE 'DELETE FROM auth.mfa_amr_claims WHERE session_id IN (SELECT id FROM auth.sessions WHERE user_id NOT IN (SELECT id FROM temp_preserved_admins))';
  END IF;

  IF to_regclass('auth.mfa_challenges') IS NOT NULL THEN
    EXECUTE 'DELETE FROM auth.mfa_challenges WHERE factor_id IN (SELECT id FROM auth.mfa_factors WHERE user_id NOT IN (SELECT id FROM temp_preserved_admins))';
  END IF;

  IF to_regclass('auth.mfa_factors') IS NOT NULL THEN
    EXECUTE 'DELETE FROM auth.mfa_factors WHERE user_id NOT IN (SELECT id FROM temp_preserved_admins)';
  END IF;

  IF to_regclass('auth.refresh_tokens') IS NOT NULL THEN
    EXECUTE 'DELETE FROM auth.refresh_tokens WHERE session_id IN (SELECT id FROM auth.sessions WHERE user_id NOT IN (SELECT id FROM temp_preserved_admins))';
  END IF;

  IF to_regclass('auth.sessions') IS NOT NULL THEN
    EXECUTE 'DELETE FROM auth.sessions WHERE user_id NOT IN (SELECT id FROM temp_preserved_admins)';
  END IF;

  IF to_regclass('auth.identities') IS NOT NULL THEN
    EXECUTE 'DELETE FROM auth.identities WHERE user_id NOT IN (SELECT id FROM temp_preserved_admins)';
  END IF;

  IF to_regclass('auth.users') IS NOT NULL THEN
    SELECT COUNT(*) INTO v_deleted_users_count FROM auth.users WHERE id NOT IN (SELECT id FROM temp_preserved_admins);
    EXECUTE 'DELETE FROM auth.users WHERE id NOT IN (SELECT id FROM temp_preserved_admins)';
  END IF;

  -- ----------------------------------------------------------------------------
  -- 8. PASTIKAN AKUN ADMIN UTAMA ADA DAN AKTIF (admin1@gmail.com / admin123)
  -- ----------------------------------------------------------------------------
  INSERT INTO auth.users (
    id,
    instance_id,
    email,
    encrypted_password,
    email_confirmed_at,
    raw_app_meta_data,
    raw_user_meta_data,
    aud,
    role,
    created_at,
    updated_at
  ) VALUES (
    v_admin_id,
    v_instance_id,
    v_admin_email,
    v_enc_pw,
    NOW(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    jsonb_build_object(
      'name', 'Admin LiveTix',
      'full_name', 'Admin LiveTix',
      'role', 'Admin',
      'email', v_admin_email,
      'email_verified', true
    ),
    'authenticated',
    'authenticated',
    NOW(),
    NOW()
  )
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    encrypted_password = EXCLUDED.encrypted_password,
    raw_app_meta_data = EXCLUDED.raw_app_meta_data,
    raw_user_meta_data = EXCLUDED.raw_user_meta_data,
    email_confirmed_at = COALESCE(auth.users.email_confirmed_at, NOW()),
    updated_at = NOW();

  INSERT INTO auth.identities (
    id,
    user_id,
    identity_data,
    provider,
    provider_id,
    last_sign_in_at,
    created_at,
    updated_at
  ) VALUES (
    gen_random_uuid(),
    v_admin_id,
    jsonb_build_object(
      'sub', v_admin_id::text,
      'email', v_admin_email,
      'email_verified', true,
      'phone_verified', false
    ),
    'email',
    v_admin_id::text,
    NOW(),
    NOW(),
    NOW()
  ) ON CONFLICT (provider, provider_id) DO NOTHING;

  INSERT INTO public.profiles (
    id,
    email,
    name,
    full_name,
    role,
    is_verified,
    verification_status,
    approval_status,
    created_at,
    updated_at
  ) VALUES (
    v_admin_id,
    v_admin_email,
    'Admin LiveTix',
    'Admin LiveTix',
    'Admin',
    TRUE,
    'approved',
    'approved',
    NOW(),
    NOW()
  )
  ON CONFLICT (id) DO UPDATE SET
    role = 'Admin',
    is_verified = TRUE,
    verification_status = 'approved',
    approval_status = 'approved',
    updated_at = NOW();

  -- ----------------------------------------------------------------------------
  -- 9. PASTIKAN KONFIGURASI BATAS WAKTU PEMBAYARAN TETAP ADA
  -- ----------------------------------------------------------------------------
  IF to_regclass('public.app_config') IS NOT NULL THEN
    INSERT INTO public.app_config (key, value, description)
    VALUES ('payment_expiry_menit', '15', 'Batas waktu pembayaran tiket dalam menit (default 15)')
    ON CONFLICT (key) DO UPDATE SET
      value = '15',
      updated_at = NOW();
  END IF;

  -- 10. Kembalikan session_replication_role ke default
  BEGIN
    SET session_replication_role = 'origin';
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

  RAISE NOTICE '=======================================================';
  RAISE NOTICE 'RESET SELESAI SUKSES!';
  RAISE NOTICE 'Non-Admin Users Terhapus : %', v_deleted_users_count;
  RAISE NOTICE 'File Storage Terhapus    : %', v_deleted_storage_count;
  RAISE NOTICE 'Akun Admin Aktif         : % (password: admin123)', v_admin_email;
  RAISE NOTICE '=======================================================';
END $$;
