-- ==============================================================================
-- SEED DATA: AKUN TESTING ADMIN, PRODUSER, GATECREW, DAN USER DI SUPABASE
-- LiveTix / Soundwave System
-- ==============================================================================
-- Seluruh akun pengujian di bawah ini siap digunakan untuk login dengan password:
-- Password: password123
-- ==============================================================================

DO $$
DECLARE
  v_admin_id UUID := 'a0000000-0000-0000-0000-000000000001';
  v_admin1_id UUID;
  v_old_admin_id UUID;
  v_produser_id UUID := 'b0000000-0000-0000-0000-000000000002';
  v_user_id UUID := 'c0000000-0000-0000-0000-000000000003';
  v_gatecrew_id UUID := 'd0000000-0000-0000-0000-000000000004';
  v_encrypted_pw TEXT := extensions.crypt('password123', extensions.gen_salt('bf'));
  v_admin1_pw TEXT := extensions.crypt('admin123', extensions.gen_salt('bf'));
BEGIN
  -- 1. Insert / Update Admin di auth.users (email_confirmed_at aktif agar langsung bisa login)
  INSERT INTO auth.users (
    id, instance_id, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, aud, role, created_at, updated_at
  )
  VALUES (
    v_admin_id, '00000000-0000-0000-0000-000000000000',
    'admin@livetix.com', v_encrypted_pw, NOW(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"name":"Super Admin LiveTix","full_name":"Super Admin LiveTix","role":"Admin"}'::jsonb,
    'authenticated', 'authenticated', NOW(), NOW()
  )
  ON CONFLICT (id) DO UPDATE SET
    encrypted_password = EXCLUDED.encrypted_password,
    email_confirmed_at = NOW(),
    raw_user_meta_data = EXCLUDED.raw_user_meta_data,
    updated_at = NOW();

  -- 2. Insert / Update Produser di auth.users
  INSERT INTO auth.users (
    id, instance_id, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, aud, role, created_at, updated_at
  )
  VALUES (
    v_produser_id, '00000000-0000-0000-0000-000000000000',
    'produser@livetix.com', v_encrypted_pw, NOW(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"name":"Nusantara Soundwave Organizer","full_name":"Nusantara Soundwave Organizer","role":"Produser"}'::jsonb,
    'authenticated', 'authenticated', NOW(), NOW()
  )
  ON CONFLICT (id) DO UPDATE SET
    encrypted_password = EXCLUDED.encrypted_password,
    email_confirmed_at = NOW(),
    raw_user_meta_data = EXCLUDED.raw_user_meta_data,
    updated_at = NOW();

  -- 3. Insert / Update Gatecrew di auth.users
  INSERT INTO auth.users (
    id, instance_id, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, aud, role, created_at, updated_at
  )
  VALUES (
    v_gatecrew_id, '00000000-0000-0000-0000-000000000000',
    'gatecrew@livetix.com', v_encrypted_pw, NOW(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"name":"Budi Petugas Gate A","full_name":"Budi Petugas Gate A","role":"Gatecrew"}'::jsonb,
    'authenticated', 'authenticated', NOW(), NOW()
  )
  ON CONFLICT (id) DO UPDATE SET
    encrypted_password = EXCLUDED.encrypted_password,
    email_confirmed_at = NOW(),
    raw_user_meta_data = EXCLUDED.raw_user_meta_data,
    updated_at = NOW();

  -- 4. Insert / Update User di auth.users
  INSERT INTO auth.users (
    id, instance_id, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, aud, role, created_at, updated_at
  )
  VALUES (
    v_user_id, '00000000-0000-0000-0000-000000000000',
    'user@livetix.com', v_encrypted_pw, NOW(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"name":"Rafi Penonton","full_name":"Rafi Penonton","role":"User"}'::jsonb,
    'authenticated', 'authenticated', NOW(), NOW()
  )
  ON CONFLICT (id) DO UPDATE SET
    encrypted_password = EXCLUDED.encrypted_password,
    email_confirmed_at = NOW(),
    raw_user_meta_data = EXCLUDED.raw_user_meta_data,
    updated_at = NOW();

  -- 5. auth.identities untuk kelancaran login Supabase GoTrue
  INSERT INTO auth.identities (
    id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
  )
  VALUES
    (v_admin_id, v_admin_id, json_build_object('sub', v_admin_id::text, 'email', 'admin@livetix.com')::jsonb, 'email', 'admin@livetix.com', NOW(), NOW(), NOW()),
    (v_produser_id, v_produser_id, json_build_object('sub', v_produser_id::text, 'email', 'produser@livetix.com')::jsonb, 'email', 'produser@livetix.com', NOW(), NOW(), NOW()),
    (v_gatecrew_id, v_gatecrew_id, json_build_object('sub', v_gatecrew_id::text, 'email', 'gatecrew@livetix.com')::jsonb, 'email', 'gatecrew@livetix.com', NOW(), NOW(), NOW()),
    (v_user_id, v_user_id, json_build_object('sub', v_user_id::text, 'email', 'user@livetix.com')::jsonb, 'email', 'user@livetix.com', NOW(), NOW(), NOW())
  ON CONFLICT (provider, provider_id) DO NOTHING;

  -- 6. Masukkan ke public.profiles
  INSERT INTO public.profiles (id, username, email, name, full_name, phone, role)
  VALUES
    (v_admin_id, 'admin_livetix', 'admin@livetix.com', 'Super Admin LiveTix', 'Super Admin LiveTix', '081122334455', 'Admin'),
    (v_produser_id, 'produser_soundwave', 'produser@livetix.com', 'Nusantara Soundwave Organizer', 'Nusantara Soundwave Organizer', '081234567890', 'Produser'),
    (v_gatecrew_id, 'gatecrew_budi', 'gatecrew@livetix.com', 'Budi Petugas Gate A', 'Budi Petugas Gate A', '081377889900', 'Gatecrew'),
    (v_user_id, 'user_rafi', 'user@livetix.com', 'Rafi Penonton', 'Rafi Penonton', '081298765432', 'User')
  ON CONFLICT (id) DO UPDATE SET
    role = EXCLUDED.role,
    name = EXCLUDED.name,
    full_name = EXCLUDED.full_name,
    email = EXCLUDED.email,
    phone = EXCLUDED.phone,
    username = EXCLUDED.username,
    updated_at = NOW();

  -- 7. Masukkan profil ke public.promoter_profiles untuk Produser
  INSERT INTO public.promoter_profiles (
    id, user_id, company_name, address, bank_name,
    bank_account_number, bank_account_name, is_verified, approval_status, submitted_at
  )
  VALUES (
    'promoter-' || substr(v_produser_id::text, 1, 8),
    v_produser_id,
    'PT LiveTix Kreasi Musik',
    'Jl. Thamrin No. 10, Jakarta Pusat',
    'BCA',
    '8801234567',
    'PT LiveTix Kreasi Musik',
    TRUE,
    'approved',
    NOW()
  )
  ON CONFLICT (id) DO UPDATE SET
    is_verified = TRUE,
    approval_status = 'approved',
    company_name = EXCLUDED.company_name;

  -- 8. Sinkronkan akun admin1@gmail.com (password: admin123) termasuk migrasi dari asldkalkdaskd@gmail.com bila ada
  SELECT id INTO v_old_admin_id
  FROM auth.users
  WHERE lower(trim(email)) = 'asldkalkdaskd@gmail.com'
  LIMIT 1;

  SELECT id INTO v_admin1_id
  FROM auth.users
  WHERE lower(trim(email)) = 'admin1@gmail.com'
  LIMIT 1;

  IF v_old_admin_id IS NOT NULL AND v_admin1_id IS NULL THEN
    v_admin1_id := v_old_admin_id;
    UPDATE auth.users
    SET email = 'admin1@gmail.com',
        encrypted_password = v_admin1_pw,
        email_confirmed_at = NOW(),
        raw_user_meta_data = '{"name":"Super Admin LiveTix","full_name":"Super Admin LiveTix","role":"Admin","email":"admin1@gmail.com","email_verified":true}'::jsonb,
        updated_at = NOW()
    WHERE id = v_admin1_id;
  ELSE
    v_admin1_id := COALESCE(v_admin1_id, 'a0000000-0000-0000-0000-000000000005'::uuid);
    INSERT INTO auth.users (
      id, instance_id, email, encrypted_password, email_confirmed_at,
      raw_app_meta_data, raw_user_meta_data, aud, role, created_at, updated_at
    )
    VALUES (
      v_admin1_id, '00000000-0000-0000-0000-000000000000',
      'admin1@gmail.com', v_admin1_pw, NOW(),
      '{"provider":"email","providers":["email"]}'::jsonb,
      '{"name":"Super Admin LiveTix","full_name":"Super Admin LiveTix","role":"Admin","email":"admin1@gmail.com","email_verified":true}'::jsonb,
      'authenticated', 'authenticated', NOW(), NOW()
    )
    ON CONFLICT (id) DO UPDATE SET
      encrypted_password = EXCLUDED.encrypted_password,
      email_confirmed_at = NOW(),
      raw_user_meta_data = EXCLUDED.raw_user_meta_data,
      updated_at = NOW();

    IF v_old_admin_id IS NOT NULL AND v_old_admin_id <> v_admin1_id THEN
      DELETE FROM auth.identities WHERE user_id = v_old_admin_id;
      DELETE FROM public.profiles WHERE id = v_old_admin_id;
      DELETE FROM auth.users WHERE id = v_old_admin_id;
    END IF;
  END IF;

  IF EXISTS (
    SELECT 1 FROM auth.identities
    WHERE user_id = v_admin1_id AND provider = 'email'
  ) THEN
    UPDATE auth.identities
    SET provider_id = CASE
          WHEN lower(trim(provider_id)) = 'asldkalkdaskd@gmail.com' THEN 'admin1@gmail.com'
          ELSE provider_id
        END,
        identity_data = COALESCE(identity_data, '{}'::jsonb) || jsonb_build_object(
          'sub', v_admin1_id::text,
          'email', 'admin1@gmail.com',
          'email_verified', true
        ),
        updated_at = NOW()
    WHERE user_id = v_admin1_id AND provider = 'email';
  ELSE
    INSERT INTO auth.identities (
      id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
    )
    VALUES (
      gen_random_uuid(),
      v_admin1_id,
      json_build_object('sub', v_admin1_id::text, 'email', 'admin1@gmail.com', 'email_verified', true)::jsonb,
      'email',
      v_admin1_id::text,
      NOW(), NOW(), NOW()
    )
    ON CONFLICT (provider, provider_id) DO NOTHING;
  END IF;

  INSERT INTO public.profiles (id, username, email, name, full_name, phone, role)
  VALUES (
    v_admin1_id, 'admin1_livetix', 'admin1@gmail.com',
    'Super Admin LiveTix', 'Super Admin LiveTix', '081122334455', 'Admin'
  )
  ON CONFLICT (id) DO UPDATE SET
    role = 'Admin',
    email = 'admin1@gmail.com',
    name = COALESCE(NULLIF(trim(public.profiles.name), ''), EXCLUDED.name),
    full_name = COALESCE(NULLIF(trim(public.profiles.full_name), ''), EXCLUDED.full_name),
    updated_at = NOW();

  -- 9. Sinkronkan juga akun sebelumnya bila ada
  UPDATE auth.users
  SET encrypted_password = v_encrypted_pw, email_confirmed_at = NOW()
  WHERE email IN ('admin@sideload.id', 'bagas@nusantarahorizon.id');
END $$;
